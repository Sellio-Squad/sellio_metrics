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

export default review;
