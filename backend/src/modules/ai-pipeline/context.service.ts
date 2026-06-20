/**
 * Sellio Metrics — AI Context Service
 *
 * Gathers repository context in 4 layers:
 *   - Layer 1: Repository file tree (cached in KV, TTL 30 days, buster on merge)
 *   - Layer 2: Configuration / architecture files (cached in KV)
 *   - Layer 3: Ticket-specific file selection (via LLM Selector + fallback)
 *   - Layer 4: File contents reading (surgical reads via GitHub Contents API, max 30 files)
 */

import type { CachedGitHubClient } from "../../infra/github/cached-github.client";
import type { CacheService } from "../../infra/cache/cache.service";
import type { Logger } from "../../core/logger";
import type { AiProviderClient } from "../../infra/ai/ai-provider.client";
import type { RepoContext } from "./ai-pipeline.types";

const SKIP_PATTERNS = [
    /node_modules\//i,
    /\.git\//i,
    /dist\//i,
    /build\//i,
    /\.dart_tool\//i,
    /\.flutter-plugins/i,
    /\.lock$/i,
    /\.(png|jpg|jpeg|gif|svg|ico|webp|mp4|mp3|otf|ttf|woff2?|zip|tar\.gz|pdf|exe|dll)$/i,
];

export class ContextService {
    private readonly github: CachedGitHubClient;
    private readonly cache: CacheService;
    private readonly ai: AiProviderClient;
    private readonly logger: Logger;
    private readonly maxAiFiles: number;

    constructor({
        cachedGithubClient,
        cacheService,
        aiProviderClient,
        logger,
        env,
    }: {
        cachedGithubClient: CachedGitHubClient;
        cacheService: CacheService;
        aiProviderClient: AiProviderClient;
        logger: Logger;
        env: { maxAiFiles: number };
    }) {
        this.github = cachedGithubClient;
        this.cache = cacheService;
        this.ai = aiProviderClient;
        this.logger = logger.child({ module: "ai-context" });
        this.maxAiFiles = env.maxAiFiles || 30;
    }

    /**
     * Gathers all 4 layers of context for a given issue.
     */
    async gatherContext(
        owner: string,
        repo: string,
        issueNumber: number,
        issueTitle: string,
        issueBody: string | null
    ): Promise<RepoContext> {
        this.logger.info({ owner, repo, issueNumber }, "Gathering repository context");

        // 1. Get/Cache Repo Tree (Layer 1)
        const fileTree = await this.getRepoTree(owner, repo);

        // 2. Get/Cache Architecture / Configuration files (Layer 1-2)
        const architectureDocs = await this.getArchitectureDocs(owner, repo, fileTree);

        // 3. Extract dependencies
        const dependencies = this.extractDependencies(architectureDocs);

        // 4. Get recent merged PRs for style reference
        const recentPrs = await this.getRecentMergedPRs(owner, repo);

        // 5. Select relevant files for the ticket (Layer 3)
        const filesToRead = await this.selectRelevantFiles(
            fileTree,
            issueTitle,
            issueBody,
            architectureDocs
        );

        // 6. Read file contents (Layer 4)
        const relevantFiles = await this.readFileContents(owner, repo, filesToRead);

        return {
            owner,
            repo,
            fileTree,
            architectureDocs,
            dependencies,
            recentPrs,
            relevantFiles,
        };
    }

    /**
     * Fetches and caches the filtered file tree.
     */
    async getRepoTree(owner: string, repo: string): Promise<string[]> {
        const cacheKey = `ai:repo:${owner}/${repo}:tree`;
        const cached = await this.cache.get<string[]>(cacheKey);
        if (cached) {
            this.logger.info({ owner, repo }, "Using cached repo tree");
            return cached.data;
        }

        this.logger.info({ owner, repo }, "Fetching fresh repo tree");
        const octokit = this.github.raw;
        
        // 1. Get default branch
        const { data: repoInfo } = await octokit.repos.get({ owner, repo });
        const defaultBranch = repoInfo.default_branch;

        // 2. Get recursive tree
        const { data: treeData } = await octokit.git.getTree({
            owner,
            repo,
            tree_sha: defaultBranch,
            recursive: "true",
        });

        const paths = (treeData.tree || [])
            .filter((item: any) => item.type === "blob" && !SKIP_PATTERNS.some(p => p.test(item.path)))
            .map((item: any) => item.path);

        // Cache for 30 days (2592000 seconds)
        await this.cache.set(cacheKey, paths, 30 * 24 * 60 * 60);
        return paths;
    }

    /**
     * Gathers and caches high-level documentation and configuration files.
     */
    async getArchitectureDocs(
        owner: string,
        repo: string,
        fileTree: string[]
    ): Promise<{ path: string; content: string }[]> {
        const cacheKey = `ai:repo:${owner}/${repo}:docs`;
        const cached = await this.cache.get<{ path: string; content: string }[]>(cacheKey);
        if (cached) {
            return cached.data;
        }

        const docPaths = fileTree.filter(p => {
            const lower = p.toLowerCase();
            return (
                lower === "readme.md" ||
                lower === "architecture.md" ||
                lower === "contributing.md" ||
                lower === "package.json" ||
                lower === "pubspec.yaml" ||
                lower === "tsconfig.json" ||
                lower === "wrangler.toml"
            );
        });

        this.logger.info({ owner, repo, docPaths }, "Fetching architecture docs");
        const docs: { path: string; content: string }[] = [];

        for (const path of docPaths) {
            try {
                const content = await this.fetchSingleFileContent(owner, repo, path);
                if (content) docs.push({ path, content });
            } catch (err: any) {
                this.logger.warn({ path, error: err.message }, "Failed to fetch architecture doc");
            }
        }

        // Cache for 30 days
        await this.cache.set(cacheKey, docs, 30 * 24 * 60 * 60);
        return docs;
    }

