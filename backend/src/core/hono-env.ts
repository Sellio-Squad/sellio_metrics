/**
 * Sellio Metrics — Hono Environment Types
 *
 * Defines the typed context variables available in all Hono route handlers
 * via `c.get("cradle")`. Import this in every route file instead of
 * importing from `../../worker` to avoid circular dependencies.
 */

import type { Cradle } from "./container";

export interface HonoEnv {
    Variables: {
        cradle: Cradle;
        rawBody?: string;
    };
}
