/**
 * AI Chat Routes
 *
 * POST /api/ai-chat/message   — Send a message to Sellio Bot
 * DELETE /api/ai-chat/session/:sessionId — Clear chat history
 * GET  /api/ai-chat/repos     — List org repos (for repo picker)
 */

import { Hono } from "hono";
import type { HonoEnv } from "../../core/hono-env";
import { useCradle, safe } from "../../lib/route-helpers";
import { AppError } from "../../core/errors";

const aiChat = new Hono<HonoEnv>();

// POST /api/ai-chat/message
aiChat.post("/message", safe(async (c) => {
    const { aiChatService, env } = useCradle(c);
    const body = await c.req.json().catch(() => null);

    if (!body?.owner || !body?.repo || !body?.message) {
        throw new AppError("Missing required fields: owner, repo, message", 400, "VALIDATION_ERROR");
    }

    const result = await aiChatService.chat(
        body.owner,
        body.repo,
        body.message,
        body.sessionId,
    );

    return c.json(result);
}));

// DELETE /api/ai-chat/session/:sessionId
aiChat.delete("/session/:sessionId", safe(async (c) => {
    const { aiChatService } = useCradle(c);
    const { sessionId } = c.req.param();
    await aiChatService.deleteSession(sessionId);
    return c.json({ ok: true, deleted: sessionId });
}));

// GET /api/ai-chat/repos — proxy to reposService
aiChat.get("/repos", safe(async (c) => {
    const { reposService, env } = useCradle(c);
    const repos = await reposService.listByOrg(env.org);
    return c.json({ org: env.org, repos });
}));

export default aiChat;