    /**
     * Fetches the contents of relevant files identified for a ticket.
     */
    async readFileContents(
        owner: string,
        repo: string,
        paths: string[]
    ): Promise<{ path: string; content: string }[]> {
        const cappedPaths = paths.slice(0, this.maxAiFiles);
        this.logger.info({ owner, repo, count: cappedPaths.length }, "Fetching contents of relevant files");
        
        const files: { path: string; content: string }[] = [];
        for (const path of cappedPaths) {
            try {
                const content = await this.fetchSingleFileContent(owner, repo, path);
                if (content !== null) {
                    files.push({ path, content });
                }
            } catch (err: any) {
                this.logger.warn({ path, error: err.message }, "Failed to fetch file content");
            }
        }
        return files;
    }

    /**
     * Invalidate caches for a repository (called on merge events).
     */
    async invalidateCache(owner: string, repo: string): Promise<void> {
        this.logger.info({ owner, repo }, "Busting AI context caches");
        await Promise.all([
            this.cache.del(`ai:repo:${owner}/${repo}:tree`),
            this.cache.del(`ai:repo:${owner}/${repo}:docs`),
        ]);
    }

    // ─── Private Helpers ─────────────────────────────────────

    private async fetchSingleFileContent(owner: string, repo: string, path: string): Promise<string | null> {
        try {
            const { data } = await this.github.raw.repos.getContent({
                owner,
                repo,
                path,
            });

            if (Array.isArray(data)) return null;
            if (data.type !== "file") return null;

            if (data.encoding === "base64" && data.content) {
                // Decode base64. Using atob is standard in browser/Workers
                return atob(data.content.replace(/\s/g, ""));
            }
            return null;
        } catch (err: any) {
            if (err.status === 404) return null;
            throw err;
        }
    }

    private extractDependencies(docs: { path: string; content: string }[]): Record<string, string> {
        const deps: Record<string, string> = {};
        
        const pkgJson = docs.find(d => d.path === "package.json");
        if (pkgJson) {
            try {
                const parsed = JSON.parse(pkgJson.content);
                const allDeps = {
                    ...(parsed.dependencies || {}),
                    ...(parsed.devDependencies || {}),
                };
                Object.assign(deps, allDeps);
            } catch { /* ignore invalid json */ }
        }

        const pubspec = docs.find(d => d.path === "pubspec.yaml");
        if (pubspec) {
            // Very simple pubspec parser for dependencies
            const lines = pubspec.content.split("\n");
            let inDeps = false;
            for (const line of lines) {
                if (line.startsWith("dependencies:") || line.startsWith("dev_dependencies:")) {
                    inDeps = true;
                    continue;
                }
                if (inDeps && line.trim() && !line.startsWith(" ")) {
                    inDeps = false;
                }
                if (inDeps && line.includes(":")) {
                    const parts = line.split(":");
                    const name = parts[0].trim();
                    const version = parts[1].trim();
                    if (name && !name.startsWith("#")) {
                        deps[name] = version;
                    }
                }
            }
        }

        return deps;
    }

    private async getRecentMergedPRs(owner: string, repo: string): Promise<{ title: string; number: number; body: string | null }[]> {
        try {
            // Retrieve last 5 PRs
            const { data } = await this.github.raw.pulls.list({
                owner,
                repo,
                state: "closed",
                per_page: 5,
            });

            return data
                .filter(pr => pr.merged_at !== null)
                .map(pr => ({
                    title: pr.title,
                    number: pr.number,
                    body: pr.body,
                }));
        } catch (err: any) {
            this.logger.warn({ error: err.message }, "Failed to fetch recent PRs");
            return [];
        }
    }

    private async selectRelevantFiles(
        fileTree: string[],
        issueTitle: string,
        issueBody: string | null,
        docs: { path: string; content: string }[]
    ): Promise<string[]> {
        const systemPrompt = `You are a senior software architect. Given an issue title and description, and a list of file paths in the repository, select the files (up to 30) that are relevant to understanding or implementing the requested changes.
Return ONLY a JSON object with a single "filesToRead" property containing the array of file paths. Do not include markdown codeblocks or explanation.
Example: { "filesToRead": ["src/main.ts", "package.json"] }`;

        const userPrompt = `Issue:
Title: ${issueTitle}
Description:
${issueBody ?? "No description provided"}

File Tree:
${fileTree.join("\n")}
`;

        try {
            const rawResponse = await this.ai.generateCompletion({
                systemPrompt,
                userPrompt,
                jsonMode: true,
            });

            // Parse response
            const cleaned = rawResponse.trim().replace(/^```json/, "").replace(/```$/, "").trim();
            const parsed = JSON.parse(cleaned);
            if (Array.isArray(parsed?.filesToRead)) {
                const files = parsed.filesToRead.filter((f: string) => fileTree.includes(f));
                this.logger.info({ count: files.length }, "AI selected files successfully");
                return files;
            }
        } catch (err: any) {
            this.logger.warn({ error: err.message }, "AI file selection failed, falling back to keyword search");
        }

        // Fallback: simple keyword matching in file tree
        const words = `${issueTitle} ${issueBody ?? ""}`
            .toLowerCase()
            .split(/[^a-zA-Z0-9_.-]/)
            .filter(w => w.length > 3);

        const uniqueWords = Array.from(new Set(words));
        const matched = fileTree.filter(path => {
            const lowerPath = path.toLowerCase();
            return uniqueWords.some(word => lowerPath.includes(word));
        });

        // Always include documentation/config if matched, else cap at 15
        return matched.slice(0, 15);
    }
}
