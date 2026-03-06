/**
 * Sellio Metrics Backend — Google Meet Client
 *
 * Low-level wrapper around the Google Meet REST API.
 * Handles service-account authentication and rate-limit tracking.
 *
 * Uses `@google-apps/meet` SDK with `google-auth-library` JWT.
 */

import { SpacesServiceClient, ConferenceRecordsServiceClient } from "@google-apps/meet";
import { OAuth2Client } from "google-auth-library";
import type { Logger } from "../../core/logger";

// ─── Rate-limit tracking ────────────────────────────────────

interface RateLimitState {
    remaining: number;
    limit: number;
    resetAt: number; // unix seconds
    lastCallAt: number;
    callCount: number;
}

// ─── Client ─────────────────────────────────────────────────

export class GoogleMeetClient {
    private readonly logger: Logger;
    private oauth2Client: OAuth2Client;
    private spacesClient: SpacesServiceClient | null = null;
    private conferenceClient: ConferenceRecordsServiceClient | null = null;
    private readonly rateLimit: RateLimitState;

    constructor({ logger, clientId, clientSecret, redirectUri }: { logger: Logger; clientId: string; clientSecret: string; redirectUri: string }) {
        this.logger = logger.child({ module: "google-meet-client" });

        this.oauth2Client = new OAuth2Client(
            clientId,
            clientSecret,
            redirectUri
        );

        this.rateLimit = {
            remaining: 60,
            limit: 60,
            resetAt: 0,
            lastCallAt: 0,
            callCount: 0,
        };
    }

    /**
     * Set the credentials after a successful OAuth2 callback.
     * Re-initializes the Meet service clients with the new token.
     */
    setCredentials(tokens: any) {
        this.oauth2Client.setCredentials(tokens);

        this.spacesClient = new SpacesServiceClient({ authClient: this.oauth2Client });
        this.conferenceClient = new ConferenceRecordsServiceClient({ authClient: this.oauth2Client });

        this.logger.info("✅ Google Meet OAuth2 Credentials configured.");
    }

    /**
     * Generate the OAuth2 consent screen URL.
     */
    getAuthUrl(): string {
        return this.oauth2Client.generateAuthUrl({
            access_type: 'offline', // Get a refresh token
            scope: [
                "https://www.googleapis.com/auth/meetings.space.created",
                "https://www.googleapis.com/auth/meetings.space.readonly",
            ],
            prompt: 'consent' // Force to get refresh token
        });
    }

    /**
     * Exchange auth code for tokens.
     */
    async authorize(code: string): Promise<any> {
        const { tokens } = await this.oauth2Client.getToken(code);
        this.setCredentials(tokens);
        return tokens;
    }

    /**
     * Check if client is authenticated
     */
    isReady(): boolean {
        return this.spacesClient !== null && this.conferenceClient !== null;
    }

    // ─── Rate Limit Tracking ────────────────────────────────

    private trackCall(): void {
        const now = Math.floor(Date.now() / 1000);

        // Reset counter every 60 seconds
        if (now - this.rateLimit.lastCallAt > 60) {
            this.rateLimit.callCount = 0;
        }

        this.rateLimit.callCount++;
        this.rateLimit.lastCallAt = now;
        this.rateLimit.remaining = Math.max(0, this.rateLimit.limit - this.rateLimit.callCount);
        this.rateLimit.resetAt = now + 60;
    }

    getRateLimitStatus(): { remaining: number; limit: number; resetAt: string; isLow: boolean } {
        return {
            remaining: this.rateLimit.remaining,
            limit: this.rateLimit.limit,
            resetAt: this.rateLimit.resetAt > 0
                ? new Date(this.rateLimit.resetAt * 1000).toISOString()
                : "",
            isLow: this.rateLimit.remaining <= 10,
        };
    }

    // ─── Exponential Backoff Wrapper ────────────────────────

    private async withRetry<T>(operation: () => Promise<T>, label: string): Promise<T> {
        const maxRetries = 3;
        for (let attempt = 0; attempt <= maxRetries; attempt++) {
            try {
                this.trackCall();
                return await operation();
            } catch (error: any) {
                const status = error?.code ?? error?.status;

                // Rate limited (429) or server error (5xx): retry with backoff
                if ((status === 429 || (status >= 500 && status < 600)) && attempt < maxRetries) {
                    const delayMs = Math.pow(2, attempt) * 1000 + Math.random() * 500;
                    this.logger.warn(
                        { attempt, delayMs, status, label },
                        `⚠️  Google Meet API ${label} — retrying after ${Math.round(delayMs)}ms`,
                    );
                    await new Promise((r) => setTimeout(r, delayMs));
                    continue;
                }

                this.logger.error({ err: error, label }, `❌ Google Meet API ${label} failed`);
                throw error;
            }
        }

        throw new Error(`Exhausted retries for ${label}`);
    }

