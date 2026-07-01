/**
 * Sellio Metrics — Agent Tool Registry
 *
 * Defines all tools the AI agent can call.
 * Each tool maps to an existing backend service method.
 *
 * To add a new capability: append one entry to TOOLS array.
 * The AI discovers and uses tools automatically via the tool schemas.
 */

import type { AgentTool, ToolDeps } from "./ai-chat.types";

// ─── Helper: wrap execute() with structured error handling ───

function withErrorHandling(
    name: string,
    fn: (args: any, deps: ToolDeps) => Promise<unknown>
): (args: any, deps: ToolDeps) => Promise<unknown> {
    return async (args, deps) => {
        try {
            return await fn(args, deps);
        } catch (err: any) {
            const status = err.status ?? err.statusCode;
            let hint = err.message;
            // Keep hints factual: report the raw status/message and the exact resource that
            // was requested. Do NOT assert a specific cause (e.g. "the app isn't installed")
            // that we cannot verify — the LLM tends to amplify guessed causes into confident,
            // false explanations to the user.
            const resource = `${deps.owner}/${deps.repo}`;
            if (status === 403) hint = `GitHub returned 403 (forbidden) for '${resource}' while running '${name}'. Raw message: ${err.message}`;
            if (status === 404) hint = `GitHub returned 404 (not found) for '${resource}' while running '${name}'. This usually means the specific PR/issue/file number does not exist. Raw message: ${err.message}`;
            if (status === 422) hint = `GitHub returned 422 (validation failed) while running '${name}': ${err.message}`;
            deps.logger.warn({ tool: name, err: err.message, status }, "Tool execution error");
            return { error: true, status: status ?? null, message: hint };
        }
    };
}

// ─── Project name resolver (shared by create tools) ─────────

async function resolveProjectNodeId(
    org: string,
    repoName: string,
    gqlClient: any,
    logger: any
): Promise<string | null> {
    try {
        const projects = await gqlClient.listOrgProjectsSlim(org);
        // fuzzy match: "sellio_mobile" matches "Sellio Mobile" or "sellio_mobile"
        const normalized = repoName.toLowerCase().replace(/[_\-]/g, " ");
        const match = projects.find((p: any) => {
            const title = (p.title ?? "").toLowerCase().replace(/[_\-]/g, " ");
            return title.includes(normalized) || normalized.includes(title);
        });
        if (match) {
            logger.info({ project: match.title, nodeId: match.id }, "Resolved project for repo");
            return match.id;
        }
        logger.warn({ repoName, available: projects.map((p: any) => p.title) }, "No matching project found for repo");
        return null;
    } catch (err: any) {
        logger.warn({ err: err.message }, "Failed to resolve project node ID");
        return null;
    }
}

// ─── Tool definitions ────────────────────────────────────────

