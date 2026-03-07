/**
 * Meet Events Module — Domain Types
 *
 * Types for real-time Google Meet event tracking
 * via Workspace Events + Pub/Sub push delivery.
 */

// ─── Pub/Sub Push Message (from GCP) ────────────────────────

export interface PubSubPushMessage {
    message: {
        data: string;          // base64-encoded JSON
        messageId: string;
        publishTime: string;
        attributes?: Record<string, string>;
    };
    subscription: string;
}

// ─── Workspace Event Envelope ───────────────────────────────

export interface WorkspaceEventPayload {
    /** Full event type, e.g. "google.workspace.meet.participant.v2.joined" */
    type: string;
    /** Affected resource name, e.g. "conferenceRecords/xxx/participants/yyy" */
    resourceName?: string;
    /** Additional event data */
    [key: string]: unknown;
}

// ─── Stored Meet Event ──────────────────────────────────────

export interface MeetEvent {
    /** Unique ID (Pub/Sub messageId or generated) */
    id: string;
    /** Event type, e.g. "participant.joined" or raw type */
    eventType: string;
    /** Human-readable event label */
    label: string;
    /** Affected space name if available */
    spaceName: string;
    /** Conference record name if available */
    conferenceId: string;
    /** Participant info if join/leave event */
    participantInfo?: {
        displayName: string;
        email: string;
    };
    /** When the event occurred */
    timestamp: string;
    /** Raw payload for debugging */
    raw: Record<string, unknown>;
}

// ─── Workspace Events Subscription ──────────────────────────

export interface WorkspaceSubscription {
    /** Resource name, e.g. "subscriptions/xxx" */
    name: string;
    /** Target resource, e.g. "//meet.googleapis.com/spaces/xxx" */
    targetResource: string;
    /** Event types subscribed to */
    eventTypes: string[];
    /** Pub/Sub topic for delivery */
    pubsubTopic: string;
    /** Subscription state */
    state: string;
    /** Expiration time (ISO 8601) */
    expireTime: string;
}