    // ─── Space Operations ───────────────────────────────────

    /**
     * Create a new Google Meet space.
     * Returns the space resource with meetingUri and meetingCode.
     */
    async createSpace(): Promise<{
        spaceName: string;
        meetingUri: string;
        meetingCode: string;
    }> {
        if (!this.spacesClient) {
            throw new Error("Google Meet Client not authorized. Requires OAuth2 sign-in.");
        }

        return this.withRetry(async () => {
            const [space] = await this.spacesClient!.createSpace({
                space: {
                    config: {
                        accessType: "OPEN",
                    },
                },
            });

            this.logger.info(
                { spaceName: space.name, meetingUri: space.meetingUri },
                "✅ Created Google Meet space",
            );

            return {
                spaceName: space.name ?? "",
                meetingUri: space.meetingUri ?? "",
                meetingCode: space.meetingCode ?? "",
            };
        }, "createSpace");
    }

    /**
     * Get details of an existing Meet space.
     */
    async getSpace(spaceName: string): Promise<{
        spaceName: string;
        meetingUri: string;
        meetingCode: string;
    }> {
        if (!this.spacesClient) {
            throw new Error("Google Meet Client not authorized. Requires OAuth2 sign-in.");
        }

        return this.withRetry(async () => {
            const [space] = await this.spacesClient!.getSpace({ name: spaceName });

            return {
                spaceName: space.name ?? "",
                meetingUri: space.meetingUri ?? "",
                meetingCode: space.meetingCode ?? "",
            };
        }, "getSpace");
    }

    /**
     * Safely format Google Protobuf Timestamps to ISO strings.
     */
    private formatTimestamp(ts: any): string {
        if (!ts) return "";
        if (typeof ts === "string") return ts;
        if (ts.seconds) {
            return new Date(Number(ts.seconds) * 1000).toISOString();
        }
        return "";
    }

    /**
     * List conference records (past meetings that actually happened).
     */
    async listConferenceRecords(spaceName: string): Promise<Array<{
        name: string;
        startTime: string;
        endTime: string;
    }>> {
        if (!this.conferenceClient) {
            throw new Error("Google Meet Client not authorized. Requires OAuth2 sign-in.");
        }

        return this.withRetry(async () => {
            const [records] = await this.conferenceClient!.listConferenceRecords({
                filter: `space.name="${spaceName}"`,
            });

            return (records ?? []).map((r: any) => ({
                name: r.name ?? "",
                startTime: this.formatTimestamp(r.startTime),
                endTime: this.formatTimestamp(r.endTime),
            }));
        }, "listConferenceRecords");
    }

    /**
     * List participants for a conference record.
     */
    async listParticipants(conferenceRecordName: string): Promise<Array<{
        name: string;
        displayName: string;
        email: string | null;
        earliestStartTime: string;
        latestEndTime: string;
    }>> {
        if (!this.conferenceClient) {
            throw new Error("Google Meet Client not authorized. Requires OAuth2 sign-in.");
        }

        return this.withRetry(async () => {
            const [participants] = await this.conferenceClient!.listParticipants({
                parent: conferenceRecordName,
            });

            return (participants ?? []).map((p: any) => ({
                name: p.name ?? "",
                displayName: p.signedinUser?.displayName ?? p.anonymousUser?.displayName ?? "Unknown",
                email: p.signedinUser?.user
                    ? `${p.signedinUser.user.replace("users/", "")}@gmail.com`
                    : null,
                earliestStartTime: this.formatTimestamp(p.earliestStartTime),
                latestEndTime: this.formatTimestamp(p.latestEndTime),
            }));
        }, "listParticipants");
    }

    /**
     * List participant sessions (individual join/leave events).
     */
    async listParticipantSessions(participantName: string): Promise<Array<{
        startTime: string;
        endTime: string | null;
    }>> {
        if (!this.conferenceClient) {
            throw new Error("Google Meet Client not authorized. Requires OAuth2 sign-in.");
        }

        return this.withRetry(async () => {
            const [sessions] = await this.conferenceClient!.listParticipantSessions({
                parent: participantName,
            });

            return (sessions ?? []).map((s: any) => {
                const endTime = this.formatTimestamp(s.endTime);
                return {
                    startTime: this.formatTimestamp(s.startTime),
                    endTime: endTime === "" ? null : endTime,
                };
            });
        }, "listParticipantSessions");
    }
}

export type { RateLimitState };
