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

// NOTE: dotenv.config() is called lazily inside _createEnv() so that
// Cloudflare Workers can populate process.env before config is read.

// ─── Private Key Reader ──────────────────────────────────────

/**
 * Reads the GitHub App RSA private key.
 *
 * Resolution order (first found wins):
 *   1. APP_PRIVATE_KEY env var   → Workers-friendly (no filesystem)
 *   2. PRIVATE_KEY_PATH env var  → custom file path
 *   3. backend/private-key.pem   → default location (relative to CWD)
 *
 * This order ensures Cloudflare Workers (which can't read the filesystem)
 * work when APP_PRIVATE_KEY is set as a secret, while local dev can still
 * use a .pem file on disk.
 */
function loadPrivateKey(): string {
    // Option 1: env var (Workers-friendly — check first)
    const envKey = process.env["APP_PRIVATE_KEY"];
    if (envKey) {
        return envKey.replace(/\\n/g, "\n");
    }

    // Option 2: explicit path from env
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

    // Option 3: default location — backend/private-key.pem
    const defaultPath = path.resolve(process.cwd(), "private-key.pem");
    if (fs.existsSync(defaultPath)) {
        return fs.readFileSync(defaultPath, "utf-8");
    }

    throw new Error(
        `❌ GitHub App private key not found.\n\n` +
        `  Please provide the key using ONE of these methods:\n\n` +
        `  1. Set APP_PRIVATE_KEY env var (required for Cloudflare Workers)\n\n` +
        `  2. Place the .pem file at:\n` +
        `       ${defaultPath}\n\n` +
        `  3. Set PRIVATE_KEY_PATH=/absolute/path/to/your-key.pem`,
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

// ─── Exported Config (lazy — safe for Cloudflare Workers) ───

/**
 * Builds the frozen config object from process.env.
 * Called lazily on first property access (not at import time)
 * so Cloudflare Workers can populate process.env from bindings first.
 */
function _createEnv() {
    // dotenv loads .env file for local dev; silently skips if no file exists
    dotenv.config();

    return Object.freeze({
        /** GitHub App — numeric App ID. */
        appId: requireEnv("APP_ID"),

        /**
         * GitHub App — RSA private key (PEM format, full content with newlines).
         *
         * On Workers: set APP_PRIVATE_KEY secret.
         * Locally: place private-key.pem in backend/ or set PRIVATE_KEY_PATH.
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
}

type EnvConfig = ReturnType<typeof _createEnv>;

let _envInstance: EnvConfig | undefined;

/**
 * Lazy config proxy — defers process.env reading until first property access.
 * This lets Cloudflare Workers set process.env from bindings before config initializes.
 * Local dev (server.ts) is unaffected — config initializes on first use.
 */
export const env: EnvConfig = new Proxy({} as EnvConfig, {
    get(_, prop: string | symbol) {
        if (!_envInstance) _envInstance = _createEnv();
        return Reflect.get(_envInstance, prop);
    },
    ownKeys() {
        if (!_envInstance) _envInstance = _createEnv();
        return Reflect.ownKeys(_envInstance);
    },
    getOwnPropertyDescriptor(_, prop) {
        if (!_envInstance) _envInstance = _createEnv();
        return Object.getOwnPropertyDescriptor(_envInstance, prop);
    },
    has(_, prop) {
        if (!_envInstance) _envInstance = _createEnv();
        return prop in _envInstance;
    },
});

export type Env = EnvConfig;

