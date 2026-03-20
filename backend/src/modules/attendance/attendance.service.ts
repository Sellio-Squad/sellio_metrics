/**
 * Attendance Service
 *
 * Manual check-in / check-out for developers who join meetings
 * without using Google Meet (or alongside it).
 *
 * Persists to `meeting_attendance` via D1RelationalService.
 * Uses `attendanceKvCache` only to track the active session
 * (so we can compute duration on check-out).
 *
 * No dependency on EventsService or the old events table.
 */

import type { AttendanceRepository, MeetingAttendance } from "./attendance.repository";
import type { DeveloperRepository } from "../developers/developer.repository";
import type { MeetingsRepository } from "../meetings/meetings.repository";
import type { CacheService } from "../../infra/cache/cache.service";
import type { Logger } from "../../core/logger";

const STALE_SESSION_HOURS = 8;

interface ActiveSession {
    attendanceId: string;
    checkinTime:  string;
    meetingId?:   string;
}

interface CheckInOpts {
    checkin_time?: string;
    meeting_id?:  string;
    location?:    string;
}

interface CheckOutOpts {
    checkout_time?: string;
    meeting_id?:   string;
    location?:     string;
}

export class AttendanceService {
    private readonly attendanceRepo: AttendanceRepository;
    private readonly developerRepo:  DeveloperRepository;
    private readonly meetingsRepo:   MeetingsRepository;
    private readonly attendanceKv:   CacheService;
    private readonly logger:         Logger;

    constructor({
        attendanceRepo,
        developerRepo,
        meetingsRepo,
        attendanceKvCache,
        logger,
    }: {
        attendanceRepo:      AttendanceRepository;
        developerRepo:       DeveloperRepository;
        meetingsRepo:        MeetingsRepository;
        attendanceKvCache:   CacheService;
        logger:              Logger;
    }) {
        this.attendanceRepo = attendanceRepo;
        this.developerRepo  = developerRepo;
        this.meetingsRepo   = meetingsRepo;
        this.attendanceKv   = attendanceKvCache;
        this.logger         = logger.child({ module: "attendance" });
    }

    // ─── Check In ─────────────────────────────────────────────

    async checkIn(
        developerLogin: string,
        opts: CheckInOpts,
    ): Promise<{ attendanceId: string; inserted: boolean }> {
        if (!opts.checkin_time) throw new Error("checkin_time is required");
        this.validateIso8601(opts.checkin_time, "checkin_time");

        const checkinTime  = new Date(opts.checkin_time).toISOString();
        const attendanceId = `checkin:${developerLogin}:${checkinTime}`;
        const sessionId    = opts.meeting_id ?? `manual:${developerLogin}`;

        // Ensure a meeting_session row exists for manual sessions
        if (!opts.meeting_id) {
            await this.meetingsRepo.upsertSession({
                id:        sessionId,
                spaceName: sessionId,
                title:     "Manual attendance",
            });
        }

        // Write a skeleton attendance row (left_at + duration filled on check-out)
        const row: MeetingAttendance = {
            id:              attendanceId,
            sessionId,
            developerLogin,
            joinedAt:        checkinTime,
            durationMinutes: 0,
        };

        await this.developerRepo.upsertDeveloper(developerLogin);
        await this.attendanceRepo.upsertAttendance(row);

        // Track active session in KV for duration calculation on check-out
        const activeSession: ActiveSession = {
            attendanceId,
            checkinTime,
            meetingId: sessionId,
        };
        const staleTtl = STALE_SESSION_HOURS * 60 * 60;
        await this.attendanceKv.set(`session:${developerLogin}`, activeSession, staleTtl);

        this.logger.info({ developerLogin, checkinTime }, "CHECK_IN recorded");
        return { attendanceId, inserted: true };
    }

    // ─── Check Out ────────────────────────────────────────────

    async checkOut(
        developerLogin: string,
        opts: CheckOutOpts,
    ): Promise<{ attendanceId: string; inserted: boolean; durationMinutes?: number; warning?: string }> {
        if (!opts.checkout_time) throw new Error("checkout_time is required");
        this.validateIso8601(opts.checkout_time, "checkout_time");

        const checkoutTime = new Date(opts.checkout_time).toISOString();
        const attendanceId = `checkout:${developerLogin}:${checkoutTime}`;

        const cached = await this.attendanceKv.get<ActiveSession>(`session:${developerLogin}`);

        let durationMinutes: number | undefined;
        let warning: string | undefined;

        if (cached?.data) {
            const checkinMs  = new Date(cached.data.checkinTime).getTime();
            const checkoutMs = new Date(checkoutTime).getTime();
            durationMinutes  = Math.max(0, Math.round((checkoutMs - checkinMs) / 60000));

            if (durationMinutes < 0) {
                warning         = "CHECK_OUT time is before CHECK_IN — duration set to 0";
                durationMinutes = 0;
            }

            // Update the existing attendance row with left_at + duration
            const sessionId = cached.data.meetingId ?? `manual:${developerLogin}`;
            const updated: MeetingAttendance = {
                id:              cached.data.attendanceId,
                sessionId,
                developerLogin,
                joinedAt:        cached.data.checkinTime,
                leftAt:          checkoutTime,
                durationMinutes,
            };
            await this.attendanceRepo.upsertAttendance(updated);
        } else {
            warning = "No matching CHECK_IN found — CHECK_OUT recorded without duration";
            this.logger.warn({ developerLogin, checkoutTime }, warning);

            // Still write a minimal row so we have a record
            const sessionId = opts.meeting_id ?? `manual:${developerLogin}`;
            await this.attendanceRepo.upsertAttendance({
                id:              attendanceId,
                sessionId,
                developerLogin,
                joinedAt:        checkoutTime,
                leftAt:          checkoutTime,
                durationMinutes: 0,
            });
        }

        // Clear active session from KV
        await this.attendanceKv.del(`session:${developerLogin}`);

        this.logger.info({ developerLogin, checkoutTime, durationMinutes }, "CHECK_OUT recorded");
        return { attendanceId, inserted: true, durationMinutes, warning };
    }

    // ─── History ──────────────────────────────────────────────

    async getHistory(filters: {
        developerLogin?: string;
        since?:          string;
        until?:          string;
        limit?:          number;
    } = {}): Promise<MeetingAttendance[]> {
        // N+1 query fixed: DB layer now executes a single optimized query
        return this.attendanceRepo.queryAttendance(filters);
    }

    // ─── Private ─────────────────────────────────────────────

    private validateIso8601(value: string, fieldName: string): void {
        if (isNaN(new Date(value).getTime())) {
            throw new Error(`${fieldName} must be a valid ISO 8601 timestamp, got: ${value}`);
        }
    }
}
