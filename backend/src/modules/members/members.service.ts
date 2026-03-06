/**
 * Members Module — Members Service
 *
 * Dedicated service for parsing PR metrics to determine active/inactive member status.
 */

import type { PrMetric } from "../../core/types";
import type { MemberStatus } from "./members.types";
import type { Logger } from "../../core/logger";

export class MembersService {
    private readonly logger: Logger;

    constructor({ logger }: { logger: Logger }) {
        this.logger = logger.child({ module: "members" });
    }

    /**
     * Calculate member active/inactive status and last activity date.
     * 
     * Takes organization members and finds the latest date they created a PR,
     * submitted a review, or added a comment.
     */
    calculateMemberStatus(prs: PrMetric[], orgMembers: any[]): MemberStatus[] {
        const statuses = new Map<string, {
            avatarUrl: string | null;
            lastActiveDate: string | null;
        }>();

        // 1. Initialize map with all org members (defaults to inactive)
        for (const member of orgMembers) {
            statuses.set(member.login, {
                avatarUrl: member.avatar_url,
                lastActiveDate: null,
            });
        }

        const updateActivity = (login: string, dateStr: string | null) => {
            if (!dateStr) return;
            let entry = statuses.get(login);

            // If the user isn't an org member, we still want to track them if they have activity
            if (!entry) {
                entry = { avatarUrl: null, lastActiveDate: null };
                statuses.set(login, entry);
            }

            // Update if the new date is more recent
            if (!entry.lastActiveDate || new Date(dateStr) > new Date(entry.lastActiveDate)) {
                entry.lastActiveDate = dateStr;
            }
        };

        // 2. Scan all PRs to find latest activity dates
        for (const pr of prs) {
            // PR Creation
            updateActivity(pr.creator.login, pr.opened_at);

            // If avatar is missing, opportunistic update
            const cEntry = statuses.get(pr.creator.login);
            if (cEntry && !cEntry.avatarUrl) cEntry.avatarUrl = pr.creator.avatar_url;

            // Approvals / Reviews
            for (const approval of pr.approvals) {
                updateActivity(approval.reviewer.login, approval.submitted_at);
                const rEntry = statuses.get(approval.reviewer.login);
                if (rEntry && !rEntry.avatarUrl) rEntry.avatarUrl = approval.reviewer.avatar_url;
            }

            // Comments
            for (const comment of pr.comments) {
                // Determine latest comment date
                const latestCommentDate = [comment.first_comment_at, comment.last_comment_at]
                    .filter(Boolean)
                    .sort((a, b) => new Date(b!).getTime() - new Date(a!).getTime())[0] || null;

                updateActivity(comment.author.login, latestCommentDate);
                const coEntry = statuses.get(comment.author.login);
                if (coEntry && !coEntry.avatarUrl) coEntry.avatarUrl = comment.author.avatar_url;
            }
        }

        // 3. Map to final output array
        return Array.from(statuses.entries()).map(([login, data]) => {
            return {
                developer: login,
                avatarUrl: data.avatarUrl,
                isActive: data.lastActiveDate !== null,
                lastActiveDate: data.lastActiveDate,
            };
        }).sort((a, b) => {
            // Sort active members first
            if (a.isActive && !b.isActive) return -1;
            if (!a.isActive && b.isActive) return 1;

            // For active members, sort by most recent activity
            if (a.isActive && b.isActive) {
                return new Date(b.lastActiveDate!).getTime() - new Date(a.lastActiveDate!).getTime();
            }

            // For inactive members, sort alphabetically by login
            return a.developer.localeCompare(b.developer);
        });
    }
}
