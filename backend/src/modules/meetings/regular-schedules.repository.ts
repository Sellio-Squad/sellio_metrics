import type { D1Database } from "../../infra/database/d1.service";
import type { Logger } from "../../core/logger";
import type {
    RegularMeetingScheduleRow,
    RegularMeetingScheduleResponse,
    CreateRegularMeetingScheduleBody,
} from "./regular-schedules.types";

/**
 * Repository for regular_meeting_schedules D1 table.
 * CRUD — list, insert, delete.
 */
export class RegularSchedulesRepository {
    private readonly logger: Logger;

    constructor(
        private readonly db: D1Database | null,
        logger: Logger,
    ) {
        this.logger = logger.child({ module: "regular-schedules-repository" });
    }

    // ─── Helpers ─────────────────────────────────────────────────────────────

    private rowToResponse(r: RegularMeetingScheduleRow): RegularMeetingScheduleResponse {
        return {
            id:              r.id,
            title:           r.title,
            description:     r.description,
            dayTime:         r.day_time,
            durationLabel:   r.duration_label,
            recurrenceLabel: r.recurrence_label,
            iconCode:        r.icon_code,
            accentColor:     r.accent_color,
            startTime:       r.start_time,
            durationMinutes: r.duration_minutes,
            recurrenceRule:  r.recurrence_rule,
        };
    }

    // ─── Queries ─────────────────────────────────────────────────────────────

    async findAll(): Promise<RegularMeetingScheduleResponse[]> {
        if (!this.db) return this.defaults();
        try {
            const res = await this.db
                .prepare("SELECT * FROM regular_meeting_schedules ORDER BY created_at ASC")
                .all<RegularMeetingScheduleRow>();
            return res.results.map((r) => this.rowToResponse(r));
        } catch (e) {
            this.logger.warn({ module: "regular-schedules-repository" }, `findAll error: ${e}`);
            return this.defaults();
        }
    }

    async insert(body: CreateRegularMeetingScheduleBody): Promise<RegularMeetingScheduleResponse> {
        const id = body.id ?? crypto.randomUUID();
        const now = new Date().toISOString();

        if (!this.db) {
            return {
                id,
                title:           body.title,
                description:     body.description ?? "",
                dayTime:         body.dayTime,
                durationLabel:   body.durationLabel,
                recurrenceLabel: body.recurrenceLabel,
                iconCode:        body.iconCode,
                accentColor:     body.accentColor,
                startTime:       body.startTime,
                durationMinutes: body.durationMinutes,
                recurrenceRule:  body.recurrenceRule,
            };
        }

        await this.db
            .prepare(
                `INSERT INTO regular_meeting_schedules
                     (id, title, description, day_time, duration_label, recurrence_label,
                      icon_code, accent_color, start_time, duration_minutes, recurrence_rule, created_at)
                 VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12)
                 ON CONFLICT(id) DO UPDATE SET
                     title            = excluded.title,
                     description      = excluded.description,
                     day_time         = excluded.day_time,
                     duration_label   = excluded.duration_label,
                     recurrence_label = excluded.recurrence_label,
                     icon_code        = excluded.icon_code,
                     accent_color     = excluded.accent_color,
                     start_time       = excluded.start_time,
                     duration_minutes = excluded.duration_minutes,
                     recurrence_rule  = excluded.recurrence_rule`
            )
            .bind(
                id,
                body.title,
                body.description ?? "",
                body.dayTime,
                body.durationLabel,
                body.recurrenceLabel,
                body.iconCode,
                body.accentColor,
                body.startTime,
                body.durationMinutes,
                body.recurrenceRule,
                now,
            )
            .run();

        this.logger.info({ module: "regular-schedules-repository" }, `Inserted schedule: ${id}`);

        return {
            id,
            title:           body.title,
            description:     body.description ?? "",
            dayTime:         body.dayTime,
            durationLabel:   body.durationLabel,
            recurrenceLabel: body.recurrenceLabel,
            iconCode:        body.iconCode,
            accentColor:     body.accentColor,
            startTime:       body.startTime,
            durationMinutes: body.durationMinutes,
            recurrenceRule:  body.recurrenceRule,
        };
    }

    async delete(id: string): Promise<void> {
        if (!this.db) return;
        await this.db
            .prepare("DELETE FROM regular_meeting_schedules WHERE id = ?1")
            .bind(id)
            .run();
        this.logger.info({ module: "regular-schedules-repository" }, `Deleted schedule: ${id}`);
    }

    // ─── Static defaults (fallback when DB not ready) ────────────────────────
    // Mirrors FakeRegularMeetingsDataSource so the UI is never empty.

    private defaults(): RegularMeetingScheduleResponse[] {
        return [
            {
                id:              "standup",
                title:           "Daily Standup",
                description:     "Quick sync on blockers and daily progress with the team.",
                dayTime:         "Mon–Fri, 10:00 AM",
                durationLabel:   "15 min",
                recurrenceLabel: "Daily",
                iconCode:        0xe5d5,   // Icons.refresh_rounded
                accentColor:     0xFF6366F1,
                startTime:       new Date().toISOString(),
                durationMinutes: 15,
                recurrenceRule:  "FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR",
            },
            {
                id:              "planning",
                title:           "Sprint Planning",
                description:     "Plan tasks and goals for the next sprint cycle with the squad.",
                dayTime:         "Sunday, 11:00 AM",
                durationLabel:   "1 hr",
                recurrenceLabel: "Biweekly",
                iconCode:        0xe916,   // Icons.calendar_month_rounded
                accentColor:     0xFF0EA5E9,
                startTime:       new Date().toISOString(),
                durationMinutes: 60,
                recurrenceRule:  "FREQ=WEEKLY;INTERVAL=2;BYDAY=SU",
            },
            {
                id:              "code_review",
                title:           "Code Review Session",
                description:     "Pair programming and deep-dive code reviews for open PRs.",
                dayTime:         "Tuesday, 2:00 PM",
                durationLabel:   "1 hr",
                recurrenceLabel: "Weekly",
                iconCode:        0xe86f,   // Icons.code_rounded
                accentColor:     0xFF10B981,
                startTime:       new Date().toISOString(),
                durationMinutes: 60,
                recurrenceRule:  "FREQ=WEEKLY;BYDAY=TU",
            },
            {
                id:              "retrospective",
                title:           "Sprint Retrospective",
                description:     "Review what went well and identify improvements for the team.",
                dayTime:         "Thursday, 3:00 PM",
                durationLabel:   "45 min",
                recurrenceLabel: "Biweekly",
                iconCode:        0xe0bf,   // Icons.forum_rounded
                accentColor:     0xFFF59E0B,
                startTime:       new Date().toISOString(),
                durationMinutes: 45,
                recurrenceRule:  "FREQ=WEEKLY;INTERVAL=2;BYDAY=TH",
            },
        ];
    }
}
