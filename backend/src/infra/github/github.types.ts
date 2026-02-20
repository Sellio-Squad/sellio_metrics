/**
 * Sellio Metrics Backend — GitHub Raw Types
 *
 * Types from the GitHub REST API that are used by mappers
 * to transform raw responses into domain types.
 * Kept separate to avoid coupling domain types to GitHub's schema.
 */

/** Minimal user object from GitHub API responses. */
export interface GitHubUser {
    login: string;
    id: number;
    html_url: string;
    avatar_url: string;
    type: string;
}

/** A GitHub review (from pulls.listReviews). */
export interface GitHubReview {
    id: number;
    user: GitHubUser | null;
    state: string;
    submitted_at: string;
    commit_id: string;
}

/** A GitHub comment (issue or review comment). */
export interface GitHubComment {
    id: number;
    user: GitHubUser | null;
    created_at: string;
}
