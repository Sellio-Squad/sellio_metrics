/**
 * Metrics — Leaderboard Calculator
 *
 * Single Responsibility: Compute leaderboard scores from PrMetric[].
 *
 * Pure function — no I/O, no dependencies, fully testable.
 * Does NOT know about GitHub, KV, or HTTP.
 *
 * Scoring weights are now dynamic — passed as PointRule[] parameter.
 * Falls back to sensible defaults if no rules provided.
 */

import type { PrMetric, LeaderboardEntry } from "../../core/types";
import type { PointRule } from "../../core/event-types";

/** Default weights — used only when no dynamic rules are provided. */
const DEFAULT_WEIGHTS = {
    prsCreated: 3,
    prsMerged: 2,
    commentsGiven: 1,
    additions: 0.01,
    deletions: 0.01,
} as const;

function resolveWeights(rules?: PointRule[]) {
    if (!rules || rules.length === 0) return DEFAULT_WEIGHTS;

    const lookup = new Map(rules.map((r) => [r.eventType, r.points]));
    return {
        prsCreated: lookup.get("PR_CREATED") ?? DEFAULT_WEIGHTS.prsCreated,
        prsMerged: lookup.get("PR_MERGED") ?? DEFAULT_WEIGHTS.prsMerged,
        commentsGiven: lookup.get("COMMENT") ?? DEFAULT_WEIGHTS.commentsGiven,
        additions: DEFAULT_WEIGHTS.additions, // Not configurable via point rules
        deletions: DEFAULT_WEIGHTS.deletions,
    };
}

export function calculateLeaderboard(prs: PrMetric[], rules?: PointRule[]): LeaderboardEntry[] {
    const WEIGHTS = resolveWeights(rules);

    type Accumulator = {
        avatarUrl: string | null;
        prsCreated: number;
        prsMerged: number;
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
                commentsGiven: 0,
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

        for (const comment of pr.comments) {
            const commenter = ensure(comment.author.login);
            commenter.commentsGiven += comment.count;
            commenter.avatarUrl ??= comment.author.avatar_url;
        }
    }

    return Array.from(scores.entries())
        .map(([login, a]) => ({
            developer: login,
            avatarUrl: a.avatarUrl,
            prsCreated: a.prsCreated,
            prsMerged: a.prsMerged,
            commentsGiven: a.commentsGiven,
            additions: a.additions,
            deletions: a.deletions,
            totalScore:
                a.prsCreated * WEIGHTS.prsCreated +
                a.prsMerged * WEIGHTS.prsMerged +
                a.commentsGiven * WEIGHTS.commentsGiven +
                a.additions * WEIGHTS.additions +
                a.deletions * WEIGHTS.deletions,
        }))
        .sort((a, b) => b.totalScore - a.totalScore);
}
