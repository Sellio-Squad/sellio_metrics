/**
 * Open Tickets Routes
 * GET /api/tickets
 *
 * Returns all open tickets: GitHub Issues + Project v2 items (merged & deduplicated).
 */

import { Hono } from "hono";
import type { HonoEnv } from "../../core/hono-env";
import { useCradle, safe } from "../../lib/route-helpers";

const tickets = new Hono<HonoEnv>();

tickets.get("/", safe(async (c) => {
    const { openTicketsService, env } = useCradle(c);
    const data = await openTicketsService.fetchOpenTickets(env.org);
    return c.json({ data });
}));

export default tickets;
