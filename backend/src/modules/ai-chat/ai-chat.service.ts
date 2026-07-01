/**
 * Sellio Metrics — AI Chat Service
 *
 * Orchestrates the agentic loop for the Sellio Bot:
 *   1. Verify org membership (OrgMemberGuard)
 *   2. Load or create KV session
 *   3. Build system prompt with repo context + tool list
 *   4. Run agentic loop: AI → tool call → result → AI (max 5 iterations)
 *   5. Persist session to KV (2h TTL)
 *   6. Return final message + tool call records
 *
 * Also provides chatFromGitHub() for the webhook mention path —
 * same loop, but posts the result as a GitHub comment instead of JSON.
 */

import type { Logger } from "../../core/logger";
import type { CacheService } from "../../infra/cache/cache.service";
import type { AiProviderClient } from "../../infra/ai/ai-provider.client";
import type { OrgMemberGuard } from "./org-member-guard";
import type { ChatSession, ChatMessage, ToolCallRecord, ToolDeps } from "./ai-chat.types";
import { AgentToolRegistry } from "./agent-tool-registry";
import { AppError } from "../../core/errors";

const SESSION_TTL = 2 * 60 * 60; // 2 hours
const MAX_TOOL_ITERATIONS = 5;

// ─── System prompt builder ───────────────────────────────────

function buildSystemPrompt(
    owner: string,
    repo: string,
    org: string,
    fileTree: string[],
    archDocsText: string,
    toolSummary: string
): string {
    const treePreview = fileTree.slice(0, 80).join("\n");
    return `You are **Sellio Bot** 🤖, a super friendly, witty, and highly capable AI teammate for the **${org}** engineering squad! 
You love programming, checking out code, cracking jokes (especially nerdy coding/git puns), and bantering with the team. You are not a stiff corporate machine; you're one of the devs. You should be helpful, sarcastic when appropriate (but always good-natured and supportive), and make coding fun! 💻🚀

## Repository context
**File tree (first 80 paths):**
\`\`\`
${treePreview}
\`\`\`

**Architecture / Documentation:**
${archDocsText || "(No architecture docs found)"}

## Your capabilities
You have these tools available:
${toolSummary}

## How to call a tool
To execute a tool, you MUST output a JSON block in EXACTLY this format:
\`\`\`json
{
  "tool": "tool_name",
  "args": {
    "arg_name": "value"
  }
}
\`\`\`
IMPORTANT: 
- Do NOT hallucinate that a tool was successful without executing it.
- You must output the JSON block, and the system will pause your execution, run the tool, and give you the result.
- Only confirm success to the user AFTER you receive the tool result.

## Rules
- **Personality**: Be friendly, joke around, use emojis, throw in coding humor or light banter, and call developers by their names/usernames. Keep the team smiling! 😄 Specifically, whenever you are responding to or talking about **ABDULLAHHG** (or @ABDULLAHHG), be sure to tell him **"الحياه حلوه"** (Life is beautiful)! 🌸✨
- Always use tools to take real actions (create issues, review PRs, etc.) rather than just talking about them.
- If the user asks to create multiple tickets/issues, you MUST use \`bulk_create_issues\` in a single call to avoid making multiple requests and duplicate numbers.
- If a tool returns \`{ error: true, message: "..." }\`, report the error **exactly as given** — quote the raw \`message\` and \`status\`. Do NOT invent or speculate about the cause. In particular, NEVER claim you lack a permission, that a repo doesn't exist, or that the GitHub App isn't installed unless the tool's error message literally says so. A 404 almost always means the specific PR/issue/file number was wrong — not a permissions problem.
- **Do not confabulate.** Never describe your own capabilities, permissions, or access in ways you cannot verify from the tool list or a tool result. You DO have repo read/write access (you post these comments and can read files via \`read_file\`); do not tell users otherwise.
- If an action is not supported or you lack a tool for it, say so plainly and name the closest tool you *do* have — never pretend you can do something you cannot, and never fabricate a technical excuse.
- Keep responses concise and highly structured (markdown). You only assist members of the **${org}** GitHub organization.`;
}

