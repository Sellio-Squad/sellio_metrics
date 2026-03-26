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

review.post("/pr", zValidator("json", reviewBodySchema), safe(async (c) => {
    const { reviewService } = useCradle(c);
    const { owner, repo, prNumber } = c.req.valid("json") as ReviewBody;
    const result = await reviewService.reviewPr(owner, repo, prNumber);
    return c.json(result);
}));

review.get("/usage", safe(async (c) => {
    const { geminiClient } = useCradle(c);
    const stats = await geminiClient.getUsageStats();
    return c.json(stats);
}));

export default review;
