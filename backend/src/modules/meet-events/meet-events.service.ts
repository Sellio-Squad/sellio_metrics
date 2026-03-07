/**
 * Meet Events Module — Service
 *
 * Business logic for real-time Google Meet event tracking.
 * Handles Pub/Sub webhook processing, event storage in KV,
 * and Workspace Events subscription management.
 */

import type { WorkspaceEventsClient } from "../../infra/google/workspace-events.client";
import type { CacheService } from "../../infra/cache/cache.service";
import type { Logger } from "../../core/logger";
import type {
    MeetEvent,
    PubSubPushMessage,
    WorkspaceSubscription,
} from "./meet-events.types";

const EVENTS_CACHE_KEY = "meet_events_log";
const MAX_EVENTS = 200;
const EVENTS_TTL = 30 * 24 * 60 * 60; // 30 days

// ─── Human-readable label map ───────────────────────────────

const EVENT_LABELS: Record<string, string> = {
    "google.workspace.meet.conference.v2.started": "Meeting Started",
    "google.workspace.meet.conference.v2.ended": "Meeting Ended",
    "google.workspace.meet.participant.v2.joined": "Participant Joined",
    "google.workspace.meet.participant.v2.left": "Participant Left",
};

// ─── Service ────────────────────────────────────────────────

export class MeetEventsService {
    private readonly logger: Logger;
    private readonly wsClient: WorkspaceEventsClient;
    private readonly cacheService: CacheService;
    private readonly pubsubTopic: string;

    constructor({
        logger,
        workspaceEventsClient,
        cacheService,
        pubsubTopic,
    }: {
        logger: Logger;
        workspaceEventsClient: WorkspaceEventsClient;
        cacheService: CacheService;
        pubsubTopic: string;
    }) {
        this.logger = logger.child({ module: "meet-events" });
        this.wsClient = workspaceEventsClient;
        this.cacheService = cacheService;
        this.pubsubTopic = pubsubTopic;
    }

    // ─── Subscribe ──────────────────────────────────────────

    /**
     * Create a Workspace Events subscription for a Meet space.
     * Events will be delivered to our Pub/Sub topic → webhook.
     */
    async subscribe(spaceName: string): Promise<WorkspaceSubscription> {
        if (!this.pubsubTopic) {
            throw new Error("GOOGLE_PUBSUB_TOPIC is not configured. Set it in environment variables.");
        }

        this.logger.info({ spaceName, pubsubTopic: this.pubsubTopic }, "Creating event subscription");
        return this.wsClient.createSubscription(spaceName, this.pubsubTopic);
    }

    // ─── Webhook Handler ────────────────────────────────────

    /**
     * Process an incoming Pub/Sub push message.
     * Decodes the base64 payload, extracts event data, and stores it in KV.
     */
    async handleWebhook(body: PubSubPushMessage): Promise<MeetEvent> {
        const { message } = body;

        if (!message?.data) {
            this.logger.warn("Received webhook with no message data");
            throw new Error("Missing message data");
        }

        // Decode base64 payload
        let payload: any;
        try {
            const decoded = atob(message.data);
            payload = JSON.parse(decoded);
        } catch (err) {
            this.logger.error({ err, raw: message.data }, "Failed to decode Pub/Sub message");
            throw new Error("Invalid message data encoding");
        }

        this.logger.info({ messageId: message.messageId, payload }, "📨 Received Meet event");

        // Extract event details from the Workspace Events notification
        const eventType = payload.type || payload["@type"] || "unknown";
        const resourceName = payload.resourceName || payload.name || "";

        // Parse space name and conference from resource
        const spaceName = this.extractSpaceName(resourceName, payload);
        const conferenceId = this.extractConferenceId(resourceName, payload);

        // Build the stored event
        const meetEvent: MeetEvent = {
            id: message.messageId || `evt_${Date.now()}`,
            eventType,
            label: EVENT_LABELS[eventType] || eventType,
            spaceName,
            conferenceId,
            participantInfo: this.extractParticipantInfo(payload),
            timestamp: message.publishTime || new Date().toISOString(),
            raw: payload,
        };

        // Store in KV
        await this.storeEvent(meetEvent);

        this.logger.info(
            { eventId: meetEvent.id, type: meetEvent.label, space: spaceName },
            `✅ Event stored: ${meetEvent.label}`,
        );

        return meetEvent;
    }

    // ─── Query Events ───────────────────────────────────────

    /**
     * Returns the most recent N events from KV.
     */
    async listEvents(limit = 50): Promise<MeetEvent[]> {
        const cached = await this.cacheService.get<MeetEvent[]>(EVENTS_CACHE_KEY);
        const events = cached?.data || [];
        return events.slice(0, limit);
    }

    // ─── Subscriptions ──────────────────────────────────────

    async listSubscriptions(): Promise<WorkspaceSubscription[]> {
        return this.wsClient.listSubscriptions();
    }

    async deleteSubscription(subscriptionName: string): Promise<void> {
        return this.wsClient.deleteSubscription(subscriptionName);
    }

    // ─── Private Helpers ────────────────────────────────────

    private async storeEvent(event: MeetEvent): Promise<void> {
        const cached = await this.cacheService.get<MeetEvent[]>(EVENTS_CACHE_KEY);
        const events = cached?.data || [];

        // Prepend new event (most recent first) and cap at MAX_EVENTS
        events.unshift(event);
        if (events.length > MAX_EVENTS) {
            events.length = MAX_EVENTS;
        }

        await this.cacheService.set(EVENTS_CACHE_KEY, events, EVENTS_TTL);
    }

    private extractSpaceName(resourceName: string, payload: any): string {
        // From resource name like "//meet.googleapis.com/spaces/abc/..."
        const match = resourceName.match(/spaces\/[^/]+/);
        if (match) return match[0];

        // Fallback: check payload fields
        if (payload.space?.name) return payload.space.name;
        if (payload.targetResource) {
            const m = payload.targetResource.match(/spaces\/[^/]+/);
            if (m) return m[0];
        }

        return "";
    }

    private extractConferenceId(resourceName: string, payload: any): string {
        const match = resourceName.match(/conferenceRecords\/[^/]+/);
        if (match) return match[0];

        if (payload.conferenceRecord?.name) return payload.conferenceRecord.name;

        return "";
    }

    private extractParticipantInfo(payload: any): { displayName: string; email: string } | undefined {
        // The event payload may include participant details
        const participant = payload.participant || payload.signedinUser;
        if (!participant) return undefined;

        return {
            displayName: participant.displayName || participant.signedinUser?.displayName || "Unknown",
            email: participant.email || participant.signedinUser?.user || "",
        };
    }
}
