/**
 * Google Meet Client
 *
 * Low-level wrapper for the Google Meet REST API and Workspace Events API.
 * Handles OAuth2 with automatic token refresh and full nextPageToken pagination.
 *
 * Combined from the old google-meet.client.ts and workspace-events.client.ts
 * to eliminate the duplicated apiFetch / auth logic.
 */

import { OAuth2Client } from "google-auth-library";
import type { CacheService } from "../cache/cache.service";
import type { Logger } from "../../core/logger";

const MEET_BASE       = "https://meet.googleapis.com/v2";
const WS_EVENTS_BASE  = "https://workspaceevents.googleapis.com/v1";

const MEET_EVENT_TYPES = [
    "google.workspace.meet.conference.v2.started",
    "google.workspace.meet.conference.v2.ended",
    "google.workspace.meet.participant.v2.joined",
    "google.workspace.meet.participant.v2.left",
];

// ─── Exported sub-types ─────────────────────────────────────────────────────

export interface MeetSpace {
    spaceName:   string;
    meetingUri:  string;
    meetingCode: string;
}

export interface ConferenceRecord {
    name:      string;
    startTime: string;
    endTime:   string;
}

export interface RawParticipant {
    name:               string;
    displayName:        string;
    /**
     * "users/{userId}" for signed-in users, null for anonymous.
     * Interoperable with Admin SDK and People API.
     */
    participantKey:     string | null;
    earliestStartTime:  string;
    latestEndTime:      string;
}

export interface WorkspaceSubscription {
    name:           string;
    targetResource: string;
    eventTypes:     string[];
    pubsubTopic:    string;
    state:          string;
    expireTime:     string;
}

// ─── Client ─────────────────────────────────────────────────────────────────

export class GoogleMeetClient {
    private readonly logger:       Logger;
    private readonly cacheService: CacheService;
    private readonly oauth2Client: OAuth2Client;

    constructor({
        logger,
        clientId,
        clientSecret,
        redirectUri,
        cacheService,
    }: {
        logger:        Logger;
        clientId:      string;
        clientSecret:  string;
        redirectUri:   string;
        cacheService:  CacheService;
    }) {
        this.logger       = logger.child({ module: "google-meet-client" });
        this.cacheService = cacheService;
        this.oauth2Client = new OAuth2Client(clientId, clientSecret, redirectUri);
    }

    // ─── OAuth2 ─────────────────────────────────────────────────────────────

    getAuthUrl(): string {
        return this.oauth2Client.generateAuthUrl({
            access_type: "offline",
            scope: [
                "https://www.googleapis.com/auth/meetings.space.created",
                "https://www.googleapis.com/auth/meetings.space.readonly",
                "https://www.googleapis.com/auth/pubsub",
            ],
            prompt: "consent",
        });
    }

    async authorize(code: string): Promise<any> {
        const { tokens } = await this.oauth2Client.getToken(code);
        await this.setCredentials(tokens);
        return tokens;
    }

    async isReady(): Promise<boolean> {
        if (this.oauth2Client.credentials?.access_token) return true;

        const cached = await this.cacheService.get<any>("google_oauth_tokens");
        if (cached?.data) {
            this.oauth2Client.setCredentials(cached.data);
            return true;
        }
        return false;
    }

    async clearCredentials(): Promise<void> {
        this.oauth2Client.setCredentials({});
        await this.cacheService.del("google_oauth_tokens");
    }

    private async setCredentials(tokens: any): Promise<void> {
        this.oauth2Client.setCredentials(tokens);
        await this.cacheService.set("google_oauth_tokens", tokens, 30 * 24 * 60 * 60);
        this.logger.info("OAuth2 credentials stored");
    }

    // ─── Generic Fetch (Meet API) ────────────────────────────────────────────

    private async meetFetch<T>(path: string, options: RequestInit = {}): Promise<T> {
        return this.apiFetch<T>(`${MEET_BASE}/${path}`, options);
    }

    // ─── Generic Fetch (Workspace Events API) ───────────────────────────────

    private async wsFetch<T>(path: string, options: RequestInit = {}): Promise<T> {
        const url = path.startsWith("http") ? path : `${WS_EVENTS_BASE}/${path}`;
        return this.apiFetch<T>(url, options);
    }

    // ─── Core Fetch with Token Refresh + Retry ───────────────────────────────

