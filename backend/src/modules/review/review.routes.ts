import { Hono } from "hono";
import { z } from "zod";
import { zValidator } from "@hono/zod-validator";
import type { HonoEnv } from "../../core/hono-env";
import { useCradle, safe } from "../../lib/route-helpers";

const reviewBodySchema = z.object({
    owner:    z.string().min(1),
    repo:     z.string().min(1),
    prNumber: z.number().int().positive(),
});

const review = new Hono<HonoEnv>();

// ─── Single-request meta for dropdowns (repos + open PRs) ────
review.get("/meta", safe(async (c) => {
    const { reposService, openPrsService, env } = useCradle(c);
    const org = env.org;

    // Both services are cached — effectively a cache read
    const [repos, openPrs] = await Promise.all([
        reposService.listByOrg(org),
        openPrsService.fetchOpenPrs(org),
    ]);

    // Shape repos with camelCase keys for the Flutter client
    const shapedRepos = repos.map((r: any) => ({
        name:     r.name,
        fullName: r.full_name ?? `${org}/${r.name}`,
    }));

    // Extract owner + repoName from the PR URL so the client
    // never needs to parse URLs itself.
    // URL format: https://github.com/{owner}/{repo}/pull/{number}
    const shapedPrs = openPrs.map((pr: any) => {
        const parts    = (pr.url as string).split("/");
        const prOwner  = parts[3] ?? org;
        const repoName = parts[4] ?? "";
        return {
            prNumber:  pr.pr_number,
            title:     pr.title,
            url:       pr.url,
            owner:     prOwner,
            repoName,
            author:    pr.creator?.login  ?? "",
            additions: pr.diff_stats?.additions ?? 0,
            deletions: pr.diff_stats?.deletions ?? 0,
        };
    });

    return c.json({ repos: shapedRepos, prs: shapedPrs });
}));

// ─── Run AI review ───────────────────────────────────────────
// zValidator infers the body type; use the schema type directly
review.post("/pr", zValidator("json", reviewBodySchema), safe(async (c) => {
    const { reviewService } = useCradle(c);
    const body = c.req.valid("json") as z.infer<typeof reviewBodySchema>;
    const result = await reviewService.reviewPr(body.owner, body.repo, body.prNumber);
    return c.json(result);
}));

// ─── Gemini usage stats ──────────────────────────────────────
review.get("/usage", safe(async (c) => {
    const { geminiClient } = useCradle(c);
    const stats = await geminiClient.getUsageStats();
    return c.json(stats);
}));

export default review;
