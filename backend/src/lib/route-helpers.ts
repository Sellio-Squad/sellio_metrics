/**
 * Route Helpers — Shared utilities for Hono route handlers
 *
 * useCradle(c)  — shorthand for c.get("cradle"), avoid repeating the string key
 * safe(fn)      — wraps a handler in try/catch, returns 500 on unhandled errors
 * oauthHtml()   — generates OAuth callback HTML pages (success / error)
 */

import type { Context } from "hono";
import type { HonoEnv } from "../core/hono-env";
import type { Cradle } from "../core/container";
import { AppError } from "../core/app-error";

// ─── Cradle accessor ──────────────────────────────────────────

/** One-liner access to the DI cradle from any Hono context. */
export const useCradle = (c: Context<any, any, any>): Cradle => c.get("cradle");

// ─── Async error wrapper ──────────────────────────────────────

type Handler = (c: Context<HonoEnv>) => Promise<Response | void>;

/**
 * Wraps a Hono route handler with uniform error handling.
 * On unhandled errors, returns { error: message } with status 500.
 *
 * @example
 *   app.get("/", safe(async (c) => {
 *     const data = await riskyFn();
 *     return c.json(data);
 *   }));
 */
export const safe = <C extends Context<any, any, any>>(
    fn: (c: C) => Promise<Response | void> | Response | void
) => async (c: C): Promise<Response> => {
        try {
            const result = await fn(c);
            return (result as Response) ?? c.json({ ok: true });
        } catch (e: any) {
            if (e instanceof AppError) {
                return c.json({
                    error: e.message,
                    ...(e.details && { details: e.details })
                }, e.statusCode as any);
            }
            const cradle = c.get("cradle") as Cradle | undefined;
            cradle?.logger?.warn?.({ err: e?.message }, "Unhandled route error");
            return c.json({ error: e?.message || "Internal Server Error" }, 500);
        }
    };

// ─── OAuth HTML responses ─────────────────────────────────────

const OAUTH_CORS = {
    "Content-Type":                  "text/html",
    "Access-Control-Allow-Origin":   "*",
    "Access-Control-Allow-Methods":  "GET, POST, PUT, DELETE, OPTIONS",
    "Access-Control-Allow-Headers":  "Content-Type, Authorization",
} as const;

export function oauthSuccessHtml(): Response {
    return new Response(
        `<html><body style="font-family:sans-serif;padding:24px">
        <h2 style="color:green">✅ Signed in successfully!</h2>
        <p>This window will close in 3 seconds…</p>
        <script>setTimeout(() => window.close(), 3000);</script>
        </body></html>`,
        { headers: OAUTH_CORS },
    );
}

export function oauthErrorHtml(error: string, hint?: string): Response {
    return new Response(
        `<html><body style="font-family:sans-serif;padding:24px">
        <h2 style="color:red">❌ Authentication Failed</h2>
        <p><b>Error:</b> ${error}</p>
        ${hint ? `<p>${hint}</p>` : ""}
        </body></html>`,
        { status: 400, headers: OAUTH_CORS },
    );
}

export function oauthFailHtml(error: string): Response {
    return new Response(
        `<html><body style="font-family:sans-serif;padding:24px">
        <h2 style="color:red">❌ Token Exchange Failed</h2>
        <p><b>Error:</b> ${error}</p>
        <p>Possible causes: invalid OAuth credentials, redirect URI mismatch, or KV write quota exceeded.</p>
        </body></html>`,
        { status: 500, headers: OAUTH_CORS },
    );
}
