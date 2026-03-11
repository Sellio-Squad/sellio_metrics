/**
 * Attendance Module — Service
 *
 * Handles CHECK_IN / CHECK_OUT events with:
 *   - Standard metadata keys (checkin_time, checkout_time, meeting_id, location)
 *   - ISO 8601 validation
 *   - Duration calculation on CHECK_OUT → generates ATTENDANCE_DURATION event
 *   - Orphan handling: warns on CHECK_OUT without matching CHECK_IN
 *   - Multiple sessions per developer supported
 */

import type { D1Service } from "../../infra/database/d1.service";
import type { CacheService } from "../../infra/cache/cache.service";
import type { Logger } from "../../core/logger";
import type { ScoringEvent, AttendanceMetadata } from "../../core/event-types";
import { EventType } from "../../core/event-types";
import type { EventsService } from "../events/events.service";

/** Duration scoring block size in minutes (configurable) */
const DURATION_BLOCK_MINUTES = 15;
/** Stale session timeout in hours */
const STALE_SESSION_HOURS = 8;

export class AttendanceService {
    private readonly d1: D1Service;
    private readonly attendanceKv: CacheService;
    private readonly eventsService: EventsService;
    private readonly logger: Logger;

    constructor({
        d1Service,
        attendanceKvCache,
        eventsService,
        logger,
    }: {
        d1Service: D1Service;
        attendanceKvCache: CacheService;
        eventsService: EventsService;
        logger: Logger;
    }) {
        this.d1 = d1Service;
        this.attendanceKv = attendanceKvCache;
        this.eventsService = eventsService;
        this.logger = logger.child({ module: "attendance" });
    }

    /**
     * Register a CHECK_IN event.
     * Validates checkin_time is present and ISO 8601.
     * Tracks active session in ATTENDANCE_KV.
     */
    async checkIn(
        developerId: string,
        metadata: Partial<AttendanceMetadata>,
    ): Promise<{ eventId: string; inserted: boolean }> {
        // Validate required field
        if (!metadata.checkin_time) {
            throw new Error("checkin_time is required for CHECK_IN");
        }
        this.validateIso8601(metadata.checkin_time, "checkin_time");

        const checkinTime = new Date(metadata.checkin_time).toISOString(); // Normalize to UTC
        const eventId = `checkin:${developerId}:${checkinTime}`;

        const event: ScoringEvent = {
            id: eventId,
            developerId,
            eventType: EventType.CHECK_IN,
            source: "attendance",
            sourceId: metadata.meeting_id,
            eventTimestamp: checkinTime,
            metadata: {
                checkin_time: checkinTime,
                ...(metadata.meeting_id && { meeting_id: metadata.meeting_id }),
                ...(metadata.location && { location: metadata.location }),
            },
        };

        const { inserted } = await this.eventsService.ingest(event);

        if (inserted) {
            // Track active session in ATTENDANCE_KV
            await this.attendanceKv.set(`session:${developerId}`, {
                eventId,
                checkinTime,
                meetingId: metadata.meeting_id || null,
            });
            this.logger.info({ developerId, checkinTime }, "CHECK_IN recorded");
        }

        return { eventId, inserted };
    }

