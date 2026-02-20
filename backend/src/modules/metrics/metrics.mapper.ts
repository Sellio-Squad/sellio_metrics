/**
 * Metrics Module — Mapper
 *
 * Transforms raw GitHub API data into domain PrMetric objects.
 * Pure functions — no side effects, no API calls.
 *
 * Separation of concerns: the service orchestrates API calls;
 * the mapper transforms the raw data.
 */

import type {
    UserInfo,
    CommentGroup,
    Approval,
    PrMetric,
} from "../../core/types";
import type { GitHubUser, GitHubReview, GitHubComment } from "../../infra/github/github.types";
import { toISOWeek, minutesBetween } from "../../core/utils/date";

// ─── User Mapping ───────────────────────────────────────────

/** Maps a raw GitHub user to a domain UserInfo. */
export function toUserInfo(user: GitHubUser | null | undefined): UserInfo {
    return {
        login: user?.login ?? "",
        id: user?.id ?? 0,
        url: user?.html_url ?? "",
        avatar_url: user?.avatar_url ?? "",
    };
}

// ─── Comment Mapping ────────────────────────────────────────

/**
 * Groups comments by author, computing first/last/count.
 * Excludes bot comments.
 */
export function groupComments(
    issueComments: GitHubComment[],
    reviewComments: GitHubComment[],
): CommentGroup[] {
    const allComments = [
        ...issueComments.filter((c) => c.user?.type !== "Bot"),
        ...reviewComments.filter((c) => c.user?.type !== "Bot"),
    ];

    const byAuthor = new Map<number, { user: GitHubUser; dates: string[] }>();

    for (const c of allComments) {
        const userId = c.user?.id;
        if (!userId || !c.user) continue;

        const existing = byAuthor.get(userId);
        if (existing) {
            existing.dates.push(c.created_at);
        } else {
            byAuthor.set(userId, { user: c.user, dates: [c.created_at] });
        }
    }

    return [...byAuthor.values()].map((group) => {
        const sorted = group.dates.sort();
        return {
            author: toUserInfo(group.user),
            first_comment_at: sorted[0] ?? null,
            last_comment_at: sorted[sorted.length - 1] ?? null,
            count: sorted.length,
        };
    });
}

// ─── Approval Mapping ───────────────────────────────────────

/**
 * Processes reviews into deduplicated approvals.
 * Keeps latest approval per reviewer; prefers approvals for current commit.
 */
export function processApprovals(
    reviews: GitHubReview[],
    headSha: string,
): Approval[] {
    const approvedReviews = reviews.filter((r) => r.state === "APPROVED");

    // Deduplicate: keep latest per reviewer
    const byReviewer = new Map<number, GitHubReview>();
    for (const review of approvedReviews) {
        const userId = review.user?.id;
        if (!userId) continue;

        const existing = byReviewer.get(userId);
        if (
            !existing ||
            new Date(review.submitted_at) > new Date(existing.submitted_at)
        ) {
            byReviewer.set(userId, review);
        }
    }

    // Prefer current-commit approvals if available
    const all = [...byReviewer.values()];
    const currentCommitApprovals = all.filter((r) => r.commit_id === headSha);
    const rawApprovals = currentCommitApprovals.length > 0
        ? currentCommitApprovals
        : all;

    return rawApprovals
        .sort((a, b) =>
            new Date(a.submitted_at).getTime() - new Date(b.submitted_at).getTime()
        )
        .map((r) => ({
            reviewer: toUserInfo(r.user),
            submitted_at: r.submitted_at,
            commit_id: r.commit_id,
            ...(r.commit_id !== headSha ? { note: "May be for different commit" } : {}),
        }));
}

// ─── PR Status ──────────────────────────────────────────────

export function determinePrStatus(
    mergedAt: string | null,
    closedAt: string | null,
    requiredApprovalsMet: boolean,
): PrMetric["status"] {
    if (mergedAt) return "merged";
    if (closedAt) return "closed";
    if (requiredApprovalsMet) return "approved";
    return "pending";
}

// ─── Full PR Mapping ────────────────────────────────────────

interface PrMappingInput {
    pr: any;  // Raw GitHub PR object
    reviews: GitHubReview[];
    issueComments: GitHubComment[];
    reviewComments: GitHubComment[];
    requiredApprovals: number;
}

/**
 * Assembles a complete PrMetric from raw GitHub API data.
 * This is the main entry point of the mapper.
 */
export function mapToPrMetric(input: PrMappingInput): PrMetric {
    const { pr, reviews, issueComments, reviewComments, requiredApprovals } = input;
    const headSha = pr.head?.sha ?? "";

    // Delegate sub-mappings
    const approvals = processApprovals(reviews, headSha);
    const comments = groupComments(issueComments, reviewComments);
    const assignees = pr.assignees?.length > 0
        ? pr.assignees.map((a: GitHubUser) => toUserInfo(a))
        : [toUserInfo(pr.user)];

    // Compute timing
    const firstApprovedAt = approvals[0]?.submitted_at ?? null;
    const timeToFirstApprovalMinutes = minutesBetween(pr.created_at, firstApprovedAt);

    const requiredMet = approvals.length >= requiredApprovals;
    const requiredMetAt = requiredMet
        ? approvals[requiredApprovals - 1].submitted_at
        : null;
    const timeToRequiredApprovalsMinutes = minutesBetween(pr.created_at, requiredMetAt);

    const mergedAt = pr.merged_at ?? null;
    const closedAt = pr.closed_at ?? null;

    return {
        pr_number: pr.number,
        url: pr.html_url ?? "",
        title: pr.title ?? "",
        opened_at: pr.created_at ?? "",
        head_ref: pr.head?.ref ?? "",
        base_ref: pr.base?.ref ?? "",
        creator: toUserInfo(pr.user),
        assignees,
        comments,
        approvals,
        required_approvals: requiredApprovals,
        first_approved_at: firstApprovedAt,
        time_to_first_approval_minutes: timeToFirstApprovalMinutes,
        required_approvals_met_at: requiredMetAt,
        time_to_required_approvals_minutes: timeToRequiredApprovalsMinutes,
        closed_at: closedAt,
        merged_at: mergedAt,
        merged_by: pr.merged_by ? toUserInfo(pr.merged_by) : null,
        week: toISOWeek(pr.created_at),
        status: determinePrStatus(mergedAt, closedAt, requiredMet),
        labels: (pr.labels ?? []).map((l: any) => l.name ?? l),
        milestone: pr.milestone
            ? { title: pr.milestone.title, number: pr.milestone.number }
            : null,
        draft: pr.draft ?? false,
        review_requests: (pr.requested_reviewers ?? []).map(
            (r: any) => r.login ?? "",
        ),
        files_changed: [],
        diff_stats: {
            additions: pr.additions ?? 0,
            deletions: pr.deletions ?? 0,
            changed_files: pr.changed_files ?? 0,
        },
    };
}
