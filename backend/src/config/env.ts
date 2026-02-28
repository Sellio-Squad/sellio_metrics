/**
 * Sellio Metrics Backend — Environment Configuration
 *
 * Single source of truth for all environment variables.
 * Validates at startup — fail fast if config is invalid.
 *
 * Private Key Strategy:
 *   Place your GitHub App private key at backend/private-key.pem
 *   The server reads it directly from disk — no escaping needed.
 */

import fs from "fs";
import path from "path";
import dotenv from "dotenv";

dotenv.config();

// ─── Private Key Reader ──────────────────────────────────────

/**
 * Reads the GitHub App RSA private key from a .pem file.
 *
 * Resolution order (first found wins):
 *   1. PRIVATE_KEY_PATH env var  → custom path
 *   2. backend/private-key.pem   → default location (relative to CWD)
 *   3. APP_PRIVATE_KEY env var   → fallback (legacy, supports literal \n)
 *
 * This approach is the most reliable — no escaping, no newline mangling.
 */
function loadPrivateKey(): string {
    // Option 1: explicit path from env
    const customPath = process.env["PRIVATE_KEY_PATH"];
    if (customPath) {
        const resolved = path.resolve(customPath);
        if (fs.existsSync(resolved)) {
            return fs.readFileSync(resolved, "utf-8");
        }
        throw new Error(
            `❌ PRIVATE_KEY_PATH is set to "${customPath}" but file not found at: ${resolved}`,
        );
    }

    // Option 2: default location — backend/private-key.pem
    const defaultPath = path.resolve(process.cwd(), "private-key.pem");
    if (fs.existsSync(defaultPath)) {
        return fs.readFileSync(defaultPath, "utf-8");
    }

    // Option 3: fallback to env var (legacy — supports literal \n escaping)
    const envKey = process.env["APP_PRIVATE_KEY"];
    if (envKey) {
        return envKey.replace(/\\n/g, "\n");
    }

    throw new Error(
        `❌ GitHub App private key not found.\n\n` +
        `  Please provide the key using ONE of these methods:\n\n` +
        `  1. (Recommended) Place the .pem file at:\n` +
        `       ${defaultPath}\n\n` +
        `  2. Set PRIVATE_KEY_PATH=/absolute/path/to/your-key.pem\n\n` +
        `  3. Set APP_PRIVATE_KEY="-----BEGIN RSA...\n...\n-----END RSA..."`,
    );
}

// ─── Validation ─────────────────────────────────────────────

interface EnvSchema {
    APP_ID: string;
    PRIVATE_KEY_PATH?: string;
    APP_PRIVATE_KEY?: string;
    INSTALLATION_ID: string;
    GITHUB_ORG?: string;
    PORT?: string;
    REQUIRED_APPROVALS?: string;
    LOG_LEVEL?: string;
    RATE_LIMIT_MAX?: string;
    RATE_LIMIT_WINDOW_MS?: string;
    REDIS_URL?: string;
    GITHUB_RATE_LIMIT_THRESHOLD?: string;
    GITHUB_WEBHOOK_SECRET?: string;
}

function requireEnv(name: keyof EnvSchema): string {
    const value = process.env[name];
    if (!value) {
        throw new Error(`❌ Missing required env var: ${name}`);
    }
    return value;
}

function optionalEnv(name: keyof EnvSchema, fallback: string): string {
    return process.env[name] || fallback;
}

// ─── Exported Config ────────────────────────────────────────

export const env = Object.freeze({
    /** GitHub App — numeric App ID. */
    appId: requireEnv("APP_ID"),

    /**
     * GitHub App — RSA private key (PEM format, full content with newlines).
     *
     * Loaded from private-key.pem by default.
     * See loadPrivateKey() for full resolution order.
     */
    privateKey: loadPrivateKey(),

    /** GitHub App — Installation ID for the Sellio-Squad org. */
    installationId: parseInt(requireEnv("INSTALLATION_ID"), 10),

    /** GitHub org slug to fetch repos from. */
    org: optionalEnv("GITHUB_ORG", "Sellio-Squad"),

    /** HTTP server port. */
    port: parseInt(optionalEnv("PORT", "3001"), 10),

    /** Number of approvals required for a PR to be considered "approved". */
    requiredApprovals: parseInt(optionalEnv("REQUIRED_APPROVALS", "2"), 10),

    /** Pino log level. */
    logLevel: optionalEnv("LOG_LEVEL", "info"),

    /** Rate limit: max requests per window. */
    rateLimitMax: parseInt(optionalEnv("RATE_LIMIT_MAX", "100"), 10),

    /** Rate limit: window duration in milliseconds. */
    rateLimitWindowMs: parseInt(
        optionalEnv("RATE_LIMIT_WINDOW_MS", "60000"),
        10,
    ),

    /** Redis connection URL for caching (optional — gracefully degrades). */
    redisUrl: optionalEnv("REDIS_URL", ""),

    /** GitHub rate limit threshold — delays requests when remaining quota is below this. */
    githubRateLimitThreshold: parseInt(
        optionalEnv("GITHUB_RATE_LIMIT_THRESHOLD", "100"),
        10,
    ),

    /** GitHub webhook secret for verifying webhook payloads (optional). */
    githubWebhookSecret: optionalEnv("GITHUB_WEBHOOK_SECRET", ""),
});

export type Env = typeof env;