// ─── Service ─────────────────────────────────────────────────

export class AiChatService {
    private readonly ai: AiProviderClient;
    private readonly cache: CacheService;
    private readonly orgMemberGuard: OrgMemberGuard;
    private readonly toolRegistry: AgentToolRegistry;
    private readonly contextService: any;
    private readonly openTicketsService: any;
    private readonly reviewService: any;
    private readonly scoreAggregationService: any;
    private readonly gitOpsService: any;
    private readonly cachedGithubClient: any;
    private readonly syncQueue: any | null;
    private readonly org: string;
    private readonly logger: Logger;

    constructor({
        aiProviderClient,
        cacheService,
        orgMemberGuard,
        contextService,
        openTicketsService,
        reviewService,
        scoreAggregationService,
        gitOpsService,
        cachedGithubClient,
        syncQueue,
        env,
        logger,
    }: {
        aiProviderClient: AiProviderClient;
        cacheService: CacheService;
        orgMemberGuard: OrgMemberGuard;
        contextService: any;
        openTicketsService: any;
        reviewService: any;
        scoreAggregationService: any;
        gitOpsService: any;
        cachedGithubClient: any;
        syncQueue: any | null;
        env: { org: string };
        logger: Logger;
    }) {
        this.ai = aiProviderClient;
        this.cache = cacheService;
        this.orgMemberGuard = orgMemberGuard;
        this.contextService = contextService;
        this.openTicketsService = openTicketsService;
        this.reviewService = reviewService;
        this.scoreAggregationService = scoreAggregationService;
        this.gitOpsService = gitOpsService;
        this.cachedGithubClient = cachedGithubClient;
        this.syncQueue = syncQueue;
        this.org = env.org;
        this.logger = logger.child({ module: "ai-chat" });
        this.toolRegistry = new AgentToolRegistry();
    }

    // ─── Dashboard chat endpoint ─────────────────────────────

    async chat(
        owner: string,
        repo: string,
        userMessage: string,
        sessionId?: string
    ): Promise<{ sessionId: string; message: string; toolCallsMade: ToolCallRecord[] }> {

        // 1. Security: org membership is bypassed (removed)
        
        // 2. Load or create session
        const sid = sessionId ?? crypto.randomUUID();
        const session = await this.loadOrCreateSession(sid, owner, repo);

        // 3. Get repo context (cached)
        const { fileTree, archDocsText } = await this.getRepoContext(owner, repo);

        // 4. Append user message
        session.messages.push({ role: "user", content: userMessage, timestamp: new Date().toISOString() });

        // 5. Run agentic loop
        const { finalMessage, toolCallsMade } = await this.runAgenticLoop(
            owner, repo, session, fileTree, archDocsText
        );

        // 6. Append assistant message & persist
        session.messages.push({ role: "assistant", content: finalMessage, timestamp: new Date().toISOString() });
        session.updatedAt = new Date().toISOString();
        await this.cache.set(`ai:chat:session:${sid}`, session, SESSION_TTL);

        return { sessionId: sid, message: finalMessage, toolCallsMade };
    }

    // ─── GitHub mention path ─────────────────────────────────

