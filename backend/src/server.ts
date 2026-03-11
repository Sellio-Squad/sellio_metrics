/**
 * Sellio Metrics Backend — Server Entry Point (LEGACY)
 *
 * This file was the old Fastify entry point.
 * The app now runs as a Cloudflare Worker (worker.ts is the entry point).
 *
 * Kept as reference. The DI container is now built inside worker.ts
 * where the Cloudflare env bindings (KV, D1) are available.
 */

// Entry point is now worker.ts — see wrangler.toml
export {};

