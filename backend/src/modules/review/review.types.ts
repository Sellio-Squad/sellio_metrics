/**
 * Review Module — Types
 *
 * Request/response shapes for the AI code review endpoint.
 */

export interface ReviewRequest {
    owner: string;
    repo: string;
    prNumber: number;
}

export interface PrFileChange {
    filename: string;
    status: "added" | "removed" | "modified" | "renamed" | "copied" | "changed" | "unchanged";
    additions: number;
    deletions: number;
    changes: number;
    patch?: string;
    previousFilename?: string;
}

export interface ReviewResponse {
    pr: {
        number: number;
        title: string;
        author: string;
        url: string;
        state: string;
        additions: number;
        deletions: number;
        changedFiles: number;
        createdAt: string;
        body: string | null;
    };
    files: PrFileChange[];
    review: import("../../infra/ai/gemini.client").GeminiReviewResult;
    reviewedAt: string;
    fromCache?: boolean;
    reviewMeta: {
        totalFiles: number;
        filesReviewed: number;
        filesSkipped: number;
        totalCharsReviewed: number;
        charBudget: number;
    };
}
