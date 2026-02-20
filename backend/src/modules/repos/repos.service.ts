/**
 * Repos Module — Service
 *
 * Business logic for listing organization repositories.
 * Receives dependencies through the DI container (constructor injection).
 */

import type { GitHubClient } from "../../infra/github/github.client";
import type { Logger } from "../../core/logger";
import type { RepoInfo } from "../../core/types";
import { GitHubApiError } from "../../core/errors";

export class ReposService {
    private readonly githubClient: GitHubClient;
    private readonly logger: Logger;

    /** Simple in-memory cache to avoid hitting GitHub API on every request. */
    private cache: { repos: RepoInfo[]; expiresAt: number } | null = null;
    private static readonly CACHE_TTL_MS = 5 * 60 * 1000; // 5 minutes

    constructor({ githubClient, logger }: { githubClient: GitHubClient; logger: Logger }) {
        this.githubClient = githubClient;
        this.logger = logger.child({ module: "repos" });
    }

    /**
     * Returns all repositories for the given org.
     * Results are cached for 5 minutes.
     */
    async listByOrg(org: string): Promise<RepoInfo[]> {
        // Return from cache if still valid
        if (this.cache && Date.now() < this.cache.expiresAt) {
            this.logger.debug("Returning repos from cache");
            return this.cache.repos;
        }

        this.logger.info({ org }, "Fetching repos from GitHub");

        try {
            const rawRepos = await this.githubClient.paginate(
                this.githubClient.rest.repos.listForOrg,
                { org, type: "all", sort: "updated", per_page: 100 },
            );

            const repos: RepoInfo[] = rawRepos.map((r) => ({
                name: r.name,
                full_name: r.full_name,
                description: r.description,
                html_url: r.html_url,
                private: r.private,
                default_branch: r.default_branch ?? "main",
            }));

            // Update cache
            this.cache = {
                repos,
                expiresAt: Date.now() + ReposService.CACHE_TTL_MS,
            };

            this.logger.info({ count: repos.length }, "Repos fetched");
            return repos;
        } catch (error: any) {
            this.logger.error({ error: error.message }, "Failed to fetch repos");
            throw new GitHubApiError(`Failed to fetch repos: ${error.message}`);
        }
    }
}
