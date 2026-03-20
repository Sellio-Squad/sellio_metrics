/**
 * Sellio Metrics — Console Logger
 *
 * A lightweight pino-compatible logger built on console.* methods.
 * Used in the Cloudflare Worker runtime where pino is not available.
 *
 * The returned object satisfies the `Logger` type (pino.Logger interface)
 * that all services and infra modules depend on.
 */

// We deliberately import the type from pino (dev dependency, type-only)
// so that our console logger satisfies the same interface as a real pino instance.
import type { Logger } from "pino";

export type { Logger };

export function createConsoleLogger(bindings: Record<string, unknown> = {}): Logger {
    const fmt = (msg: string, extra?: unknown) => {
        const parts = { ...bindings, ...(typeof extra === "object" && extra ? extra : {}) };
        return Object.keys(parts).length > 0 ? `[${JSON.stringify(parts)}] ${msg}` : msg;
    };

    const mk = (fn: (...args: any[]) => void) =>
        (objOrMsg: unknown, msg?: string, ...args: any[]) =>
            typeof objOrMsg === "string" ? fn(objOrMsg, ...args) : fn(fmt(msg || "", objOrMsg as any));

    // We cast to Logger (pino.Logger) — all methods that services actually call
    // are implemented; unused pino-specific props (symbol, stream, etc.) are not needed.
    return {
        info:    mk(console.log),
        warn:    mk(console.warn),
        error:   mk(console.error),
        debug:   mk(console.debug),
        trace:   () => { /* no-op */ },
        fatal:   (o: unknown, m?: string) => console.error(fmt(`[FATAL] ${m || ""}`, o)),
        silent:  () => { /* no-op */ },
        // pino.Logger requires `child` returning Logger
        child:   (binds: Record<string, unknown>) => createConsoleLogger({ ...bindings, ...binds }),
        level:   "info",
        // pino internals — stubs so the type is satisfied
        msgPrefix:    "",
        isLevelEnabled: () => true,
        // pino uses these for serialization — noop in Worker
        bindings:  () => ({}),
        flush:     () => {},
    } as unknown as Logger;
}
