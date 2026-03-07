/**
 * Sellio Metrics Backend — Google Meet Client
 *
 * Low-level wrapper around the Google Meet REST API.
 * Handles OAuth2 authentication and native fetch to Google APIs
 * (avoids @google-apps/meet which crashes on Cloudflare Workers due to protobuf eval).
 */

import { OAuth2Client } from "google-auth-library";
import type { CacheService } from "../cache/cache.service";
import type { Logger } from "../../core/logger";

// ─── Rate-limit tracking ────────────────────────────────────

export interface RateLimitState {
    remaining: number;
    limit: number;
    resetAt: number; // unix seconds
    lastCallAt: number;
    callCount: number;
}

// ─── Client ─────────────────────────────────────────────────

export class GoogleMeetClient {
    private readonly logger: Logger;
    private readonly cacheService: CacheService;
    private oauth2Client: OAuth2Client;
    private readonly rateLimit: RateLimitState;
    private currentToken: string | null = null;

    constructor({ logger, clientId, clientSecret, redirectUri, cacheService }: { logger: Logger; clientId: string; clientSecret: string; redirectUri: string; cacheService: CacheService }) {
        this.logger = logger.child({ module: "google-meet-client" });
        this.cacheService = cacheService;

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

    async setCredentials(tokens: any) {
        this.oauth2Client.setCredentials(tokens);
        this.currentToken = tokens.access_token || null;
        await this.cacheService.set("google_oauth_tokens", tokens, 30 * 24 * 60 * 60); // 30 days
        this.logger.info("✅ Google Meet OAuth2 Credentials configured.");
    }

    getAuthUrl(): string {
        return this.oauth2Client.generateAuthUrl({
            access_type: 'offline',
            scope: [
                "https://www.googleapis.com/auth/meetings.space.created",
                "https://www.googleapis.com/auth/meetings.space.readonly",
            ],
            prompt: 'consent'
        });
    }

    async authorize(code: string): Promise<any> {
        const { tokens } = await this.oauth2Client.getToken(code);
        await this.setCredentials(tokens);
        return tokens;
    }

    async isReady(): Promise<boolean> {
        if (this.currentToken) return true;

        // Check cache on new instances
        const cached = await this.cacheService.get<any>("google_oauth_tokens");
        if (cached?.data) {
            this.oauth2Client.setCredentials(cached.data);
            this.currentToken = cached.data.access_token || null;
            return true;
        }

        return false;
    }

    async clearCredentials(): Promise<void> {
        this.oauth2Client.setCredentials({});
        this.currentToken = null;
        await this.cacheService.del("google_oauth_tokens");
    }

    // ─── Rate Limit Tracking ────────────────────────────────

    private trackCall(): void {
        const now = Math.floor(Date.now() / 1000);
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

    // ─── Generic Fetch Wrapper ─────────────────────────────

    private async apiFetch<T>(endpoint: string, options: RequestInit = {}): Promise<T> {
        if (!(await this.isReady())) throw new Error("Not authorized");

        const url = `https://meet.googleapis.com/v2/${endpoint}`;
        const accessToken = (await this.oauth2Client.getAccessToken()).token;
        if (!accessToken) throw new Error("Failed to get access token");

        this.currentToken = accessToken; // Keep updated

        const fetchOptions: RequestInit = {
            ...options,
            headers: {
                "Authorization": `Bearer ${this.currentToken}`,
                "Content-Type": "application/json",
                ...options.headers,
            },
        };

        const maxRetries = 3;
        for (let attempt = 0; attempt <= maxRetries; attempt++) {
            this.trackCall();
            const res = await fetch(url, fetchOptions);

            if (res.ok) {
                // Return empty object for 204 No Content
                if (res.status === 204 || res.headers.get("content-length") === "0") return {} as T;
                return await res.json() as T;
            }

            if (res.status === 429 || (res.status >= 500 && res.status < 600)) {
                if (attempt < maxRetries) {
                    const delayMs = Math.pow(2, attempt) * 1000 + Math.random() * 500;
                    this.logger.warn({ attempt, delayMs, status: res.status, url }, `⚠️ Rate limited / Server Error — retrying fetch`);
                    await new Promise(r => setTimeout(r, delayMs));
                    continue;
                }
            }

            let errBody = "";
            try { errBody = await res.text(); } catch { }
            throw new Error(`Google Meet API failed: ${res.status} ${res.statusText} - ${errBody}`);
        }
        throw new Error("Exhausted retries");
    }

    // ─── Space Operations ───────────────────────────────────

    async createSpace(): Promise<{ spaceName: string; meetingUri: string; meetingCode: string; }> {
        const space = await this.apiFetch<any>("spaces", {
            method: "POST",
            body: JSON.stringify({ config: { accessType: "OPEN" } })
        });

        return {
            spaceName: space.name ?? "",
            meetingUri: space.meetingUri ?? "",
            meetingCode: space.meetingCode ?? "",
        };
    }

    async getSpace(spaceName: string): Promise<{ spaceName: string; meetingUri: string; meetingCode: string; }> {
        const space = await this.apiFetch<any>(spaceName);
        return {
            spaceName: space.name ?? "",
            meetingUri: space.meetingUri ?? "",
            meetingCode: space.meetingCode ?? "",
        };
    }

    async endSpace(spaceName: string): Promise<void> {
        await this.apiFetch(`${spaceName}:endActiveConference`, { method: "POST", body: "{}" });
    }

    // ─── Conference Analytics ───────────────────────────────

    async listConferenceRecords(spaceName: string): Promise<Array<{ name: string; startTime: string; endTime: string; }>> {
        const query = encodeURIComponent(`space.name="${spaceName}"`);
        const res = await this.apiFetch<any>(`conferenceRecords?filter=${query}`);
        const records = res.conferenceRecords || [];

        return records.map((r: any) => ({
            name: r.name ?? "",
            startTime: r.startTime ?? "",
            endTime: r.endTime ?? "",
        }));
    }

    async listParticipants(conferenceRecordName: string): Promise<Array<{
        name: string; displayName: string; email: string | null;
        earliestStartTime: string; latestEndTime: string;
    }>> {
        const res = await this.apiFetch<any>(`${conferenceRecordName}/participants`);
        const participants = res.participants || [];

        return participants.map((p: any) => ({
            name: p.name ?? "",
            displayName: p.signedinUser?.displayName ?? p.anonymousUser?.displayName ?? "Unknown",
            email: p.signedinUser?.user ? p.signedinUser.user.replace("users/", "") : null, // Not always valid format if no gmail, but fallback
            earliestStartTime: p.earliestStartTime ?? "",
            latestEndTime: p.latestEndTime ?? "",
        }));
    }

    async listParticipantSessions(participantName: string): Promise<Array<{ startTime: string; endTime: string | null; }>> {
        const res = await this.apiFetch<any>(`${participantName}/participantSessions`);
        const sessions = res.participantSessions || [];

        return sessions.map((s: any) => ({
            startTime: s.startTime ?? "",
            endTime: s.endTime || null,
        }));
    }
}
