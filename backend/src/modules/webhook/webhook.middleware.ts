/**
 * GitHub Webhook Signature Verification Middleware
 *
 * Verifies the HMAC-SHA256 signature sent by GitHub in the
 * `x-hub-signature-256` header using the WebCrypto API
 * (compatible with Cloudflare Workers).
 *
 * If GITHUB_WEBHOOK_SECRET is not set, verification is skipped
 * (development mode).
 */

import type { Context, Next } from "hono";
import { useCradle } from "../../lib/route-helpers";

/**
 * Constant-time comparison of two ArrayBuffers to prevent timing attacks.
 */
function timingSafeEqual(a: ArrayBuffer, b: ArrayBuffer): boolean {
    const va = new Uint8Array(a);
    const vb = new Uint8Array(b);
    if (va.length !== vb.length) return false;
    let result = 0;
    for (let i = 0; i < va.length; i++) {
        result |= va[i]! ^ vb[i]!;
    }
    return result === 0;
}

/**
 * Computes HMAC-SHA256 of the given payload using the WebCrypto API.
 */
async function computeHmac(secret: string, payload: string): Promise<ArrayBuffer> {
    const encoder = new TextEncoder();
    const key = await crypto.subtle.importKey(
        "raw",
        encoder.encode(secret),
        { name: "HMAC", hash: "SHA-256" },
        false,
        ["sign"],
    );
    return crypto.subtle.sign("HMAC", key, encoder.encode(payload));
}

/**
 * Converts a hex string to an ArrayBuffer.
 */
function hexToBuffer(hex: string): ArrayBuffer {
    const bytes = new Uint8Array(hex.length / 2);
    for (let i = 0; i < hex.length; i += 2) {
        bytes[i / 2] = parseInt(hex.substring(i, i + 2), 16);
    }
    return bytes.buffer;
}

/**
 * Hono middleware that verifies the GitHub webhook HMAC-SHA256 signature.
 *
 * Must be placed BEFORE JSON body parsing — it reads the raw body text.
 * Stores the raw body on the context for downstream handlers.
 */
export async function verifyGitHubSignature(c: Context, next: Next): Promise<Response | void> {
    const cradle = useCradle(c);
    const secret = cradle.env.githubWebhookSecret;

    // Skip verification in dev mode (no secret configured)
    if (!secret) {
        return next();
    }

    const signatureHeader = c.req.header("x-hub-signature-256");
    if (!signatureHeader) {
        return c.json({ error: "Missing x-hub-signature-256 header" }, 401);
    }

    // Expected format: "sha256=<hex>"
    const [algorithm, signature] = signatureHeader.split("=");
    if (algorithm !== "sha256" || !signature) {
        return c.json({ error: "Invalid signature format" }, 401);
    }

    const rawBody = await c.req.text();

    const expected = await computeHmac(secret, rawBody);
    const received = hexToBuffer(signature);

    if (!timingSafeEqual(expected, received)) {
        cradle.logger.warn("Webhook signature verification failed");
        return c.json({ error: "Invalid webhook signature" }, 401);
    }

    // Store raw body for downstream JSON parsing
    c.set("rawBody", rawBody);
    return next();
}
