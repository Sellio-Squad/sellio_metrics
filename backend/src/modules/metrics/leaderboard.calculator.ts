/**
 * Metrics — Leaderboard Calculator
 *
 * Single Responsibility: Compute leaderboard scores from PrMetric[].
 *
 * Pure function — no I/O, no dependencies, fully testable.
 * Does NOT know about GitHub, KV, or HTTP.
 */

import type { PrMetric, LeaderboardEntry } from "../../core/types";

/** Scoring weights — tune here without touching business logic. */
const WEIGHTS = {
    prsCreated: 3,
    prsMerged: 2,
    reviewsGiven: 0,
    commentsGiven: 1,
    additions: 0.01,
    deletions: 0.01,
} as const;

export function calculateLeaderboard(prs: PrMetric[]): LeaderboardEntry[] {
    type Accumulator = {
        avatarUrl: string | null;
        prsCreated: number;
        prsMerged: number;
        reviewsGiven: number;
        commentsGiven: number;
        additions: number;
        deletions: number;
    };

    const scores = new Map<string, Accumulator>();

    const ensure = (login: string): Accumulator => {
        if (!scores.has(login)) {
            scores.set(login, {
                avatarUrl: null,
                prsCreated: 0, prsMerged: 0,
                reviewsGiven: 0, commentsGiven: 0,
                additions: 0, deletions: 0,
            });
        }
        return scores.get(login)!;
    };

    for (const pr of prs) {
        const creator = ensure(pr.creator.login);
        creator.prsCreated++;
        creator.avatarUrl ??= pr.creator.avatar_url;
        creator.additions += pr.diff_stats.additions;
        creator.deletions += pr.diff_stats.deletions;
        if (pr.status === "merged") creator.prsMerged++;

        for (const approval of pr.approvals) {
            if (approval.reviewer.login === pr.creator.login) continue;
            const reviewer = ensure(approval.reviewer.login);
            reviewer.reviewsGiven++;
            reviewer.avatarUrl ??= approval.reviewer.avatar_url;
        }

        for (const comment of pr.comments) {
            const commenter = ensure(comment.author.login);
            commenter.commentsGiven++;
            commenter.avatarUrl ??= comment.author.avatar_url;
        }
    }

    return Array.from(scores.entries())
        .map(([login, a]) => ({
            developer: login,
            avatarUrl: a.avatarUrl,
            prsCreated: a.prsCreated,
            prsMerged: a.prsMerged,
            reviewsGiven: a.reviewsGiven,
            commentsGiven: a.commentsGiven,
            additions: a.additions,
            deletions: a.deletions,
            totalScore:
                a.prsCreated * WEIGHTS.prsCreated +
                a.prsMerged * WEIGHTS.prsMerged +
                a.reviewsGiven * WEIGHTS.reviewsGiven +
                a.commentsGiven * WEIGHTS.commentsGiven +
                a.additions * WEIGHTS.additions +
                a.deletions * WEIGHTS.deletions,
        }))
        .sort((a, b) => b.totalScore - a.totalScore);
}