    /**
     * Register a CHECK_OUT event.
     * Finds matching CHECK_IN, calculates duration, and creates ATTENDANCE_DURATION event.
     * Warns if no matching CHECK_IN found (orphan handling).
     */
    async checkOut(
        developerId: string,
        metadata: Partial<AttendanceMetadata>,
    ): Promise<{ eventId: string; inserted: boolean; durationMinutes?: number; warning?: string }> {
        // Validate required field
        if (!metadata.checkout_time) {
            throw new Error("checkout_time is required for CHECK_OUT");
        }
        this.validateIso8601(metadata.checkout_time, "checkout_time");

        const checkoutTime = new Date(metadata.checkout_time).toISOString();
        const eventId = `checkout:${developerId}:${checkoutTime}`;

        // Look for matching CHECK_IN
        const activeSession = await this.attendanceKv.get<{
            eventId: string;
            checkinTime: string;
            meetingId: string | null;
        }>(`session:${developerId}`);

        let durationMinutes: number | undefined;
        let warning: string | undefined;

        if (activeSession?.data) {
            const checkinTime = new Date(activeSession.data.checkinTime).getTime();
            const checkoutTimeMs = new Date(checkoutTime).getTime();
            durationMinutes = Math.round((checkoutTimeMs - checkinTime) / 60000);

            if (durationMinutes < 0) {
                warning = "CHECK_OUT time is before CHECK_IN time — duration set to 0";
                durationMinutes = 0;
            }
        } else {
            // Orphan: CHECK_OUT without matching CHECK_IN
            warning = "No matching CHECK_IN found — CHECK_OUT recorded but no ATTENDANCE_DURATION generated";
            this.logger.warn({ developerId, checkoutTime }, warning);
        }

        // Store CHECK_OUT event
        const checkoutEvent: ScoringEvent = {
            id: eventId,
            developerId,
            eventType: EventType.CHECK_OUT,
            source: "attendance",
            sourceId: metadata.meeting_id || activeSession?.data?.meetingId || undefined,
            eventTimestamp: checkoutTime,
            metadata: {
                checkout_time: checkoutTime,
                ...(durationMinutes !== undefined && { duration_minutes: durationMinutes }),
                ...(metadata.meeting_id && { meeting_id: metadata.meeting_id }),
                ...(metadata.location && { location: metadata.location }),
                ...(warning && { warning }),
            },
        };

        const { inserted } = await this.eventsService.ingest(checkoutEvent);

        // Generate ATTENDANCE_DURATION event if we have a valid duration
        if (inserted && durationMinutes !== undefined && durationMinutes > 0) {
            const durationBlocks = Math.floor(durationMinutes / DURATION_BLOCK_MINUTES);

            if (durationBlocks > 0) {
                const durationEvent: ScoringEvent = {
                    id: `duration:${developerId}:${checkoutTime}`,
                    developerId,
                    eventType: EventType.ATTENDANCE_DURATION,
                    source: "attendance",
                    sourceId: metadata.meeting_id || activeSession?.data?.meetingId || undefined,
                    eventTimestamp: checkoutTime,
                    metadata: {
                        checkin_time: activeSession?.data?.checkinTime,
                        checkout_time: checkoutTime,
                        duration_minutes: durationMinutes,
                        duration_blocks: durationBlocks,
                        block_size_minutes: DURATION_BLOCK_MINUTES,
                    },
                };

                await this.eventsService.ingest(durationEvent);
                this.logger.info(
                    { developerId, durationMinutes, durationBlocks },
                    "ATTENDANCE_DURATION event created",
                );
            }
        }

        // Clear active session
        await this.attendanceKv.del(`session:${developerId}`);

        return { eventId, inserted, durationMinutes, warning };
    }

    /**
     * Get attendance history for a developer or all developers.
     */
    async getHistory(filters: {
        developerId?: string;
        since?: string;
        until?: string;
        limit?: number;
    } = {}): Promise<any[]> {
        return this.d1.queryEvents({
            ...filters,
            eventType: undefined, // Get all attendance-related events
        });
    }

    /**
     * Check for stale sessions (no CHECK_OUT within timeout).
     * Called periodically by cron.
     */
    async closeStaleSessionsNotImplemented(): Promise<void> {
        // Future: query ATTENDANCE_KV for sessions older than STALE_SESSION_HOURS
        // and auto-close them with a warning in metadata
        this.logger.info("Stale session cleanup — not yet implemented");
    }

    // ─── Private ────────────────────────────────────────────

    private validateIso8601(value: string, fieldName: string): void {
        const date = new Date(value);
        if (isNaN(date.getTime())) {
            throw new Error(`${fieldName} must be a valid ISO 8601 timestamp, got: ${value}`);
        }
    }
}
