import { Hono } from "hono";
import { z } from "zod";
import { zValidator } from "@hono/zod-validator";
import type { HonoEnv } from "../../core/hono-env";
import { useCradle, safe } from "../../lib/route-helpers";

const reviewBodySchema = z.object({
    owner: z.string().min(1),
    repo: z.string().min(1),
    prNumber: z.number().int().positive(),
});

type ReviewBody = z.infer<typeof reviewBodySchema>;

const review = new Hono<HonoEnv>();

// ─── Single-request meta for dropdowns (repos + open PRs) ────
review.get("/meta", safe(async (c) => {
    const { reposService, openPrsService, env } = useCradle(c);
    const org = env.org;

    // Both are cached — this is effectively a cache read, not two network hits
    const [repos, openPrs] = await Promise.all([
        reposService.listByOrg(org),
        openPrsService.fetchOpenPrs(org),
    ]);

    // Return slim PR shape (only what the dropdown needs)
    const prs = openPrs.map((pr: any) => ({
        prNumber: pr.pr_number,
        title:    pr.title,
        url:      pr.url,
        author:   pr.creator?.login ?? "",
        additions: pr.diff_stats?.additions ?? 0,
        deletions: pr.diff_stats?.deletions ?? 0,
    }));

    return c.json({ repos, prs });
}));

// ─── Run AI review ───────────────────────────────────────────
review.post("/pr", zValidator("json", reviewBodySchema), safe(async (c) => {
    const { reviewService } = useCradle(c);
    const { owner, repo, prNumber } = c.req.valid("json") as ReviewBody;
    const result = await reviewService.reviewPr(owner, repo, prNumber);
    return c.json(result);
}));

// ─── Gemini usage stats ──────────────────────────────────────
review.get("/usage", safe(async (c) => {
    const { geminiClient } = useCradle(c);
    const stats = await geminiClient.getUsageStats();
    return c.json(stats);
}));

export default review;