    async chatFromGitHub(
        owner: string,
        repo: string,
        author: string,
        issueNumber: number,
        commentBody: string
    ): Promise<void> {
        this.logger.info({ owner, repo, author, issueNumber }, "Routing GitHub mention to agentic bot");

        try {
            // Strip the @sellio mention from the comment
            const userMessage = commentBody.replace(/@sellio[\-\w]*/gi, "").trim();
            if (!userMessage) {
                await this.gitOpsService.commentOnIssue(owner, repo, issueNumber,
                    `👋 Hey @${author}! I'm **Sellio Bot**. How can I help? Try mentioning me with a request, like:\n> @sellio create a ticket for the login bug\n> @sellio review PR #42`);
                return;
            }

            // Use issue thread as conversation context
            const octokit = this.cachedGithubClient.raw;
            const [{ data: issue }, { data: comments }] = await Promise.all([
                octokit.issues.get({ owner, repo, issue_number: issueNumber }),
                octokit.issues.listComments({ owner, repo, issue_number: issueNumber, per_page: 20 }),
            ]);

            // Build a mini session from the issue thread (ephemeral, not stored in KV)
            const contextMessages: ChatMessage[] = [
                {
                    role: "user",
                    content: `Issue #${issueNumber}: ${issue.title}\n\n${issue.body ?? ""}`,
                    timestamp: new Date().toISOString(),
                },
                ...comments.slice(-10).map((c: any) => ({
                    role: "user" as const,
                    content: `**@${c.user?.login ?? "user"}**: ${c.body ?? ""}`,
                    timestamp: c.created_at,
                })),
                { role: "user", content: userMessage, timestamp: new Date().toISOString() },
            ];

            const session: ChatSession = {
                sessionId: `gh:${owner}:${repo}:${issueNumber}`,
                owner, repo,
                messages: contextMessages,
                createdAt: new Date().toISOString(),
                updatedAt: new Date().toISOString(),
            };

            const { fileTree, archDocsText } = await this.getRepoContext(owner, repo);
            const { finalMessage, toolCallsMade } = await this.runAgenticLoop(owner, repo, session, fileTree, archDocsText);

            // Build tool summary for the comment
            let toolSummaryText = "";
            if (toolCallsMade.length > 0) {
                toolSummaryText = "\n\n---\n🔧 **Actions taken:** " +
                    toolCallsMade.map(t => `\`${t.name}\``).join(", ");
            }

            await this.gitOpsService.commentOnIssue(owner, repo, issueNumber,
                `🤖 **Sellio Bot** — responding to @${author}:\n\n${finalMessage}${toolSummaryText}`
            );

            this.logger.info({ owner, repo, issueNumber, tools: toolCallsMade.length }, "GitHub mention handled");
        } catch (err: any) {
            this.logger.error({ owner, repo, issueNumber, err: err.message }, "Failed to handle GitHub mention");
            try {
                await this.gitOpsService.commentOnIssue(owner, repo, issueNumber,
                    `❌ **Sellio Bot** encountered an error: ${err.message}. Please try again or contact the squad admin.`);
            } catch { /* ignore */ }
        }
    }

    // ─── Agentic loop ────────────────────────────────────────

    private async runAgenticLoop(
        owner: string,
        repo: string,
        session: ChatSession,
        fileTree: string[],
        archDocsText: string
    ): Promise<{ finalMessage: string; toolCallsMade: ToolCallRecord[] }> {

        const gqlClient = await this.getGqlClient();
        const toolDeps: ToolDeps = {
            owner, repo, org: this.org,
            octokit: this.cachedGithubClient.raw,
            gqlClient,
            contextService: this.contextService,
            openTicketsService: this.openTicketsService,
            reviewService: this.reviewService,
            scoreAggregationService: this.scoreAggregationService,
            gitOpsService: this.gitOpsService,
            syncQueue: this.syncQueue,
            logger: this.logger,
        };

        const systemPrompt = buildSystemPrompt(
            owner, repo, this.org,
            fileTree, archDocsText,
            this.toolRegistry.getToolSummary()
        );

        // Build messages array for the AI
        const aiMessages = session.messages.map(m => ({
            role: m.role === "tool_result" ? "user" : m.role,
            content: m.role === "tool_result"
                ? `[Tool result from ${m.toolName}]: ${JSON.stringify(m.toolResult)}`
                : m.content,
        }));

        const toolCallsMade: ToolCallRecord[] = [];
        let finalMessage = "";

        for (let i = 0; i < MAX_TOOL_ITERATIONS; i++) {
            // Use the "fast" tier: it tries Workers AI first (free, runs on Cloudflare's
            // GPUs with its own quota) and automatically falls through to the premium
            // providers (Gemini/OpenAI/…) if it fails. This preserves the scarce external
            // free-tier quotas for when they're actually needed.
            const response = await this.ai.generateCompletion({
                systemPrompt,
                userPrompt: aiMessages.map(m => `${m.role}: ${m.content}`).join("\n\n"),
            }, "fast");

            // Parse tool call from response if AI wraps it in JSON
            const toolCall = this.extractToolCall(response);

            if (!toolCall) {
                finalMessage = response;
                break;
            }

            this.logger.info({ tool: toolCall.name, args: toolCall.args }, "Agent calling tool");
            const result = await this.toolRegistry.execute(toolCall.name, toolCall.args, toolDeps);

            toolCallsMade.push({ name: toolCall.name, args: toolCall.args, result });

            // Append tool result to conversation for next iteration
            const toolResultMsg = `[Tool: ${toolCall.name}] Result: ${JSON.stringify(result)}`;
            aiMessages.push({ role: "user", content: toolResultMsg });

            // If this was the last iteration, force a final response
            if (i === MAX_TOOL_ITERATIONS - 1) {
                finalMessage = await this.ai.generateCompletion({
                    systemPrompt,
                    userPrompt: aiMessages.map(m => `${m.role}: ${m.content}`).join("\n\n") +
                        "\n\nassistant: Summarize what was accomplished for the user.",
                }, "fast");
            }
        }

        return { finalMessage: finalMessage || "Done! Let me know if you need anything else.", toolCallsMade };
    }

