/**
 * GitHub Webhook — Per-Event Zod Schemas
 *
 * Discriminated schemas per event type instead of one monolithic schema.
 * Each schema validates only the fields relevant to that event.
 */

import { z } from "zod";

// ─── Shared Sub-Schemas ──────────────────────────────────────

const githubUserSchema = z.object({
    login:      z.string(),
    type:       z.string(),
    avatar_url: z.string(),
    name:       z.string().nullable().optional(),
}).passthrough();

const repositorySchema = z.object({
    id:        z.number(),
    full_name: z.string(),
    name:      z.string(),
    html_url:  z.string(),
    owner:     z.object({ login: z.string() }).passthrough().optional(),
}).passthrough();

const organizationSchema = z.object({
    login: z.string(),
}).passthrough();

// ─── Pull Request Event ──────────────────────────────────────

export const pullRequestPayloadSchema = z.object({
    action:       z.string(),
    organization: organizationSchema.optional(),
    repository:   repositorySchema,
    pull_request: z.object({
        id:         z.number(),
        number:     z.number(),
        title:      z.string(),
        html_url:   z.string(),
        merged:     z.boolean().optional(),
        user:       githubUserSchema.optional(),
        merged_at:  z.string().nullable().optional(),
        closed_at:  z.string().nullable().optional(),
        created_at: z.string().optional(),
        additions:  z.number().optional(),
        deletions:  z.number().optional(),
    }).passthrough(),
}).passthrough();

export type PullRequestPayload = z.infer<typeof pullRequestPayloadSchema>;

// ─── Issue Comment Event ─────────────────────────────────────

export const issueCommentPayloadSchema = z.object({
    action:       z.string(),
    organization: organizationSchema.optional(),
    repository:   repositorySchema,
    issue:        z.object({ number: z.number() }).passthrough(),
    comment: z.object({
        id:         z.number(),
        body:       z.string(),
        html_url:   z.string(),
        created_at: z.string(),
        user:       githubUserSchema.optional(),
    }).passthrough(),
    pull_request: z.object({
        id:     z.number().optional(),
        number: z.number().optional(),
    }).passthrough().optional(),
}).passthrough();

export type IssueCommentPayload = z.infer<typeof issueCommentPayloadSchema>;

// ─── Pull Request Review Comment Event ───────────────────────

export const reviewCommentPayloadSchema = z.object({
    action:       z.string(),
    organization: organizationSchema.optional(),
    repository:   repositorySchema,
    pull_request: z.object({
        id:     z.number(),
        number: z.number(),
    }).passthrough(),
    comment: z.object({
        id:         z.number(),
        body:       z.string(),
        html_url:   z.string(),
        created_at: z.string(),
        user:       githubUserSchema.optional(),
    }).passthrough(),
}).passthrough();

export type ReviewCommentPayload = z.infer<typeof reviewCommentPayloadSchema>;

// ─── Pull Request Review Event ───────────────────────────────

export const pullRequestReviewPayloadSchema = z.object({
    action:       z.string(),
    organization: organizationSchema.optional(),
    repository:   repositorySchema,
    pull_request: z.object({
        id:     z.number(),
        number: z.number(),
    }).passthrough(),
}).passthrough();

export type PullRequestReviewPayload = z.infer<typeof pullRequestReviewPayloadSchema>;

// ─── Organization / Member Events ────────────────────────────

export const orgMembershipPayloadSchema = z.object({
    action:       z.string(),
    organization: organizationSchema.optional(),
}).passthrough();

export type OrgMembershipPayload = z.infer<typeof orgMembershipPayloadSchema>;

// ─── Schema Selector ─────────────────────────────────────────

const schemaMap: Record<string, z.ZodType<any>> = {
    pull_request:               pullRequestPayloadSchema,
    pull_request_review:        pullRequestReviewPayloadSchema,
    issue_comment:              issueCommentPayloadSchema,
    pull_request_review_comment: reviewCommentPayloadSchema,
    organization:               orgMembershipPayloadSchema,
    member:                     orgMembershipPayloadSchema,
    membership:                 orgMembershipPayloadSchema,
};

/**
 * Safely parses a webhook payload using the schema for the given event.
 * Returns `{ success: true, data }` or `{ success: false, error }`.
 */
export function parseWebhookPayload(event: string, rawJson: unknown) {
    const schema = schemaMap[event];
    if (!schema) return { success: false as const, error: `No schema for event: ${event}` };
    return schema.safeParse(rawJson);
}
