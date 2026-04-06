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

import dotenv from "dotenv";

// NOTE: dotenv.config() is called lazily inside _createEnv() so that
// Cloudflare Workers can populate process.env before config is read.

// ─── Private Key Reader ──────────────────────────────────────

/**
 * Normalizes a PEM private key from an environment variable.
 *
 * Handles common issues when PEM keys are stored as env vars:
 *   - Literal \n (backslash + n) instead of real newlines
 *   - Windows-style \r\n line endings
 *   - Missing final newline
 *
 * IMPORTANT for Cloudflare Workers:
 *   Workers' WebCrypto API requires PKCS#8 format ("-----BEGIN PRIVATE KEY-----").
 *   GitHub generates PKCS#1 keys ("-----BEGIN RSA PRIVATE KEY-----").
 *   Convert your key with:
 *     openssl pkcs8 -topk8 -inform PEM -outform PEM -in github-key.pem -out pkcs8-key.pem -nocrypt
 */
function normalizePemKey(raw: string): string {
    let key = raw
        .replace(/\\n/g, "\n")      // literal \n → real newline
        .replace(/\r\n/g, "\n")     // Windows CRLF → LF
        .trim();

    // If the key looks like it has no newlines at all (single line base64),
    // reconstruct the PEM format
    if (key.includes("-----") && !key.includes("\n")) {
        key = key
            .replace(/(-----BEGIN [^-]+-----)/, "$1\n")
            .replace(/(-----END [^-]+-----)/, "\n$1");

        // Split the base64 content into 64-char lines (PEM standard)
        const match = key.match(/-----BEGIN [^-]+-----\n?([\s\S]+?)\n?-----END [^-]+-----/);
        if (match) {
            const header = key.substring(0, key.indexOf("\n") + 1);
            const footer = key.substring(key.lastIndexOf("\n"));
            const base64 = match[1].replace(/\s/g, "");
            const lines = base64.match(/.{1,64}/g) || [];
            key = header + lines.join("\n") + footer;
        }
    }

    return key;
}

