/**
 * Meetings Module — Service
 *
 * Business orchestration for Google Meet integration.
 * Manages meeting lifecycle, attendance tracking, and analytics.
 * All scoring logic lives here (on the backend).
 */

import type { GoogleMeetClient } from "../../infra/google/google-meet.client";
import type { CacheService } from "../../infra/cache/cache.service";
import type { Logger } from "../../core/logger";
import type {
    MeetingSpace,
    MeetingDetail,
    AttendanceRecord,
    AttendanceAnalytics,
    RateLimitInfo,
    Participant,
} from "./meetings.types";
import { mapParticipants, aggregateAnalytics } from "./meetings.mapper";

// ─── In-Memory Storage ──────────────────────────────────────

interface StoredMeeting {
    id: string;
    title: string;
    spaceName: string;
    meetingUri: string;
    meetingCode: string;
    createdAt: string;
}

// ─── Service ────────────────────────────────────────────────

export class MeetingsService {
    private readonly logger: Logger;
    private readonly meetClient: GoogleMeetClient;
    private readonly cacheService: CacheService;

    constructor({ logger, googleMeetClient, cacheService }: { logger: Logger; googleMeetClient: GoogleMeetClient; cacheService: CacheService }) {
        this.logger = logger.child({ module: "meetings" });
        this.meetClient = googleMeetClient;
        this.cacheService = cacheService;
    }

    private async getMeetings(): Promise<Map<string, StoredMeeting>> {
        const res = await this.cacheService.get<StoredMeeting[]>("meetings_list");
        const list = res?.data || [];
        const map = new Map<string, StoredMeeting>();
        for (const m of list) map.set(m.id, m);
        return map;
    }

    private async saveMeetings(map: Map<string, StoredMeeting>): Promise<void> {
        const list = Array.from(map.values());
        // Store for 30 days
        await this.cacheService.set("meetings_list", list, 30 * 24 * 60 * 60);
    }

    // ─── OAuth2 Authentication ──────────────────────────────

    getAuthUrl(): string {
        return this.meetClient.getAuthUrl();
    }

    async authorize(code: string): Promise<any> {
        this.logger.info("Exchanging auth code for tokens...");
        return this.meetClient.authorize(code);
    }

    async isReady(): Promise<boolean> {
        return this.meetClient.isReady();
    }

    async clearCredentials(): Promise<void> {
        await this.meetClient.clearCredentials();
    }

    // ─── Create ─────────────────────────────────────────────

    async createMeeting(title: string): Promise<MeetingSpace> {
        this.logger.info({ title }, "Creating new meeting");

        const space = await this.meetClient.createSpace();

        const id = `meet_${Date.now()}_${Math.floor(Math.random() * 10000)}`;
        const stored: StoredMeeting = {
            id,
            title,
            spaceName: space.spaceName,
            meetingUri: space.meetingUri,
            meetingCode: space.meetingCode,
            createdAt: new Date().toISOString(),
        };

        const map = await this.getMeetings();
        map.set(id, stored);
        await this.saveMeetings(map);

        this.logger.info({ id, meetingUri: space.meetingUri }, "✅ Meeting created");

        return {
            ...stored,
            participantCount: 0,
        };
    }

    // ─── List ───────────────────────────────────────────────

