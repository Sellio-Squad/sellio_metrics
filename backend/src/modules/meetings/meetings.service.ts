/**
 * Meetings Service
 *
 * Single responsibility: OAuth + meeting CRUD.
 * Does NOT handle webhook events (that is WebhookHandlerService's job).
 */

import type { GoogleMeetClient } from "../../infra/google/google-meet.client";
import type { MeetingsRepository } from "./meetings.repository";
import type { Logger } from "../../core/logger";
import type {
    MeetingResponse,
    MeetingDetailResponse,
    ParticipantResponse,
} from "./meetings.types";

export class MeetingsService {
    private readonly logger: Logger;

    constructor(
        private readonly meetClient: GoogleMeetClient,
        private readonly meetingsRepo: MeetingsRepository,
        private readonly pubsubTopic: string,
        logger: Logger,
    ) {
        this.logger = logger.child({ module: "meetings-service" });
    }

    // ─── OAuth ───────────────────────────────────────────────────────────────

    getAuthUrl(): string { return this.meetClient.getAuthUrl(); }

    async authorize(code: string): Promise<any> {
        this.logger.info("Exchanging auth code for tokens");
        return this.meetClient.authorize(code);
    }

    async isReady(): Promise<boolean> { return this.meetClient.isReady(); }

    async clearCredentials(): Promise<void> { return this.meetClient.clearCredentials(); }

    // ─── Create ──────────────────────────────────────────────────────────────

    async createMeeting(title: string): Promise<MeetingResponse> {
        this.logger.info({ title }, "Creating meeting space");

        const space = await this.meetClient.createSpace();
        const id    = `meet_${Date.now()}`;
        const now   = new Date().toISOString();

        await this.meetingsRepo.upsertSession({
            id,
            spaceName:   space.spaceName,
            meetingUri:  space.meetingUri,
            meetingCode: space.meetingCode,
            title,
            startedAt:   now,
        });

        // Subscribe to Workspace Events so the Pub/Sub webhook fires on join/leave.
        // Failure is non-fatal — the meeting is still usable without real-time events.
        let subscribed = false;
        if (this.pubsubTopic) {
            try {
                await this.meetClient.createEventSubscription(space.spaceName, this.pubsubTopic);
                subscribed = true;
                this.logger.info({ id }, "Workspace Events subscription created");
            } catch (err: any) {
                this.logger.warn({ err: err?.message, id }, "createEventSubscription failed — real-time events disabled");
            }
        }

        this.logger.info({ id, meetingUri: space.meetingUri }, "Meeting created");
        return {
            id,
            title,
            spaceName:        space.spaceName,
            meetingUri:       space.meetingUri,
            meetingCode:      space.meetingCode,
            createdAt:        now,
            endedAt:          null,
            participantCount: 0,
            subscribed,
        };
    }

    // ─── List ────────────────────────────────────────────────────────────────

    async listMeetings(limit = 50): Promise<MeetingResponse[]> {
        const sessions = await this.meetingsRepo.getSessions(limit);
        return sessions.map((s) => ({
            id:               s.id,
            title:            s.title,
            spaceName:        s.spaceName,
            meetingUri:       s.meetingUri,
            meetingCode:      s.meetingCode,
            createdAt:        s.startedAt ?? "",
            endedAt:          s.endedAt   ?? null,
            participantCount: 0,
            subscribed:       true,
        }));
    }

    // ─── Detail ──────────────────────────────────────────────────────────────

    async getMeeting(id: string): Promise<MeetingDetailResponse> {
        const session = await this.requireSession(id);
        const rows    = await this.meetingsRepo.getAllParticipants(id);

        return {
            id:               session.id,
            title:            session.title,
            spaceName:        session.spaceName,
            meetingUri:       session.meetingUri,
            meetingCode:      session.meetingCode,
            createdAt:        session.startedAt   ?? "",
            endedAt:          session.endedAt     ?? null,
            participantCount: rows.filter(r => !r.endTime).length,
            subscribed:       true,
            participants:     rows.map(this.toParticipantResponse),
        };
    }

    // ─── Participants (active only) ───────────────────────────────────────────

    async getActiveParticipants(id: string): Promise<ParticipantResponse[]> {
        await this.requireSession(id);
        const rows = await this.meetingsRepo.getActiveParticipants(id);
        return rows.map(this.toParticipantResponse);
    }

    // ─── End ─────────────────────────────────────────────────────────────────

    async endMeeting(id: string): Promise<void> {
        const session = await this.requireSession(id);
        await this.meetClient.endSpace(session.spaceName);
        await this.meetingsRepo.upsertSession({ ...session, endedAt: new Date().toISOString() });
        this.logger.info({ id }, "Meeting ended");
    }

    // ─── Helpers ─────────────────────────────────────────────────────────────

    private async requireSession(id: string) {
        const session = await this.meetingsRepo.getSessionById(id);
        if (!session) throw new Error(`Meeting not found: ${id}`);
        return session;
    }

    private toParticipantResponse = (r: { participantKey: string; displayName: string; startTime: string | null; endTime: string | null }): ParticipantResponse => {
        const start = r.startTime ? new Date(r.startTime).getTime() : 0;
        const end   = r.endTime   ? new Date(r.endTime).getTime()   : Date.now();
        return {
            participantKey:      r.participantKey,
            displayName:         r.displayName,
            startTime:           r.startTime  ?? "",
            endTime:             r.endTime    ?? null,
            isActive:            r.endTime === null,
            totalDurationMinutes: Math.max(0, Math.round((end - start) / 60000)),
        };
    }
}
