/**
 * Meeting Event Handler — Platform-Agnostic Business Logic
 *
 * Processes participant join/leave/end events and delegates
 * broadcast + persistence to injected abstractions.
 *
 * This class contains ZERO platform-specific code.
 * It works identically whether powered by Cloudflare DOs, Node.js `ws`,
 * or Socket.IO — only the IConnectionManager implementation changes.
 */

import type { IConnectionManager } from "./connection-manager";
import type { MeetingsRepository } from "../meetings.repository";
import type { MeetingWSEvent, ParticipantSessionRow } from "../meetings.types";
import type { Logger } from "../../../core/logger";
import type { LogsService } from "../../logs/logs.service";

// ─── Incoming Event Shape ───────────────────────────────────────────────────

export interface IncomingMeetEvent {
    sessionId: string;
    event: {
        type: string;
        spaceName: string;
        participantKey: string | null;
        displayName: string;
        timestamp: string;
    };
}

// ─── Handler ────────────────────────────────────────────────────────────────

export class MeetingEventHandler {
    constructor(
        private readonly connectionManager: IConnectionManager,
        private readonly repo: MeetingsRepository,
        private readonly logger: Logger,
        private readonly logsService: LogsService | null = null,
    ) {}

    /**
     * Route an incoming event to the appropriate handler.
     * Returns true if the event was a meeting_ended (caller may want to tear down).
     */
    async handleEvent(body: IncomingMeetEvent): Promise<{ meetingEnded: boolean }> {
        const { sessionId, event } = body;
        const now = event.timestamp;

        try {
            switch (event.type) {
                case "google.workspace.meet.participant.v2.joined":
                    await this.onParticipantJoined(sessionId, event, now);
                    return { meetingEnded: false };

                case "google.workspace.meet.participant.v2.left":
                    await this.onParticipantLeft(sessionId, event, now);
                    return { meetingEnded: false };

                case "google.workspace.meet.conference.v2.ended":
                    await this.onMeetingEnded(sessionId, now);
                    return { meetingEnded: true };

                default:
                    this.logger.info({ type: event.type }, "Unrecognized event type — ignoring");
                    return { meetingEnded: false };
            }
        } catch (err: any) {
            this.logger.error({ err: err?.message, sessionId, type: event.type }, "Error processing event");
            if (this.logsService) {
                await this.logsService.log(
                    `Event handler error: ${err?.message}`,
                    "error",
                    "googleMeet",
                    { type: event.type, trace: err?.stack },
                );
            }
            return { meetingEnded: false };
        }
    }

    // ─── Participant Joined ─────────────────────────────────────────────────

    private async onParticipantJoined(
        sessionId: string,
        event: IncomingMeetEvent["event"],
        now: string,
    ): Promise<void> {
        const participantKey = event.participantKey ?? event.displayName;

        const row: ParticipantSessionRow = {
            id:             `${sessionId}:${participantKey}:${Date.parse(now)}`,
            sessionId,
            participantKey,
            displayName:    event.displayName,
            startTime:      now,
            endTime:        null,
        };

        try {
            await this.repo.insertParticipantJoin(row);
            if (this.logsService) {
                await this.logsService.log(`DB inserted joined: ${participantKey}`, "success", "googleMeet");
            }
        } catch (err: any) {
            if (this.logsService) {
                await this.logsService.log(`DB insert error: ${err.message}`, "error", "googleMeet", { stack: err.stack });
            }
            throw err;
        }

        this.broadcastEvent({
            type:        "participant_joined",
            meetingId:   sessionId,
            participant: { participantKey, displayName: event.displayName },
            timestamp:   now,
        });

        this.logger.info({ sessionId, participantKey }, "Participant joined");
    }

    // ─── Participant Left ───────────────────────────────────────────────────

    private async onParticipantLeft(
        sessionId: string,
        event: IncomingMeetEvent["event"],
        now: string,
    ): Promise<void> {
        const participantKey = event.participantKey ?? event.displayName;

        await this.repo.markParticipantLeft(sessionId, participantKey, now);

        this.broadcastEvent({
            type:        "participant_left",
            meetingId:   sessionId,
            participant: { participantKey, displayName: event.displayName },
            timestamp:   now,
        });

        this.logger.info({ sessionId, participantKey }, "Participant left");
    }

    // ─── Meeting Ended ──────────────────────────────────────────────────────

    private async onMeetingEnded(sessionId: string, now: string): Promise<void> {
        // 1. Close all open participant sessions in DB
        await this.repo.closeAllParticipantSessions(sessionId, now);

        // 2. Broadcast meeting_ended to all connected clients
        this.broadcastEvent({ type: "meeting_ended", meetingId: sessionId, timestamp: now });

        // 3. Close all WebSocket connections
        this.connectionManager.closeAll(1000, "Meeting ended");

        this.logger.info({ sessionId }, "Meeting ended — all WebSocket connections closed");
    }

    // ─── Broadcast Helper ───────────────────────────────────────────────────

    private broadcastEvent(event: MeetingWSEvent): void {
        const payload = JSON.stringify(event);
        const result  = this.connectionManager.broadcast(payload);

        this.logger.info(
            { type: event.type, sent: result.sent, failed: result.failed },
            "Broadcast sent",
        );
    }
}
