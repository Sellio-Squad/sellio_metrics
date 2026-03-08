/**
 * Metrics — Members Calculator
 *
 * Single Responsibility: Compute member active/inactive status from
 * PrMetric[] and a list of GitHub org members.
 *
 * Pure function — no I/O, no dependencies, fully testable.
 * Does NOT know about GitHub API, KV, or HTTP.
 * Replaces MembersService class and the entire modules/members/ folder.
 */

import type { PrMetric } from "../../core/types";

export interface MemberStatus {
    developer: string;
    avatarUrl: string | null;
    isActive: boolean;
    lastActiveDate: string | null;
}

export function calculateMemberStatus(
    prs: PrMetric[],
    orgMembers: Array<{ login: string; avatar_url: string }>,
): MemberStatus[] {
    const activity = new Map<string, { avatarUrl: string | null; lastActiveDate: string | null }>();

    // Seed with all org members (defaults to inactive)
    for (const member of orgMembers) {
        activity.set(member.login, { avatarUrl: member.avatar_url, lastActiveDate: null });
    }

    const updateActivity = (login: string, dateStr: string | null, avatarUrl?: string) => {
        if (!dateStr) return;
        let entry = activity.get(login);
        if (!entry) {
            entry = { avatarUrl: avatarUrl ?? null, lastActiveDate: null };
            activity.set(login, entry);
        }
        if (!entry.lastActiveDate || new Date(dateStr) > new Date(entry.lastActiveDate)) {
            entry.lastActiveDate = dateStr;
        }
        if (avatarUrl && !entry.avatarUrl) entry.avatarUrl = avatarUrl;
    };

    for (const pr of prs) {
        updateActivity(pr.creator.login, pr.opened_at, pr.creator.avatar_url);

        for (const approval of pr.approvals) {
            updateActivity(approval.reviewer.login, approval.submitted_at, approval.reviewer.avatar_url);
        }

        for (const comment of pr.comments) {
            const latest = [comment.first_comment_at, comment.last_comment_at]
                .filter(Boolean)
                .sort((a, b) => new Date(b!).getTime() - new Date(a!).getTime())[0] || null;
            updateActivity(comment.author.login, latest, comment.author.avatar_url);
        }
    }

    return Array.from(activity.entries())
        .map(([login, data]) => ({
            developer: login,
            avatarUrl: data.avatarUrl,
            isActive: data.lastActiveDate !== null,
            lastActiveDate: data.lastActiveDate,
        }))
        .sort((a, b) => {
            if (a.isActive && !b.isActive) return -1;
            if (!a.isActive && b.isActive) return 1;
            if (a.isActive && b.isActive) {
                return new Date(b.lastActiveDate!).getTime() - new Date(a.lastActiveDate!).getTime();
            }
            return a.developer.localeCompare(b.developer);
        });
}