export const TOOLS: AgentTool[] = [
    // ── 1. Create a single GitHub issue ──────────────────────
    {
        name: "create_github_issue",
        description: "Create a single GitHub issue in the current repo and auto-add it to the matching project board. Deduplicates automatically by title.",
        parameters: {
            type: "object",
            properties: {
                title: { type: "string", description: "Issue title" },
                body:  { type: "string", description: "Issue description in markdown" },
                labels: { type: "array", items: { type: "string" }, description: "Optional label names" },
            },
            required: ["title", "body"],
        },
        execute: withErrorHandling("create_github_issue", async (args, deps) => {
            const { octokit, owner, repo, org, gqlClient, logger } = deps;
            
            // Deduplication check: check if an open issue with the same title already exists.
            // NOTE: issues.listForRepo also returns pull requests (GitHub models PRs as issues).
            // We filter out anything with a `pull_request` field so a PR is never treated as a
            // duplicate issue — this previously caused create_github_issue to "match" the PR itself.
            const { data: existingItems } = await octokit.issues.listForRepo({
                owner,
                repo,
                state: "open",
                per_page: 100,
            });
            const existingIssues = existingItems.filter((item: any) => !item.pull_request);
            const searchTitle = args.title.trim().toLowerCase();
            const duplicate = existingIssues.find((issue: any) => issue.title.trim().toLowerCase() === searchTitle);
            
            if (duplicate) {
                logger.info({ title: args.title, issueNumber: duplicate.number }, "Found duplicate issue by title, skipping creation");
                return {
                    issueNumber: duplicate.number,
                    issueUrl: duplicate.html_url,
                    title: duplicate.title,
                    addedToProject: false,
                    projectId: null,
                    alreadyExists: true,
                };
            }

            const { data: issue } = await octokit.issues.create({
                owner,
                repo,
                title: args.title,
                body: args.body ?? "",
                labels: args.labels ?? [],
            });

            // Auto-add to project if we can resolve the project node ID
            const projectId = await resolveProjectNodeId(org, repo, gqlClient, logger);
            let addedToProject = false;
            if (projectId) {
                try {
                    await gqlClient.addProjectV2Item(projectId, issue.node_id);
                    addedToProject = true;
                } catch (err: any) {
                    logger.warn({ err: err.message }, "Could not add issue to project — continuing");
                }
            }

            return {
                issueNumber: issue.number,
                issueUrl: issue.html_url,
                title: issue.title,
                addedToProject,
                projectId: projectId ?? null,
                alreadyExists: false,
            };
        }),
    },

    // ── 2. Bulk create multiple GitHub issues ─────────────────
    {
        name: "bulk_create_issues",
        description: "Create multiple GitHub issues at once from a list. Use when the user asks for several tickets in one request. Deduplicates automatically by title.",
        parameters: {
            type: "object",
            properties: {
                issues: {
                    type: "array",
                    description: "List of issues to create",
                    items: {
                        type: "object",
                        properties: {
                            title:  { type: "string" },
                            body:   { type: "string" },
                            labels: { type: "array", items: { type: "string" } },
                        },
                        required: ["title", "body"],
                    },
                },
            },
            required: ["issues"],
        },
        execute: withErrorHandling("bulk_create_issues", async (args, deps) => {
            const { octokit, owner, repo, org, gqlClient, logger } = deps;
            const projectId = await resolveProjectNodeId(org, repo, gqlClient, logger);

            // Fetch open issues once for the whole bulk run to save API calls.
            // Filter out pull requests — issues.listForRepo returns PRs too, and a PR must
            // never be matched as a duplicate issue.
            const { data: existingItems } = await octokit.issues.listForRepo({
                owner,
                repo,
                state: "open",
                per_page: 100,
            });
            const existingIssues = existingItems.filter((item: any) => !item.pull_request);

            const created: any[] = [];
            const skipped: any[] = [];

            for (const issueArgs of args.issues) {
                const searchTitle = issueArgs.title.trim().toLowerCase();
                const duplicate = existingIssues.find((issue: any) => issue.title.trim().toLowerCase() === searchTitle);

                if (duplicate) {
                    logger.info({ title: issueArgs.title, issueNumber: duplicate.number }, "Skipping bulk creation of duplicate issue");
                    skipped.push({
                        issueNumber: duplicate.number,
                        issueUrl: duplicate.html_url,
                        title: duplicate.title,
                    });
                    continue;
                }

                const { data: issue } = await octokit.issues.create({
                    owner,
                    repo,
                    title: issueArgs.title,
                    body: issueArgs.body ?? "",
                    labels: issueArgs.labels ?? [],
                });

                let addedToProject = false;
                if (projectId) {
                    try {
                        await gqlClient.addProjectV2Item(projectId, issue.node_id);
                        addedToProject = true;
                    } catch (err: any) {
                        logger.warn({ issueNumber: issue.number, err: err.message }, "Could not add issue to project");
                    }
                }

                created.push({
                    issueNumber: issue.number,
                    issueUrl: issue.html_url,
                    title: issue.title,
                    addedToProject,
                });
            }

            return { created, skipped, totalCreated: created.length, totalSkipped: skipped.length, projectId: projectId ?? null };
        }),
    },

    // ── 3. Move a project card to a column ────────────────────
    {
        name: "move_project_card",
        description: "Move a GitHub Projects V2 card to a different status column (e.g. 'In Progress', 'Done', 'Backlog').",
        parameters: {
            type: "object",
            properties: {
                projectId:  { type: "string", description: "Project node ID" },
                itemId:     { type: "string", description: "Project item node ID" },
                fieldId:    { type: "string", description: "Status field node ID" },
                columnName: { type: "string", description: "Target column name, e.g. 'In Progress'" },
            },
            required: ["projectId", "itemId", "fieldId", "columnName"],
        },
        execute: withErrorHandling("move_project_card", async (args, deps) => {
            await deps.gitOpsService.moveProjectCardByName(
                args.projectId, args.itemId, args.fieldId, args.columnName
            );
            return { moved: true, column: args.columnName };
        }),
    },

    // ── 4. Comment on an issue or PR ──────────────────────────
    {
        name: "comment_on_issue",
        description: "Post a comment on a GitHub issue or pull request.",
        parameters: {
            type: "object",
            properties: {
                issueNumber: { type: "number", description: "Issue or PR number" },
                body:        { type: "string", description: "Comment body in markdown" },
            },
            required: ["issueNumber", "body"],
        },
        execute: withErrorHandling("comment_on_issue", async (args, deps) => {
            await deps.gitOpsService.commentOnIssue(deps.owner, deps.repo, args.issueNumber, args.body);
            return { commented: true, issueNumber: args.issueNumber };
        }),
    },

    // ── 5. Close an issue ────────────────────────────────────
    {
        name: "close_issue",
        description: "Close a GitHub issue by its number.",
        parameters: {
            type: "object",
            properties: {
                issueNumber: { type: "number" },
                reason:      { type: "string", enum: ["completed", "not_planned"], description: "Close reason" },
            },
            required: ["issueNumber"],
        },
        execute: withErrorHandling("close_issue", async (args, deps) => {
            const { octokit, owner, repo } = deps;
            const { data } = await octokit.issues.update({
                owner, repo,
                issue_number: args.issueNumber,
                state: "closed",
                state_reason: args.reason ?? "completed",
            });
            return { closed: true, issueNumber: data.number, url: data.html_url };
        }),
    },

    // ── 5b. Close a pull request ─────────────────────────────
    {
        name: "close_pr",
        description: "Close a pull request without merging it, by its number. Use this when asked to close (not merge) a PR.",
        parameters: {
            type: "object",
            properties: {
                prNumber: { type: "number", description: "Pull request number" },
                comment:  { type: "string", description: "Optional comment to post before closing (e.g. reason for closing)" },
            },
            required: ["prNumber"],
        },
        execute: withErrorHandling("close_pr", async (args, deps) => {
            const { octokit, owner, repo } = deps;
            if (args.comment) {
                await deps.gitOpsService.commentOnIssue(owner, repo, args.prNumber, args.comment);
            }
            const { data } = await octokit.pulls.update({
                owner, repo,
                pull_number: args.prNumber,
                state: "closed",
            });
            return { closed: true, prNumber: data.number, url: data.html_url, state: data.state };
        }),
    },

    // ── 5c. Link an issue to a pull request ──────────────────
    {
        name: "link_issue_to_pr",
        description: "Link a GitHub issue to a pull request so merging the PR auto-closes the issue. Appends a 'Closes #<issue>' reference to the PR body.",
        parameters: {
            type: "object",
            properties: {
                prNumber:    { type: "number", description: "Pull request number" },
                issueNumber: { type: "number", description: "Issue number to link (the PR will close it on merge)" },
                keyword:     { type: "string", enum: ["Closes", "Fixes", "Resolves"], description: "Closing keyword (default: Closes)" },
            },
            required: ["prNumber", "issueNumber"],
        },
        execute: withErrorHandling("link_issue_to_pr", async (args, deps) => {
            const { octokit, owner, repo } = deps;
            const keyword = args.keyword ?? "Closes";
            const reference = `${keyword} #${args.issueNumber}`;

            // Fetch the current PR body so we can append the link without clobbering it
            const { data: pr } = await octokit.pulls.get({ owner, repo, pull_number: args.prNumber });
            const currentBody = pr.body ?? "";

            // Skip if the exact reference is already present (idempotent)
            const linkRegex = new RegExp(`\\b(clos|fix|resolv)\\w*\\s+#${args.issueNumber}\\b`, "i");
            if (linkRegex.test(currentBody)) {
                return { linked: true, alreadyLinked: true, prNumber: args.prNumber, issueNumber: args.issueNumber, reference };
            }

            const newBody = currentBody.trim().length > 0
                ? `${currentBody.trim()}\n\n${reference}`
                : reference;

            await octokit.pulls.update({
                owner, repo,
                pull_number: args.prNumber,
                body: newBody,
            });
            return { linked: true, alreadyLinked: false, prNumber: args.prNumber, issueNumber: args.issueNumber, reference };
        }),
    },

    // ── 6. Read a file from the repo ─────────────────────────
    {
        name: "read_file",
        description: "Read the content of a specific file from the repo. Use to inspect code, config, or docs.",
        parameters: {
            type: "object",
            properties: {
                path: { type: "string", description: "File path relative to the repo root, e.g. 'lib/main.dart'" },
            },
            required: ["path"],
        },
        execute: withErrorHandling("read_file", async (args, deps) => {
            const contents = await deps.contextService.readFileContents(deps.owner, deps.repo, [args.path]);
            const file = contents.find((f: any) => f.path === args.path);
            if (!file) return { error: true, message: `File '${args.path}' not found in the repo.` };
            return { path: file.path, content: file.content };
        }),
    },

    // ── 7. Search file tree ──────────────────────────────────
    {
        name: "search_repo_files",
        description: "Search the repo file tree by keyword or extension. Returns matching file paths.",
        parameters: {
            type: "object",
            properties: {
                query: { type: "string", description: "Keyword to search for in file paths, e.g. 'auth', '.service.ts'" },
            },
            required: ["query"],
        },
        execute: withErrorHandling("search_repo_files", async (args, deps) => {
            const tree: string[] = await deps.contextService.getRepoTree(deps.owner, deps.repo);
            const q = args.query.toLowerCase();
            const matches = tree.filter((p: string) => p.toLowerCase().includes(q));
            return { query: args.query, matches: matches.slice(0, 50), total: matches.length };
        }),
    },

    // ── 8. List open tickets ──────────────────────────────────
    {
        name: "list_open_tickets",
        description: "List open GitHub issues and project tickets for the org.",
        parameters: {
            type: "object",
            properties: {
                repo: { type: "string", description: "Optional: filter by repo name" },
            },
        },
        execute: withErrorHandling("list_open_tickets", async (args, deps) => {
            const tickets = await deps.openTicketsService.fetchOpenTickets(deps.org);
            const filtered = args.repo
                ? tickets.filter((t: any) => t.repo?.toLowerCase() === args.repo.toLowerCase())
                : tickets;
            return { tickets: filtered.slice(0, 30), total: filtered.length };
        }),
    },

    // ── 9. List open PRs ─────────────────────────────────────
    {
        name: "list_open_prs",
        description: "List open pull requests in the current repo.",
        parameters: {
            type: "object",
            properties: {
                state: { type: "string", enum: ["open", "closed", "all"], description: "PR state filter (default: open)" },
            },
        },
        execute: withErrorHandling("list_open_prs", async (args, deps) => {
            const { octokit, owner, repo } = deps;
            const { data } = await octokit.pulls.list({
                owner, repo,
                state: args.state ?? "open",
                per_page: 20,
            });
            return {
                prs: data.map((pr: any) => ({
                    number: pr.number,
                    title: pr.title,
                    author: pr.user?.login,
                    url: pr.html_url,
                    state: pr.state,
                    draft: pr.draft,
                    createdAt: pr.created_at,
                })),
                total: data.length,
            };
        }),
    },

    // ── 10. Review a PR ──────────────────────────────────────
    {
        name: "review_pr",
        description: "Run an AI code review on a pull request. Returns bug findings, security issues, and suggestions.",
        parameters: {
            type: "object",
            properties: {
                prNumber: { type: "number", description: "Pull request number" },
            },
            required: ["prNumber"],
        },
        execute: withErrorHandling("review_pr", async (args, deps) => {
            const review = await deps.reviewService.reviewPr(deps.owner, deps.repo, args.prNumber);
            return {
                prTitle: review.pr.title,
                bugs: review.review.bugs,
                security: review.review.security,
                suggestions: review.review.suggestions,
                summary: review.review.summary,
                filesReviewed: review.reviewMeta.filesReviewed,
                fromCache: review.fromCache,
            };
        }),
    },

    // ── 11. Trigger AI implementation for an issue ───────────
    {
        name: "trigger_ai_implement",
        description: "Trigger the Sellio AI Agent to autonomously implement a GitHub issue (generates code, opens a PR). Use with caution.",
        parameters: {
            type: "object",
            properties: {
                issueNumber: { type: "number", description: "Issue number to implement" },
                projectId:   { type: "string", description: "Project node ID for moving the card" },
                itemId:      { type: "string", description: "Project item node ID" },
                fieldId:     { type: "string", description: "Status field node ID" },
                agentType:   { type: "string", enum: ["openhands", "swe-agent"], description: "Which AI agent to run. 'swe-agent' is more token-efficient and fits better in free tier quotas. 'openhands' is standard.", default: "swe-agent" },
            },
            required: ["issueNumber"],
        },
        execute: withErrorHandling("trigger_ai_implement", async (args, deps) => {
            const { octokit, owner, repo, syncQueue, logger } = deps;
            const { data: issue } = await octokit.issues.get({ owner, repo, issue_number: args.issueNumber });
            const job = {
                type: "ai_implement",
                owner, repo,
                issueNumber: issue.number,
                issueTitle: issue.title,
                issueBody: issue.body,
                projectId: args.projectId ?? "",
                itemId: args.itemId ?? "",
                fieldId: args.fieldId ?? "",
                agentType: args.agentType || "swe-agent",
                phase: 1,
                taskId: `${owner}-${repo}-${issue.number}-${Date.now()}`,
            };

            if (syncQueue) {
                await syncQueue.send(job);
                return { enqueued: true, taskId: job.taskId, issueNumber: issue.number, agentType: job.agentType };
            }
            logger.warn("syncQueue not available — cannot enqueue AI implement job");
            return { error: true, message: "AI implementation queue is not configured. Contact the squad admin." };
        }),
    },

    // ── 12. Get team leaderboard ─────────────────────────────
    {
        name: "get_leaderboard",
        description: "Fetch the current team leaderboard with scores and rankings.",
        parameters: {
            type: "object",
            properties: {
                limit: { type: "number", description: "Max number of entries to return (default 10)" },
            },
        },
        execute: withErrorHandling("get_leaderboard", async (args, deps) => {
            const result = await deps.scoreAggregationService.getLeaderboard(args.limit ?? 10);
            return { entries: result.entries, cachedAt: result.cachedAt };
        }),
    },

    // ── 13. Resolve project node ID by name ──────────────────
    {
        name: "resolve_project_id",
        description: "Find the GitHub Projects V2 node ID for a project by its name.",
        parameters: {
            type: "object",
            properties: {
                projectName: { type: "string", description: "Project name or partial name, e.g. 'Sellio Mobile'" },
            },
            required: ["projectName"],
        },
        execute: withErrorHandling("resolve_project_id", async (args, deps) => {
            const projects = await deps.gqlClient.listOrgProjectsSlim(deps.org);
            const q = args.projectName.toLowerCase().replace(/[_\-]/g, " ");
            const match = projects.find((p: any) => {
                const title = (p.title ?? "").toLowerCase().replace(/[_\-]/g, " ");
                return title.includes(q) || q.includes(title);
            });
            if (!match) return { found: false, available: projects.map((p: any) => p.title) };
            return { found: true, projectId: match.id, title: match.title, number: match.number };
        }),
    },

    // ── 14. Get repo CI status ───────────────────────────────
    {
        name: "get_repo_ci_status",
        description: "Get recent CI workflow runs for the repo, including any failures.",
        parameters: {
            type: "object",
            properties: {
                branch: { type: "string", description: "Branch name (default: main/master)" },
            },
        },
        execute: withErrorHandling("get_repo_ci_status", async (args, deps) => {
            const branch = args.branch ?? "main";
            const runs = await deps.gitOpsService.listWorkflowRunsForBranch(deps.owner, deps.repo, branch);
            return {
                branch,
                runs: runs.slice(0, 5).map((r: any) => ({
                    id: r.id,
                    name: r.name,
                    status: r.status,
                    conclusion: r.conclusion,
                    branch: r.head_branch,
                    url: r.html_url,
                    createdAt: r.created_at,
                })),
            };
        }),
    },
    // ── 15. Get PR review comments ───────────────────────────
    {
        name: "get_pr_review_comments",
        description: "Fetch all inline code review comments on a pull request. Use to understand what reviewers have flagged.",
        parameters: {
            type: "object",
            properties: {
                prNumber: { type: "number", description: "Pull request number" },
            },
            required: ["prNumber"],
        },
        execute: withErrorHandling("get_pr_review_comments", async (args, deps) => {
            const { octokit, owner, repo } = deps;
            const { data } = await octokit.pulls.listReviewComments({
                owner,
                repo,
                pull_number: args.prNumber,
            });
            return data.map((c: any) => ({
                id: c.id,
                path: c.path,
                line: c.line,
                body: c.body,
                author: c.user?.login,
                diffHunk: c.diff_hunk,
                url: c.html_url,
            }));
        }),
    },
];

// ─── Registry class ──────────────────────────────────────────

export class AgentToolRegistry {
    private readonly toolMap: Map<string, AgentTool>;

    constructor() {
        this.toolMap = new Map(TOOLS.map(t => [t.name, t]));
    }

    /** Returns the tool list in OpenAI-compatible function-calling format. */
    getToolSchemas(): { type: "function"; function: { name: string; description: string; parameters: Record<string, unknown> } }[] {
        return TOOLS.map(t => ({
            type: "function" as const,
            function: {
                name: t.name,
                description: t.description,
                parameters: t.parameters,
            },
        }));
    }

    /** Executes a named tool with the given args and deps. Returns a structured result. */
    async execute(toolName: string, args: unknown, deps: ToolDeps): Promise<unknown> {
        const tool = this.toolMap.get(toolName);
        if (!tool) {
            return {
                error: true,
                message: `Tool '${toolName}' is not implemented. Available tools: ${[...this.toolMap.keys()].join(", ")}`,
            };
        }
        return tool.execute(args, deps);
    }

    /** Returns a plain-text summary of all tools for the system prompt. */
    getToolSummary(): string {
        return TOOLS.map(t => `- **${t.name}**: ${t.description}`).join("\n");
    }
}
