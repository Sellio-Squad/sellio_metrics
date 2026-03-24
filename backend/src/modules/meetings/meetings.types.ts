/**
 * Meetings Module — Domain Types
 *
 * DB row shapes, API response types, and WebSocket event payload.
 * Uses Google's stable `users/{userId}` identifier instead of email.
 */

// ─── DB Row Shapes ──────────────────────────────────────────────────────────

export interface MeetingSessionRow {
    id: string;
    spaceName: string;
    meetingUri: string;
    meetingCode: string;
    title: string;
    startedAt: string | null;
    endedAt: string | null;
}

/** One row per join-leave pair. Rejoin = new row. */
export interface ParticipantSessionRow {
    /** Composite: "{sessionId}:{participantKey}:{epochMs}" */
    id: string;
    sessionId: string;
    /** "users/{userId}" for signed-in users, display name for anonymous */
    participantKey: string;
    displayName: string;
    startTime: string | null;
    endTime: string | null; // NULL = still inside the meeting
}

// ─── API Response Shapes ────────────────────────────────────────────────────

export interface MeetingResponse {
    id: string;
    title: string;
    spaceName: string;
    meetingUri: string;
    meetingCode: string;
    createdAt: string;
    endedAt: string | null;
    participantCount: number;
    /** false when Pub/Sub subscription could not be created */
    subscribed: boolean;
}

export interface ParticipantResponse {
    participantKey: string;
    displayName: string;
    startTime: string;
    endTime: string | null;
    /** true when end_time IS NULL */
    isActive: boolean;
    totalDurationMinutes: number;
}

export interface MeetingDetailResponse extends MeetingResponse {
    participants: ParticipantResponse[];
}

// ─── WebSocket / Broadcast Event ────────────────────────────────────────────

export type MeetingWSEventType =
    | 'participant_joined'
    | 'participant_left'
    | 'meeting_ended';

export interface MeetingWSEvent {
    type: MeetingWSEventType;
    meetingId: string;
    participant?: Pick<ParticipantResponse, 'participantKey' | 'displayName'>;
    timestamp: string;
}

// ─── Pub/Sub Webhook Input ──────────────────────────────────────────────────

export interface PubSubMessage {
    data: string;       // base64-encoded JSON
    messageId: string;
    publishTime: string;
    attributes?: Record<string, string>;
}

export interface PubSubPushBody {
    message: PubSubMessage;
    subscription: string;
}
