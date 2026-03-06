/**
 * Meetings Module — Service
 *
 * Business orchestration for Google Meet integration.
 * Manages meeting lifecycle, attendance tracking, and analytics.
 * All scoring logic lives here (on the backend).
 */

import type { GoogleMeetClient } from "../../infra/google/google-meet.client";
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
    private readonly meetings: Map<string, StoredMeeting> = new Map();
    private idCounter = 0;

    constructor({ logger, googleMeetClient }: { logger: Logger; googleMeetClient: GoogleMeetClient }) {
        this.logger = logger.child({ module: "meetings" });
        this.meetClient = googleMeetClient;
    }

    // ─── OAuth2 Authentication ──────────────────────────────

    getAuthUrl(): string {
        return this.meetClient.getAuthUrl();
    }

    async authorize(code: string): Promise<any> {
        this.logger.info("Exchanging auth code for tokens...");
        return this.meetClient.authorize(code);
    }

    isReady(): boolean {
        return this.meetClient.isReady();
    }

    clearCredentials(): void {
        this.meetClient.clearCredentials();
    }

    // ─── Create ─────────────────────────────────────────────

    async createMeeting(title: string): Promise<MeetingSpace> {
        this.logger.info({ title }, "Creating new meeting");

        const space = await this.meetClient.createSpace();

        const id = `meet_${++this.idCounter}_${Date.now()}`;
        const stored: StoredMeeting = {
            id,
            title,
            spaceName: space.spaceName,
            meetingUri: space.meetingUri,
            meetingCode: space.meetingCode,
            createdAt: new Date().toISOString(),
        };

        this.meetings.set(id, stored);

        this.logger.info({ id, meetingUri: space.meetingUri }, "✅ Meeting created");

        return {
            ...stored,
            participantCount: 0,
        };
    }

    // ─── List ───────────────────────────────────────────────

    async listMeetings(): Promise<MeetingSpace[]> {
        const list = Array.from(this.meetings.values());

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
        const meeting = this.meetings.get(id);
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
        const meeting = this.meetings.get(id);
        if (!meeting) {
            throw new Error(`Meeting not found: ${id}`);
        }

        await this.meetClient.endSpace(meeting.spaceName);
        this.logger.info({ id, spaceName: meeting.spaceName }, "Ended meeting");
    }

    // ─── Attendance ─────────────────────────────────────────

    async getAttendance(meetingId: string): Promise<AttendanceRecord> {
        const meeting = this.meetings.get(meetingId);
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
        const meetingsList = Array.from(this.meetings.values());

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
