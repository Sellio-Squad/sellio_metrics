/**
 * Sellio Metrics — GitHub Sync Service
 *
 * Encapsulates the `syncOneRepo` logic that was previously inlined
 * in `worker.ts`. Handles fetching, enriching, and storing merged
 * PRs, comments, and member profiles from GitHub into D1.
 */

import type { Cradle } from "../../core/container";
import { isBot } from "../../lib/bot-filter";

export async function syncOneRepo(
    cradle: Cradle,
    owner: string,
    repoName: string,
    orgRepos: any[],
    targetPrNumbers?: number[],
): Promise<object> {
    const { cachedGithubClient, d1RelationalService, logger } = cradle;

    // Bust repo cache so fresh data is fetched
    await cradle.cacheService.del(`github:repos:${owner}`);

    let prs: any[]            = [];
    let issueComments: any[]  = [];
    let reviewComments: any[] = [];

    if (targetPrNumbers && targetPrNumbers.length > 0) {
        logger.info({ repo: repoName, count: targetPrNumbers.length }, "Performing targeted PR sync");
        prs = targetPrNumbers.map((num) => ({ number: num, merged_at: "mock", user: {} }));
    } else {
        [prs, issueComments, reviewComments] = await Promise.all([
            cachedGithubClient.listPulls(owner, repoName, "all", 100),
            cachedGithubClient.listAllIssueComments(owner, repoName),
            cachedGithubClient.listAllPRReviewComments(owner, repoName),
        ]);
    }

    // Filter to merged non-bot PRs
    const mergedPrs = prs.filter((pr: any) =>
        !!pr.merged_at && !isBot(pr.user?.login ?? "", pr.user?.type),
    );

    // Upsert repo with full metadata
    const repoMeta = orgRepos.find((r: any) => r.name === repoName);
    if (!repoMeta?.id) throw new Error(`Repo metadata id missing for ${owner}/${repoName}`);

    const repoId = await d1RelationalService.upsertRepo(repoMeta.id as number, owner, repoName, {
        htmlUrl:         repoMeta?.html_url ?? `https://github.com/${owner}/${repoName}`,
        description:     repoMeta?.description ?? undefined,
        githubCreatedAt: repoMeta?.created_at ?? undefined,
        pushedAt:        repoMeta?.pushed_at ?? undefined,
    });

    // Skip PRs already deeply fetched (i.e., have non-null additions)
    const existingMergedPrs = await d1RelationalService.getMergedPrs({ repoId: repoMeta.id as number, limit: 1000 });
    const existingMap = new Map(existingMergedPrs.map((p: any) => [p.prNumber, p]));

    const enrichedPrs: any[] = [];
    const fetchFailures: { prNumber: number; error: string }[] = [];

    const prsToDeepFetch = mergedPrs.filter((pr: any) => {
        const existing = existingMap.get(pr.number);
        return !existing || existing.additions === null;
    });

    // Carry over PRs that are already fully synced
    const prsNotDeepFetched = mergedPrs
        .filter((pr: any) => !prsToDeepFetch.includes(pr))
        .map((pr: any) => {
            const existing = existingMap.get(pr.number);
            if (existing) {
                pr.additions    = existing.additions;
                pr.deletions    = existing.deletions;
                pr.changed_files = 1;
            }
            return pr;
        });
    enrichedPrs.push(...prsNotDeepFetched);

    // Fetch PR details in parallel chunks (size 5) to respect GitHub rate limits
    const chunkSize = 5;
    for (let i = 0; i < prsToDeepFetch.length; i += chunkSize) {
        const chunk = prsToDeepFetch.slice(i, i + chunkSize);

        await Promise.all(chunk.map(async (pr: any) => {
            try {
                const detail = await cachedGithubClient.getPull(owner, repoName, pr.number, false);
                enrichedPrs.push(detail);
            } catch (e: any) {
                logger.warn(
                    { prNumber: pr.number, err: e.message },
                    "getPull failed — falling back to list-API entry (additions/deletions will be null)",
                );
                fetchFailures.push({ prNumber: pr.number, error: e.message });
                pr.additions = null;
                pr.deletions = null;
                enrichedPrs.push(pr);
            }
        }));

        if (i + chunkSize < mergedPrs.length) {
            await new Promise((r) => setTimeout(r, 600));
        }
    }

    // Fetch & upsert full member profiles (display_name + joined_at)
    const uniqueLogins = [
        ...new Set(enrichedPrs.map((pr: any) => pr.user?.login).filter(Boolean)),
    ] as string[];

    for (const login of uniqueLogins) {
        try {
            await cradle.cacheService.del(`github:user:${login}`);
            const profile = await cachedGithubClient.getUser(login);
            await d1RelationalService.upsertMember(
                login,
                profile.avatar_url ?? undefined,
                profile.name ?? undefined,
                profile.created_at ?? undefined,
            );
        } catch (e: any) {
            logger.warn({ login, err: e.message }, "getUser failed — storing login only");
            const pr = enrichedPrs.find((p: any) => p.user?.login === login);
            await d1RelationalService.upsertMember(login, pr?.user?.avatar_url);
        }
    }

    // Build PR rows
    const prRows = enrichedPrs.map((pr: any) => ({
        id:          pr.id as number,
        repoId,
        prNumber:    pr.number as number,
        author:      pr.user.login as string,
        title:       pr.title as string | undefined,
        body:        pr.body as string | undefined,
        htmlUrl:     pr.html_url as string | undefined,
        mergedAt:    pr.merged_at as string,
        prCreatedAt: pr.created_at as string | undefined,
        additions:   pr.additions,   // null means fetch failure
        deletions:   pr.deletions,
    }));

    const { upserted } = await d1RelationalService.upsertMergedPrBatch(prRows);

    // Index merged PR ids for comment filtering
    const mergedPrNumbers = new Set(enrichedPrs.map((p: any) => p.number as number));

    let commentsInserted = 0;

    // Issue comments
    for (const comment of issueComments) {
        const author: string = comment.user?.login;
        if (!author || isBot(author, comment.user?.type)) continue;
        const prNumber = parseInt(comment.issue_url?.split("/").pop() ?? "0", 10);
        if (!mergedPrNumbers.has(prNumber)) continue;
        const prGithubId = enrichedPrs.find((p: any) => p.number === prNumber)?.id as number | undefined;
        if (!prGithubId) continue;
        await d1RelationalService.upsertMember(author, comment.user?.avatar_url);
        const ok = await d1RelationalService.insertComment({
            id:          comment.id as number,
            prId:        prGithubId,
            repoId,
            prNumber,
            author,
            body:        comment.body,
            commentType: "issue",
            htmlUrl:     comment.html_url,
            commentedAt: comment.created_at,
        });
        if (ok) commentsInserted++;
    }

    // Review comments
    for (const comment of reviewComments) {
        const author: string = comment.user?.login;
        if (!author || isBot(author, comment.user?.type)) continue;
        const prNumber = parseInt(comment.pull_request_url?.split("/").pop() ?? "0", 10);
        if (!mergedPrNumbers.has(prNumber)) continue;
        const prGithubId = enrichedPrs.find((p: any) => p.number === prNumber)?.id as number | undefined;
        if (!prGithubId) continue;
        await d1RelationalService.upsertMember(author, comment.user?.avatar_url);
        const ok = await d1RelationalService.insertComment({
            id:          comment.id as number,
            prId:        prGithubId,
            repoId,
            prNumber,
            author,
            body:        comment.body,
            commentType: "review",
            htmlUrl:     comment.html_url,
            commentedAt: comment.created_at,
        });
        if (ok) commentsInserted++;
    }

    let totalAdded = 0;
    let totalDeleted = 0;
    for (const r of prRows) {
        if (r.additions) totalAdded += r.additions;
        if (r.deletions) totalDeleted += r.deletions;
    }

    return {
        ok:             true,
        repo:           `${owner}/${repoName}`,
        prsFound:       prs.length,
        mergedPrs:      mergedPrs.length,
        prsUpserted:    upserted,
        issueComments:  issueComments.length,
        reviewComments: reviewComments.length,
        commentsInserted,
        linesAdded:     totalAdded,
        linesDeleted:   totalDeleted,
        fetchFailures,
        debugPrs:       prRows.slice(0, 3),
    };
}
