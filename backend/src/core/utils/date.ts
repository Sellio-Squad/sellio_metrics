/**
 * Sellio Metrics Backend — Date Utilities
 *
 * Pure functions for date calculations used in metrics.
 */

/**
 * Returns the ISO week string for a date, e.g. "2026-W04".
 * Uses the ISO 8601 week date algorithm.
 */
export function toISOWeek(dateStr: string): string {
    const d = new Date(dateStr);
    const target = new Date(d.valueOf());
    const dayNr = (d.getDay() + 6) % 7;
    target.setDate(target.getDate() - dayNr + 3);

    const firstThursday = target.valueOf();
    target.setMonth(0, 1);

    if (target.getDay() !== 4) {
        target.setMonth(0, 1 + ((4 - target.getDay() + 7) % 7));
    }

    const week =
        1 + Math.ceil((firstThursday - target.valueOf()) / (7 * 86_400_000));
    const isoYear = new Date(firstThursday).getFullYear();

    return `${isoYear}-W${week.toString().padStart(2, "0")}`;
}

/**
 * Calculates minutes between two ISO date strings.
 * Returns null if either date is missing.
 */
export function minutesBetween(
    start: string | null | undefined,
    end: string | null | undefined,
): number | null {
    if (!start || !end) return null;
    return (new Date(end).getTime() - new Date(start).getTime()) / 60_000;
}