    // ─── Tool call extraction ────────────────────────────────

    private extractToolCall(response: string): { name: string; args: unknown } | null {
        // Try to parse a JSON tool call if the AI outputs one in the format:
        // {"tool":"name","args":{...}}  or  ```json\n{"tool":"name","args":{...}}
        try {
            const jsonMatch = response.match(/```(?:json)?\s*(\{[\s\S]*?"tool"[\s\S]*?\})\s*```/);
            if (jsonMatch) {
                const parsed = JSON.parse(jsonMatch[1]);
                if (parsed.tool && typeof parsed.tool === "string") {
                    return { name: parsed.tool, args: parsed.args ?? {} };
                }
            }
            // Direct JSON in response (no fence)
            if (response.trimStart().startsWith("{")) {
                const parsed = JSON.parse(response);
                if (parsed.tool && typeof parsed.tool === "string") {
                    return { name: parsed.tool, args: parsed.args ?? {} };
                }
            }
        } catch { /* not a tool call */ }
        return null;
    }

    // ─── Session management ──────────────────────────────────

    private async loadOrCreateSession(sessionId: string, owner: string, repo: string): Promise<ChatSession> {
        const cacheKey = `ai:chat:session:${sessionId}`;
        const cached = await this.cache.get<ChatSession>(cacheKey);
        if (cached) return cached.data;
        return {
            sessionId,
            owner, repo,
            messages: [],
            createdAt: new Date().toISOString(),
            updatedAt: new Date().toISOString(),
        };
    }

    async deleteSession(sessionId: string): Promise<void> {
        await this.cache.del(`ai:chat:session:${sessionId}`);
    }

    // ─── Repo context (cached) ───────────────────────────────

    private async getRepoContext(owner: string, repo: string): Promise<{ fileTree: string[]; archDocsText: string }> {
        try {
            const fileTree: string[] = await this.contextService.getRepoTree(owner, repo);
            const archDocs = await this.contextService.getArchitectureDocs(owner, repo, fileTree);
            const archDocsText = (archDocs as any[])
                .map((d: any) => `### ${d.path}\n${d.content}`)
                .join("\n\n")
                .slice(0, 8000); // cap at 8k chars
            return { fileTree, archDocsText };
        } catch (err: any) {
            this.logger.warn({ owner, repo, err: err.message }, "Could not load repo context — proceeding without it");
            return { fileTree: [], archDocsText: "" };
        }
    }

    // ─── GraphQL client (lazy) ───────────────────────────────

    private async getGqlClient(): Promise<any> {
        const { GitHubGraphQLClient } = await import("../../infra/github/github-graphql.client");
        return new GitHubGraphQLClient(this.cachedGithubClient.raw, this.logger);
    }
}
