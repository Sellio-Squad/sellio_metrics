/**
 * Sellio Metrics — Bot Filter Utility
 *
 * Shared bot detection logic used by sync, webhook, scores, and members routes.
 */

export function isBot(login: string, userType?: string): boolean {
    return (
        userType === "Bot" ||
        login.endsWith("[bot]")
    );
}
