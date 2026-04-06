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

export function createConsoleLogger(
    bindings: Record<string, unknown> = {},
    onLog?: (level: string, msg: string, obj: unknown) => void
): Logger {
    const fmt = (msg: string, extra?: unknown) => {
        const parts = { ...bindings, ...(typeof extra === "object" && extra ? extra : {}) };
        return Object.keys(parts).length > 0 ? `[${JSON.stringify(parts)}] ${msg}` : msg;
    };

    const mk = (level: string, fn: (...args: any[]) => void) =>
        (objOrMsg: unknown, msg?: string, ...args: any[]) => {
            const formattedMsg = typeof objOrMsg === "string" ? objOrMsg : (msg || "");
            const obj = typeof objOrMsg === "string" ? undefined : objOrMsg;
            if (onLog && level !== "trace" && level !== "debug") {
                onLog(level, formattedMsg, typeof objOrMsg === "string" ? args : { ...bindings, ...(obj as any) });
            }
            typeof objOrMsg === "string" ? fn(objOrMsg, ...args) : fn(fmt(msg || "", objOrMsg as any));
        };

    // We cast to Logger (pino.Logger) — all methods that services actually call
    // are implemented; unused pino-specific props (symbol, stream, etc.) are not needed.
    return {
        info:    mk("info", console.log),
        warn:    mk("warn", console.warn),
        error:   mk("error", console.error),
        debug:   mk("debug", console.debug),
        trace:   () => { /* no-op */ },
        fatal:   mk("fatal", console.error),
        silent:  () => { /* no-op */ },
        // pino.Logger requires `child` returning Logger
        child:   (binds: Record<string, unknown>) => createConsoleLogger({ ...bindings, ...binds }, onLog),
        level:   "info",
        // pino internals — stubs so the type is satisfied
        msgPrefix:    "",
        isLevelEnabled: () => true,
        // pino uses these for serialization — noop in Worker
        bindings:  () => ({ ...bindings }),
        flush:     () => {},
    } as unknown as Logger;
}
