/**
 * Sellio Metrics Backend — GitHub Client
 *
 * Infrastructure adapter for the GitHub API.
 * Uses @octokit/auth-app for automatic token refresh.
 *
 * This is the ONLY module that knows about Octokit.
 * The rest of the app interacts through GitHubClient.
 */

import { Octokit } from "@octokit/rest";
import { createAppAuth } from "@octokit/auth-app";
import type { Env } from "../../config/env";

// ─── Types ──────────────────────────────────────────────────

export type GitHubClient = Octokit;

// ─── Factory ────────────────────────────────────────────────

/**
 * Creates an authenticated Octokit instance.
 *
 * The `@octokit/auth-app` strategy automatically:
 * 1. Creates a JWT from App ID + private key
 * 2. Exchanges it for an installation access token
 * 3. Caches the token and auto-refreshes before expiry (~1 hour)
 */
export function createGitHubClient({ env }: { env: Env }): GitHubClient {
    return new Octokit({
        authStrategy: createAppAuth,
        auth: {
            appId: env.appId,
            privateKey: env.privateKey,
            installationId: env.installationId,
        },
    });
}
