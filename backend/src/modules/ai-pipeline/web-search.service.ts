import puppeteer from "@cloudflare/puppeteer";
import type { Logger } from "../../core/logger";

interface WebSearchResult {
    title: string;
    snippet: string;
    link: string;
}

export class WebSearchService {
    private logger: Logger;
    private browserBinding: any | null;

    constructor({ logger, browser }: { logger: Logger; browser: any | null }) {
        this.logger = logger;
        this.browserBinding = browser;
    }

    /**
     * Fetch the latest version of a package directly from its registry API.
     * Extremely fast and does not require launching a browser instance.
     */
    async getPackageLatestVersion(registry: "pub" | "npm", packageName: string): Promise<string | null> {
        this.logger.info({ registry, packageName }, "Fetching package latest version from registry");
        try {
            if (registry === "pub") {
                const response = await fetch(`https://pub.dev/api/packages/${encodeURIComponent(packageName)}`);
                if (!response.ok) {
                    if (response.status === 404) return null;
                    throw new Error(`pub.dev API returned status ${response.status}`);
                }
                const data: any = await response.json();
                const latestVersion = data?.latest?.version;
                this.logger.info({ packageName, latestVersion }, "Resolved Dart package version");
                return latestVersion || null;
            } else {
                const response = await fetch(`https://registry.npmjs.org/${encodeURIComponent(packageName)}/latest`);
                if (!response.ok) {
                    if (response.status === 404) return null;
                    throw new Error(`npm registry API returned status ${response.status}`);
                }
                const data: any = await response.json();
                const latestVersion = data?.version;
                this.logger.info({ packageName, latestVersion }, "Resolved npm package version");
                return latestVersion || null;
            }
        } catch (err: any) {
            this.logger.error({ packageName, error: err.message }, "Failed to fetch package version from registry");
            return null;
        }
    }

    /**
     * Search the web for documentation or answers using Cloudflare Browser Rendering.
     * Uses DuckDuckGo HTML (lite/no-js version) for fast and reliable scraping.
     */
    async searchDocs(query: string): Promise<string> {
        this.logger.info({ query }, "Initiating headless browser web search");
        if (!this.browserBinding) {
            this.logger.warn("Browser Rendering binding 'BROWSER' is not configured. Web search skipped.");
            return "Web search is unavailable because the BROWSER binding is not configured in wrangler.toml.";
        }

        let browser;
        try {
            browser = await puppeteer.launch(this.browserBinding);
            const page = await browser.newPage();
            
            // DuckDuckGo html search endpoint
            const url = `https://html.duckduckgo.com/html/?q=${encodeURIComponent(query)}`;
            await page.goto(url, { waitUntil: "domcontentloaded", timeout: 15000 });

            // Extract results
            const results = await page.evaluate(() => {
                const items: WebSearchResult[] = [];
                const links = document.querySelectorAll(".result__snippet");
                links.forEach((snippetEl) => {
                    const parent = snippetEl.closest(".web-result");
                    if (!parent) return;
                    const titleEl = parent.querySelector(".result__a") as HTMLAnchorElement;
                    if (!titleEl) return;
                    items.push({
                        title: titleEl.innerText || "",
                        snippet: (snippetEl as HTMLElement).innerText || "",
                        link: titleEl.href || "",
                    });
                });
                return items.slice(0, 5);
            });

            if (results.length === 0) {
                this.logger.warn({ query }, "No search results returned from DuckDuckGo");
                return `No web search results found for: "${query}"`;
            }

            let summary = `Search results for "${query}":\n\n`;
            for (const r of results) {
                summary += `### [${r.title}](${r.link})\n${r.snippet}\n\n`;
            }

            this.logger.info({ query, resultsCount: results.length }, "Web search completed successfully");
            return summary;
        } catch (err: any) {
            this.logger.error({ query, error: err.message }, "Error during web search headless session");
            return `Web search failed for query "${query}": ${err.message}`;
        } finally {
            if (browser) {
                try {
                    await browser.close();
                } catch (e: any) {
                    this.logger.error({ error: e.message }, "Failed to close browser session");
                }
            }
        }
    }
}
