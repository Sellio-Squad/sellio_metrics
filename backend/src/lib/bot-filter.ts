/**
 * Sellio Metrics — Bot Filter Utility
 *
 * Shared bot detection logic used by sync, webhook, scores, and members routes.
 */

/** Known bot login names that don't end with [bot] but should be excluded. */
export const KNOWN_BOTS = new Set([
    "Copilot", "github-copilot", "dependabot", "dependabot-preview",
    "renovate", "renovate-bot", "snyk-bot", "greenkeeper",
    "netlify", "vercel", "codecov", "coveralls",
    // Project-specific bots
    "Sellio-Bot", "sellio-bot",
]);

export function isBot(login: string, userType?: string): boolean {
    return (
        userType === "Bot" ||
        login.endsWith("[bot]") ||
        KNOWN_BOTS.has(login)
    );
}
