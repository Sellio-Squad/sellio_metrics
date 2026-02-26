/**
 * Metrics Module — Leaderboard Service
 *
 * Dedicated service for parsing PR metrics into leaderboard scores.
 * Enforces Separation of Concerns (SoC) and Single Responsibility Principle (SRP).
 */

import type { PrMetric, LeaderboardEntry } from "../../core/types";
import type { Logger } from "../../core/logger";

export class LeaderboardService {
    private readonly logger: Logger;

    // Leaderboard point weights
    private readonly weights = {
        prsCreated: 3,
        prsMerged: 2,
        reviewsGiven: 0,
        commentsGiven: 1,
        additions: 0.01,
        deletions: 0.01,
    };

    constructor({ logger }: { logger: Logger }) {
        this.logger = logger.child({ module: "leaderboard" });
    }

    /**
     * Calculate leaderboard entries from a list of PRs.
     */
    calculateLeaderboard(prs: PrMetric[]): LeaderboardEntry[] {
        const scores = new Map<string, {
            avatarUrl: string | null;
            prsCreated: number;
            prsMerged: number;
            reviewsGiven: number;
            commentsGiven: number;
            additions: number;
            deletions: number;
        }>();

        const getOrCreate = (login: string) => {
            let entry = scores.get(login);
            if (!entry) {
                entry = {
                    avatarUrl: null,
                    prsCreated: 0,
                    prsMerged: 0,
                    reviewsGiven: 0,
                    commentsGiven: 0,
                    additions: 0,
                    deletions: 0,
                };
                scores.set(login, entry);
            }
            return entry;
        };

        for (const pr of prs) {
            const creator = pr.creator.login;
            const cEntry = getOrCreate(creator);
            cEntry.prsCreated++;
            cEntry.avatarUrl ??= pr.creator.avatar_url;
            cEntry.additions += pr.diff_stats.additions;
            cEntry.deletions += pr.diff_stats.deletions;

            if (pr.status === "merged") cEntry.prsMerged++;

            for (const approval of pr.approvals) {
                const reviewer = approval.reviewer.login;
                if (reviewer === creator) continue;
                const rEntry = getOrCreate(reviewer);
                rEntry.reviewsGiven++;
                rEntry.avatarUrl ??= approval.reviewer.avatar_url;
            }

            for (const comment of pr.comments) {
                const commenter = comment.author.login;
                const coEntry = getOrCreate(commenter);
                coEntry.commentsGiven++;
                coEntry.avatarUrl ??= comment.author.avatar_url;
            }
        }

        return Array.from(scores.entries()).map(([login, a]) => {
            const totalScore =
                a.prsCreated * this.weights.prsCreated +
                a.prsMerged * this.weights.prsMerged +
                a.reviewsGiven * this.weights.reviewsGiven +
                a.commentsGiven * this.weights.commentsGiven +
                a.additions * this.weights.additions +
                a.deletions * this.weights.deletions;

            return {
                developer: login,
                avatarUrl: a.avatarUrl,
                prsCreated: a.prsCreated,
                prsMerged: a.prsMerged,
                reviewsGiven: a.reviewsGiven,
                commentsGiven: a.commentsGiven,
                additions: a.additions,
                deletions: a.deletions,
                totalScore,
            };
        }).sort((a, b) => b.totalScore - a.totalScore);
    }
}