function validatePem(key: string): string {
    if (!key.includes("-----BEGIN") || !key.includes("-----END")) {
        throw new Error("❌ Loaded private key does not appear to be in PEM format");
    }
    return key;
}

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
function loadPrivateKey(envSrc: Record<string, string | undefined>): string {
    // Option 1: env var (Workers-friendly — check first)
    const envKey = envSrc["APP_PRIVATE_KEY"];
    if (envKey) {
        return validatePem(normalizePemKey(envKey));
    }

    // Option 2: explicit path from env
    const customPath = envSrc["PRIVATE_KEY_PATH"];
    if (customPath) {
        const path = require("node:path");
        const fs = require("node:fs");
        const resolved = path.resolve(customPath);
        if (fs.existsSync(resolved)) {
            return validatePem(fs.readFileSync(resolved, "utf-8"));
        }
        throw new Error(
            `❌ PRIVATE_KEY_PATH is set to "${customPath}" but file not found at: ${resolved}`,
        );
    }

    // Option 3: default location — backend/private-key.pem
    const path = require("node:path");
    const fs = require("node:fs");
    const defaultPath = path.resolve(process.cwd(), "private-key.pem");
    if (fs.existsSync(defaultPath)) {
        return validatePem(fs.readFileSync(defaultPath, "utf-8"));
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

function requireEnv(name: string, envSrc: Record<string, string | undefined>): string {
    const value = envSrc[name];
    if (!value) {
        throw new Error(`❌ Missing required env var: ${name}`);
    }
    return value;
}

function requireNumericEnv(name: string, envSrc: Record<string, string | undefined>): number {
    const raw = envSrc[name];
    if (!raw) {
        throw new Error(`❌ Missing required env var: ${name}`);
    }
    const parsed = parseInt(raw, 10);
    if (Number.isNaN(parsed)) {
        throw new Error(`❌ Env var ${name}="${raw}" is not a valid integer`);
    }
    return parsed;
}

function optionalEnv(name: string, fallback: string, envSrc: Record<string, string | undefined>): string {
    const val = envSrc[name];
    return val !== undefined && val !== "" ? val : fallback;
}

function numericEnv(name: string, fallback: number, envSrc: Record<string, string | undefined>): number {
    const raw = envSrc[name];
    if (raw === undefined || raw === "") return fallback;
    const parsed = parseInt(raw, 10);
    if (Number.isNaN(parsed)) {
        throw new Error(`❌ Env var ${name}="${raw}" is not a valid integer`);
    }
    return parsed;
}

// ─── Exported Config (lazy — safe for Cloudflare Workers) ───

/**
 * Builds the frozen config object from process.env (or overrides for testing).
 * Called lazily on first property access (not at import time)
 * so Cloudflare Workers can populate process.env from bindings first.
 */
function _createEnv(overrides?: Record<string, string | undefined>) {
    // dotenv loads .env file for local dev; silently skips if no file exists
    dotenv.config();

    const envSrc = overrides || process.env;

    const githubWebhookSecret = optionalEnv("GITHUB_WEBHOOK_SECRET", "", envSrc);
    if (!githubWebhookSecret) {
        console.warn("⚠️  GITHUB_WEBHOOK_SECRET is not set — webhook payloads will NOT be verified");
    }

    const config = {
        /** GitHub App — numeric App ID. */
        appId: requireEnv("APP_ID", envSrc),

        /**
         * GitHub App — RSA private key (PEM format, full content with newlines).
         *
         * On Workers: set APP_PRIVATE_KEY secret.
         * Locally: place private-key.pem in backend/ or set PRIVATE_KEY_PATH.
         * See loadPrivateKey() for full resolution order.
         */
        privateKey: loadPrivateKey(envSrc),

        /** GitHub App — Installation ID for the Sellio-Squad org. */
        installationId: requireNumericEnv("INSTALLATION_ID", envSrc),

        /** GitHub org slug to fetch repos from. */
        org: optionalEnv("GITHUB_ORG", "Sellio-Squad", envSrc),

        /** HTTP server port. */
        port: numericEnv("PORT", 3001, envSrc),

        /** Number of approvals required for a PR to be considered "approved". */
        requiredApprovals: numericEnv("REQUIRED_APPROVALS", 2, envSrc),

        /** Pino log level. */
        logLevel: optionalEnv("LOG_LEVEL", "info", envSrc),

        /** Rate limit: max requests per window. */
        rateLimitMax: numericEnv("RATE_LIMIT_MAX", 100, envSrc),

        /** Rate limit: window duration in milliseconds. */
        rateLimitWindowMs: numericEnv("RATE_LIMIT_WINDOW_MS", 60000, envSrc),

        /** GitHub rate limit threshold — delays requests when remaining quota is below this. */
        githubRateLimitThreshold: numericEnv("GITHUB_RATE_LIMIT_THRESHOLD", 100, envSrc),

        /** GitHub webhook secret for verifying webhook payloads (optional). */
        githubWebhookSecret,

        /**
         * Optional GitHub Personal Access Token (PAT).
         * When set, the tickets service uses this instead of the App installation token.
         * Required if the GitHub App lacks Projects v2 (read) permission.
         * Needs scopes: repo, read:org, read:project
         */
        githubToken: optionalEnv("GITHUB_TOKEN", "", envSrc),

        /** Google OAuth2 Client ID for Meet API */
        googleClientId: optionalEnv("GOOGLE_CLIENT_ID", "", envSrc),

        /** Google OAuth2 Client Secret */
        googleClientSecret: optionalEnv("GOOGLE_CLIENT_SECRET", "", envSrc),

        /** Google OAuth2 Redirect URI */
        googleRedirectUri: optionalEnv("GOOGLE_REDIRECT_URI", "http://localhost:3001/api/meetings/oauth2callback", envSrc),

        /** Google Pub/Sub topic for Workspace Events (e.g. "projects/my-proj/topics/meet-events-topic"). */
        googlePubsubTopic: optionalEnv("GOOGLE_PUBSUB_TOPIC", "", envSrc),

        /** Google Gemini API key for AI code review. */
        geminiApiKey: optionalEnv("GEMINI_API_KEY", "", envSrc),

    };

    return Object.freeze(config);
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