    private async apiFetch<T>(url: string, options: RequestInit = {}, isRetry = false): Promise<T> {
        if (!(await this.isReady())) throw new Error("Not authorized — sign in first");

        const token = (await this.oauth2Client.getAccessToken()).token;
        if (!token) throw new Error("Failed to get access token");

        const res = await fetch(url, {
            ...options,
            headers: {
                "Authorization": `Bearer ${token}`,
                "Content-Type":  "application/json",
                ...options.headers,
            },
        });

        // Transparent token refresh on 401
        if (res.status === 401 && !isRetry) {
            this.logger.warn({ url }, "Access token expired — refreshing");
            const { credentials } = await this.oauth2Client.refreshAccessToken();
            await this.setCredentials(credentials);
            return this.apiFetch<T>(url, options, true /* isRetry */);
        }

        if (res.ok) {
            if (res.status === 204 || res.headers.get("content-length") === "0") return {} as T;
            return res.json() as Promise<T>;
        }

        // Retry on transient 5xx / 429
        if (!isRetry && (res.status === 429 || res.status >= 500)) {
            const delay = res.status === 429 ? 2000 : 1000;
            this.logger.warn({ url, status: res.status }, `Transient error — retrying after ${delay}ms`);
            await new Promise(r => setTimeout(r, delay));
            return this.apiFetch<T>(url, options, true /* isRetry */);
        }

        let body = "";
        try { body = await res.text(); } catch { /* ignore */ }
        throw new Error(`Google API ${res.status} ${res.statusText}: ${body}`);
    }

    // ─── Meet Space Operations ───────────────────────────────────────────────

    async createSpace(): Promise<MeetSpace> {
        const space = await this.meetFetch<any>("spaces", {
            method: "POST",
            body: JSON.stringify({ config: { accessType: "OPEN" } }),
        });
        return {
            spaceName:   space.name        ?? "",
            meetingUri:  space.meetingUri   ?? "",
            meetingCode: space.meetingCode  ?? "",
        };
    }

    async endSpace(spaceName: string): Promise<void> {
        await this.meetFetch(`${spaceName}:endActiveConference`, { method: "POST", body: "{}" });
    }

    // ─── Conference Records (paginated) ─────────────────────────────────────

    async listConferenceRecords(spaceName: string): Promise<ConferenceRecord[]> {
        const filter = encodeURIComponent(`space.name="${spaceName}"`);
        const records: ConferenceRecord[] = [];
        let pageToken: string | undefined;

        do {
            const url = `conferenceRecords?filter=${filter}${pageToken ? `&pageToken=${pageToken}` : ""}`;
            const res = await this.meetFetch<any>(url);
            for (const r of res.conferenceRecords ?? []) {
                records.push({ name: r.name ?? "", startTime: r.startTime ?? "", endTime: r.endTime ?? "" });
            }
            pageToken = res.nextPageToken;
        } while (pageToken);

        return records;
    }

    // ─── Participants (paginated) ────────────────────────────────────────────

    async listParticipants(conferenceRecordName: string): Promise<RawParticipant[]> {
        const participants: RawParticipant[] = [];
        let pageToken: string | undefined;

        do {
            const url = `${conferenceRecordName}/participants${pageToken ? `?pageToken=${pageToken}` : ""}`;
            const res = await this.meetFetch<any>(url);
            for (const p of res.participants ?? []) {
                participants.push({
                    name:              p.name ?? "",
                    displayName:       p.signedinUser?.displayName ?? p.anonymousUser?.displayName ?? p.phoneUser?.displayName ?? "Unknown",
                    participantKey:    p.signedinUser?.user ?? null, // "users/{userId}" or null
                    earliestStartTime: p.earliestStartTime ?? "",
                    latestEndTime:     p.latestEndTime     ?? "",
                });
            }
            pageToken = res.nextPageToken;
        } while (pageToken);

        return participants;
    }

    async getParticipant(participantName: string): Promise<RawParticipant> {
        // e.g. "conferenceRecords/xxx/participants/yyy"
        const p = await this.meetFetch<any>(participantName);
        return {
            name:              p.name ?? participantName,
            displayName:       p.signedinUser?.displayName ?? p.anonymousUser?.displayName ?? p.phoneUser?.displayName ?? "Unknown",
            participantKey:    p.signedinUser?.user ?? null,
            earliestStartTime: p.earliestStartTime ?? "",
            latestEndTime:     p.latestEndTime     ?? "",
        };
    }

    // ─── Workspace Events Subscriptions ─────────────────────────────────────

    async createEventSubscription(spaceName: string, pubsubTopic: string): Promise<WorkspaceSubscription> {
        this.logger.info({ spaceName, pubsubTopic }, "Creating Workspace Events subscription");

        const body = {
            targetResource: `//meet.googleapis.com/${spaceName}`,
            eventTypes: MEET_EVENT_TYPES,
            notificationEndpoint: { pubsubTopic },
        };

        const result = await this.wsFetch<any>("subscriptions", {
            method: "POST",
            body: JSON.stringify(body),
        });

        // createSubscription returns a long-running Operation; actual sub is in .response
        const sub = result.response ?? result;
        return {
            name:           sub.name           ?? "",
            targetResource: sub.targetResource  ?? body.targetResource,
            eventTypes:     sub.eventTypes      ?? MEET_EVENT_TYPES,
            pubsubTopic:    sub.notificationEndpoint?.pubsubTopic ?? pubsubTopic,
            state:          sub.state           ?? "ACTIVE",
            expireTime:     sub.expireTime       ?? "",
        };
    }

    async deleteEventSubscription(subscriptionName: string): Promise<void> {
        await this.wsFetch(subscriptionName, { method: "DELETE" });
        this.logger.info({ subscriptionName }, "Subscription deleted");
    }
}
