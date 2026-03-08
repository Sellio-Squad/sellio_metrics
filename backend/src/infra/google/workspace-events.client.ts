/**
 * Sellio Metrics Backend — Google Workspace Events Client
 *
 * Low-level wrapper around the Workspace Events REST API.
 * Creates/manages subscriptions for Google Meet events
 * that are delivered via Pub/Sub push to our webhook.
 *
 * Uses the same OAuth2 credentials as GoogleMeetClient.
 */

import type { CacheService } from "../cache/cache.service";
import type { Logger } from "../../core/logger";
import type { WorkspaceSubscription } from "../../modules/meet-events/meet-events.types";

const WORKSPACE_EVENTS_BASE = "https://workspaceevents.googleapis.com/v1";

/**
 * Google Meet event types supported by Workspace Events API.
 * @see https://developers.google.com/workspace/events/guides/events-meet
 */
const MEET_EVENT_TYPES = [
    "google.workspace.meet.conference.v2.started",
    "google.workspace.meet.conference.v2.ended",
    "google.workspace.meet.participant.v2.joined",
    "google.workspace.meet.participant.v2.left",
];

export class WorkspaceEventsClient {
    private readonly logger: Logger;
    private readonly cacheService: CacheService;

    constructor({ logger, cacheService }: { logger: Logger; cacheService: CacheService }) {
        this.logger = logger.child({ module: "workspace-events-client" });
        this.cacheService = cacheService;
    }

    // ─── Token Retrieval ────────────────────────────────────

    private async getAccessToken(): Promise<string> {
        // Reuse the same cached Google OAuth tokens as GoogleMeetClient
        const cached = await this.cacheService.get<any>("google_oauth_tokens");
        if (!cached?.data?.access_token) {
            throw new Error("Not authorized — no Google OAuth tokens found. Please sign in first.");
        }

        // If we have a refresh_token and the token might be expired, we need to
        // rely on GoogleMeetClient having refreshed it. For now, use the stored token.
        return cached.data.access_token;
    }

    // ─── Generic Fetch Wrapper ──────────────────────────────

    private async apiFetch<T>(endpoint: string, options: RequestInit = {}): Promise<T> {
        const accessToken = await this.getAccessToken();

        const url = endpoint.startsWith("http")
            ? endpoint
            : `${WORKSPACE_EVENTS_BASE}/${endpoint}`;

        const fetchOptions: RequestInit = {
            ...options,
            headers: {
                Authorization: `Bearer ${accessToken}`,
                "Content-Type": "application/json",
                ...options.headers,
            },
        };

        const maxRetries = 3;
        for (let attempt = 0; attempt <= maxRetries; attempt++) {
            const res = await fetch(url, fetchOptions);

            if (res.ok) {
                if (res.status === 204 || res.headers.get("content-length") === "0") return {} as T;
                return (await res.json()) as T;
            }

            if (res.status === 429 || (res.status >= 500 && res.status < 600)) {
                if (attempt < maxRetries) {
                    const delayMs = Math.pow(2, attempt) * 1000 + Math.random() * 500;
                    this.logger.warn({ attempt, delayMs, status: res.status, url }, "⚠️ Rate limited / Server Error — retrying");
                    await new Promise((r) => setTimeout(r, delayMs));
                    continue;
                }
            }

            let errBody = "";
            try { errBody = await res.text(); } catch { }
            throw new Error(`Workspace Events API failed: ${res.status} ${res.statusText} - ${errBody}`);
        }
        throw new Error("Exhausted retries");
    }

    // ─── Subscription Operations ────────────────────────────

    /**
     * Create a Workspace Events subscription for a Google Meet space.
     *
     * @param spaceName - The Meet space resource name (e.g. "spaces/abc123")
     * @param pubsubTopic - Fully-qualified Pub/Sub topic (e.g. "projects/xxx/topics/meet-events-topic")
     */
    async createSubscription(spaceName: string, pubsubTopic: string): Promise<WorkspaceSubscription> {
        this.logger.info({ spaceName, pubsubTopic }, "Creating Workspace Events subscription");

        // The target resource must be in the format: //meet.googleapis.com/spaces/xxx
        const targetResource = `//meet.googleapis.com/${spaceName}`;

        const body = {
            targetResource,
            eventTypes: MEET_EVENT_TYPES,
            notificationEndpoint: {
                pubsubTopic,
            },
        };

        const result = await this.apiFetch<any>("subscriptions", {
            method: "POST",
            body: JSON.stringify(body),
        });

        this.logger.info({ subscriptionName: result.name || result.response?.name }, "✅ Subscription created");

        // The create call returns a long-running operation.
        // The actual subscription is in result.response or result directly
        const sub = result.response || result;

        return {
            name: sub.name ?? "",
            targetResource: sub.targetResource ?? targetResource,
            eventTypes: sub.eventTypes ?? MEET_EVENT_TYPES,
            pubsubTopic: sub.notificationEndpoint?.pubsubTopic ?? pubsubTopic,
            state: sub.state ?? "ACTIVE",
            expireTime: sub.expireTime ?? "",
        };
    }

    /**
     * Get details of an existing subscription.
     */
    async getSubscription(subscriptionName: string): Promise<WorkspaceSubscription> {
        const result = await this.apiFetch<any>(subscriptionName);
        return {
            name: result.name ?? "",
            targetResource: result.targetResource ?? "",
            eventTypes: result.eventTypes ?? [],
            pubsubTopic: result.notificationEndpoint?.pubsubTopic ?? "",
            state: result.state ?? "",
            expireTime: result.expireTime ?? "",
        };
    }

    /**
     * List all active subscriptions.
     * Filters by Meet event types.
     */
    async listSubscriptions(): Promise<WorkspaceSubscription[]> {
        try {
            const filter = encodeURIComponent(`event_types:"google.workspace.meet"`);
            const result = await this.apiFetch<any>(`subscriptions?filter=${filter}`);
            const subscriptions = result.subscriptions || [];

            return subscriptions.map((s: any) => ({
                name: s.name ?? "",
                targetResource: s.targetResource ?? "",
                eventTypes: s.eventTypes ?? [],
                pubsubTopic: s.notificationEndpoint?.pubsubTopic ?? "",
                state: s.state ?? "",
                expireTime: s.expireTime ?? "",
            }));
        } catch (error) {
            this.logger.warn({ err: error }, "Could not list subscriptions");
            return [];
        }
    }

    /**
     * Delete a subscription.
     */
    async deleteSubscription(subscriptionName: string): Promise<void> {
        await this.apiFetch(subscriptionName, { method: "DELETE" });
        this.logger.info({ subscriptionName }, "🗑️ Subscription deleted");
    }
}