    async listMeetings(): Promise<MeetingSpace[]> {
        const map = await this.getMeetings();
        const list = Array.from(map.values());

        return list
            .map((m) => ({
                id: m.id,
                title: m.title,
                spaceName: m.spaceName,
                meetingUri: m.meetingUri,
                meetingCode: m.meetingCode,
                createdAt: m.createdAt,
                participantCount: 0, // Live count fetched on detail
            }))
            .sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());
    }

    // ─── Get Detail ─────────────────────────────────────────

    async getMeeting(id: string): Promise<MeetingDetail> {
        const map = await this.getMeetings();
        const meeting = map.get(id);
        if (!meeting) {
            throw new Error(`Meeting not found: ${id}`);
        }

        // Try to fetch live participants from conference records
        let participants: Participant[] = [];
        try {
            const records = await this.meetClient.listConferenceRecords(meeting.spaceName);

            if (records.length > 0) {
                // Get participants from the most recent conference
                const latestRecord = records[records.length - 1];
                const rawParticipants = await this.meetClient.listParticipants(latestRecord.name);

                participants = mapParticipants(
                    rawParticipants,
                    latestRecord.startTime,
                    latestRecord.endTime || null,
                );
            }
        } catch (error) {
            this.logger.warn({ err: error, id }, "Could not fetch live participants");
        }

        return {
            id: meeting.id,
            title: meeting.title,
            spaceName: meeting.spaceName,
            meetingUri: meeting.meetingUri,
            meetingCode: meeting.meetingCode,
            createdAt: meeting.createdAt,
            participantCount: participants.length,
            participants,
        };
    }

    async endMeeting(id: string): Promise<void> {
        const map = await this.getMeetings();
        const meeting = map.get(id);
        if (!meeting) {
            throw new Error(`Meeting not found: ${id}`);
        }

        await this.meetClient.endSpace(meeting.spaceName);
        this.logger.info({ id, spaceName: meeting.spaceName }, "Ended meeting");
    }

    // ─── Attendance ─────────────────────────────────────────

    async getAttendance(meetingId: string): Promise<AttendanceRecord> {
        const map = await this.getMeetings();
        const meeting = map.get(meetingId);
        if (!meeting) {
            throw new Error(`Meeting not found: ${meetingId}`);
        }

        let participants: Participant[] = [];
        let totalDurationMinutes = 0;

        try {
            const records = await this.meetClient.listConferenceRecords(meeting.spaceName);

            for (const record of records) {
                const rawParticipants = await this.meetClient.listParticipants(record.name);
                const mapped = mapParticipants(
                    rawParticipants,
                    record.startTime,
                    record.endTime || null,
                );
                participants.push(...mapped);

                // Calculate total meeting duration
                const start = new Date(record.startTime).getTime();
                const end = record.endTime ? new Date(record.endTime).getTime() : Date.now();
                totalDurationMinutes += Math.round((end - start) / 60000);
            }
        } catch (error) {
            this.logger.warn({ err: error, meetingId }, "Could not fetch attendance data");
        }

        // De-duplicate participants (same person across conference records)
        const uniqueMap = new Map<string, Participant>();
        for (const p of participants) {
            const key = p.email ?? p.displayName;
            const existing = uniqueMap.get(key);
            if (!existing || p.durationMinutes > existing.durationMinutes) {
                uniqueMap.set(key, p);
            }
        }

        return {
            meetingId: meeting.id,
            meetingTitle: meeting.title,
            meetingDate: meeting.createdAt,
            totalDurationMinutes,
            participants: Array.from(uniqueMap.values())
                .sort((a, b) => b.attendanceScore - a.attendanceScore),
        };
    }

    // ─── Analytics ──────────────────────────────────────────

    async getAnalytics(): Promise<AttendanceAnalytics> {
        const map = await this.getMeetings();
        const meetingsList = Array.from(map.values());

        const meetingsWithParticipants: Array<{
            id: string;
            title: string;
            createdAt: string;
            participants: Participant[];
        }> = [];

        for (const meeting of meetingsList) {
            try {
                const records = await this.meetClient.listConferenceRecords(meeting.spaceName);
                let allParticipants: Participant[] = [];

                for (const record of records) {
                    const rawParticipants = await this.meetClient.listParticipants(record.name);
                    allParticipants.push(
                        ...mapParticipants(rawParticipants, record.startTime, record.endTime || null),
                    );
                }

                meetingsWithParticipants.push({
                    id: meeting.id,
                    title: meeting.title,
                    createdAt: meeting.createdAt,
                    participants: allParticipants,
                });
            } catch (error) {
                this.logger.warn({ err: error, meetingId: meeting.id }, "Skipping meeting in analytics");
            }
        }

        return aggregateAnalytics(meetingsWithParticipants);
    }

    // ─── Rate Limit Status ──────────────────────────────────

    getRateLimitStatus(): RateLimitInfo {
        return this.meetClient.getRateLimitStatus();
    }
}
