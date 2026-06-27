/**
 * Sellio Metrics — OrgMemberGuard
 *
 * Security layer: verifies that a GitHub login is an active member
 * of the configured org before allowing bot access.
 *
 * Results are cached in KV for 10 minutes to avoid hammering GitHub API
 * on every message.
 */

import type { CacheService } from "../../infra/cache/cache.service";
import type { Logger } from "../../core/logger";

const MEMBER_CACHE_TTL = 600; // 10 minutes

export class OrgMemberGuard {
    private readonly cache: CacheService;
    private readonly octokit: any;
    private readonly logger: Logger;

    constructor({
        cacheService,
        cachedGithubClient,
        logger,
    }: {
        cacheService: CacheService;
        cachedGithubClient: any;
        logger: Logger;
    }) {
        this.cache = cacheService;
        this.octokit = cachedGithubClient.raw;
        this.logger = logger.child({ module: "org-member-guard" });
    }

    /**
     * Returns true if the given GitHub login is a public or private member
     * of the org. Cached for 10 minutes per login.
     */
    async isMember(org: string, login: string): Promise<boolean> {
        const cacheKey = `ai:chat:member:${org}:${login.toLowerCase()}`;
        const cached = await this.cache.get<boolean>(cacheKey);
        if (cached !== null) return cached.data;

        try {
            // Use the org membership check endpoint — returns 204 if member, 404 if not
            await this.octokit.orgs.checkMembershipForUser({ org, username: login });
            await this.cache.set(cacheKey, true, MEMBER_CACHE_TTL);
            this.logger.info({ org, login }, "Org membership verified");
            return true;
        } catch (err: any) {
            if (err.status === 404 || err.status === 302) {
                await this.cache.set(cacheKey, false, MEMBER_CACHE_TTL);
                this.logger.info({ org, login }, "Login is not an org member");
                return false;
            }
            // On network error, fail open (don't block the user) but log
            this.logger.warn({ org, login, err: err.message }, "Could not verify org membership — failing open");
            return true;
        }
    }
}
