/**
 * Repos Module — Service
 *
 * Business logic for listing organization repositories.
 * Now uses CachedGitHubClient for Redis-backed caching
 * instead of manual in-memory cache.
 */

import type { CachedGitHubClient } from "../../infra/github/cached-github.client";
import type { Logger } from "../../core/logger";
import type { RepoInfo } from "../../core/types";
import { GitHubApiError } from "../../core/errors";

export class ReposService {
    private readonly cachedGithubClient: CachedGitHubClient;
    private readonly logger: Logger;

    constructor({
        cachedGithubClient,
        logger,
    }: {
        cachedGithubClient: CachedGitHubClient;
        logger: Logger;
    }) {
        this.cachedGithubClient = cachedGithubClient;
        this.logger = logger.child({ module: "repos" });
    }

    /**
     * Returns all repositories for the given org.
     * Results are cached in Redis (24-hour TTL).
     */
    async listByOrg(org: string): Promise<RepoInfo[]> {
        this.logger.info({ org }, "Fetching repos");

        try {
            const rawRepos = await this.cachedGithubClient.listOrgRepos(org);

            const repos: RepoInfo[] = rawRepos.map((r: any) => ({
                name: r.name,
                full_name: r.full_name,
                description: r.description,
                html_url: r.html_url,
                private: r.private,
                default_branch: r.default_branch ?? "main",
            }));

            this.logger.info({ count: repos.length }, "Repos fetched");
            return repos;
        } catch (error: any) {
            this.logger.error({ error: error.message }, "Failed to fetch repos");
            throw new GitHubApiError(`Failed to fetch repos: ${error.message}`);
        }
    }
}
