/**
 * Webhook Service — Decoupled Business Logic
 *
 * Pure business logic handlers for each GitHub event type.
 * The route layer dispatches to these methods after validation,
 * signature verification, and deduplication.
 *
 * Design:
 *  - No HTTP concerns (no c.json, no c.req)
 *  - Independent DB operations run in parallel via Promise.all
 *  - No unsafe `as string` casts — uses Zod-parsed types
 *  - Returns structured results for the route to serialize
 */

import type { Logger } from "../../core/logger";
import type { ReposRepository } from "../repos/repos.repository";
import type { DeveloperRepository } from "../developers/developer.repository";
import type { PrsRepository } from "../prs/prs.repository";
import type { CommentsRepository } from "../prs/comments.repository";
import type { CommitsRepository } from "../commits/commits.repository";
import type { OpenPrsService } from "../prs/open-prs.service";
import type { CacheService } from "../../infra/cache/cache.service";
import type { CacheRegistry } from "../../infra/cache/cache-registry";
import type { CachedGitHubClient } from "../../infra/github/cached-github.client";
import { GitHubGraphQLClient } from "../../infra/github/github-graphql.client";
import { isBot } from "../../lib/bot-filter";
import type {
    PullRequestPayload,
    IssueCommentPayload,
    ReviewCommentPayload,
    OrgMembershipPayload,
    PushPayload,
} from "./webhook.schemas";
import type { AiPipelineService } from "../ai-pipeline/ai-pipeline.service";
import type { AiChatService } from "../ai-chat/ai-chat.service";
import type { OrgMemberGuard } from "../ai-chat/org-member-guard";

export interface WebhookHandlerResult {
    affectedDevelopers: string[];
    botPromise?: Promise<any>;
}

interface WebhookServiceDeps {
    logger: Logger;
    reposRepo: ReposRepository;
    developerRepo: DeveloperRepository;
    prsRepo: PrsRepository;
    commentsRepo: CommentsRepository;
    commitsRepo: CommitsRepository;
    openPrsService: OpenPrsService;
    cache: CacheRegistry;
    cachedGithubClient?: CachedGitHubClient;
    env: { org: string };
    aiPipelineService: AiPipelineService;
    aiChatService: AiChatService;
    orgMemberGuard: OrgMemberGuard;
}

export class WebhookService {
    private readonly logger: Logger;
    private readonly reposRepo: ReposRepository;
    private readonly developerRepo: DeveloperRepository;
    private readonly prsRepo: PrsRepository;
    private readonly commentsRepo: CommentsRepository;
    private readonly commitsRepo: CommitsRepository;
    private readonly openPrsService: OpenPrsService;
    private readonly cache: CacheRegistry;
    private readonly cachedGithubClient?: CachedGitHubClient;
    private readonly org: string;
    private readonly aiPipelineService: AiPipelineService;
    private readonly aiChatService: AiChatService;
    private readonly orgMemberGuard: OrgMemberGuard;

    constructor(deps: WebhookServiceDeps) {
        this.logger        = deps.logger.child({ module: "webhook-service" });
        this.reposRepo     = deps.reposRepo;
        this.developerRepo = deps.developerRepo;
        this.prsRepo       = deps.prsRepo;
        this.commentsRepo  = deps.commentsRepo;
        this.commitsRepo   = deps.commitsRepo;
        this.openPrsService = deps.openPrsService;
        this.cache         = deps.cache;
        this.cachedGithubClient = deps.cachedGithubClient;
        this.org           = deps.env.org;
        this.aiPipelineService = deps.aiPipelineService;
        this.aiChatService = deps.aiChatService;
        this.orgMemberGuard = deps.orgMemberGuard;
    }

    // ─── Pull Request (merged) ──────────────────────────────

    async handlePullRequest(payload: PullRequestPayload): Promise<WebhookHandlerResult> {
        const affectedDevelopers: string[] = [];
        const action = payload.action;
        const pr     = payload.pull_request;
        const repo   = payload.repository;
        const org    = repo.owner?.login ?? this.org;

        // Invalidate open-PRs cache (non-blocking, logged on error)
        this.invalidatePrCache(org);

        // Only process merged PRs
        if (action !== "closed" || !pr.merged) {
            return { affectedDevelopers };
        }

        const repoOwner = repo.owner?.login ?? org;

        // Invalidate AI context cache
        const cacheTreeKey = `ai:repo:${repoOwner}/${repo.name}:tree`;
        const cacheDocsKey = `ai:repo:${repoOwner}/${repo.name}:docs`;
        await Promise.all([
            this.cache.general.del(cacheTreeKey),
            this.cache.general.del(cacheDocsKey),
        ]).catch(err => this.logger.error({ err }, "Failed to bust AI context cache on merge"));

        const author = pr.user?.login;
        if (!author || isBot(author, pr.user?.type)) {
            return { affectedDevelopers };
        }

        // Parallel: upsert repo + upsert developer (independent operations)
        const [repoId] = await Promise.all([
            this.reposRepo.upsertRepo(repo.id, repoOwner, repo.name, { htmlUrl: repo.html_url }),
            this.developerRepo.upsertDeveloper(author, pr.user?.avatar_url, pr.user?.name ?? undefined),
        ]);

        await this.prsRepo.upsertMergedPr({
            id:          pr.id,
            repoId,
            prNumber:    pr.number,
            author,
            title:       pr.title,
            htmlUrl:     pr.html_url,
            mergedAt:    pr.merged_at || pr.closed_at || new Date().toISOString(),
            prCreatedAt: pr.created_at,
            additions:   pr.additions ?? 0,
            deletions:   pr.deletions ?? 0,
        });

        // The PR is now merged! Let's fetch all historical comments it accumulated
        // while it was open efficiently via GraphQL.
        if (this.cachedGithubClient) {
            try {
                const gqlClient = new GitHubGraphQLClient(this.cachedGithubClient.raw as any, this.logger);
                const gqlPr = await gqlClient.fetchSinglePR(repoOwner, repo.name, pr.number);
                
                if (gqlPr) {
                    const commentsToInsert: any[] = [];
                    
                    const addComment = (c: any, type: "issue" | "review") => {
                        const cAuthor = c.author?.login;
                        if (!cAuthor || isBot(cAuthor, c.author?.__typename)) return;
                        commentsToInsert.push({
                            id:          parseInt(c.databaseId.toString(), 10) || parseInt(c.id.toString(), 10),
                            prId:        pr.id,
                            repoId,
                            prNumber:    pr.number,
                            author:      cAuthor,
                            body:        c.body,
                            commentType: type,
                            htmlUrl:     c.url,
                            commentedAt: c.createdAt,
                        });
                    };

                    // Add standard PR comments
                    gqlPr.comments?.nodes?.forEach(c => addComment(c, "issue"));
                    
                    // Add review thread comments
                    gqlPr.reviewThreads?.nodes?.forEach(thread => {
                        thread.comments?.nodes?.forEach(c => addComment(c, "review"));
                    });

                    // Add review summary bodies as comments
                    gqlPr.reviews?.nodes?.forEach(r => {
                        if (r.body?.trim()) {
                            addComment({
                                ...r,
                                databaseId: Math.floor(Math.random() * -1000000), // mock ID for synthetic review bodies
                                url: pr.html_url,
                                createdAt: r.submittedAt,
                            }, "review");
                        }
                    });

                    if (commentsToInsert.length > 0) {
                        await this.commentsRepo.insertCommentBatch(commentsToInsert);
                    }
                }
            } catch (err) {
                this.logger.error({ err }, "Failed to backfill historical comments for newly merged PR via GraphQL");
            }
        }

        affectedDevelopers.push(author);
        return { affectedDevelopers };
    }

    // ─── Comment (issue_comment or review_comment) ──────────

    async handleIssueComment(payload: IssueCommentPayload): Promise<WebhookHandlerResult> {
        const affected = await this.processComment(
            "issue",
            payload.comment,
            payload.issue.number,
            payload.pull_request?.id,
            payload.repository,
            payload.organization?.login,
        );

        const comment = payload.comment;
        const author = comment.user?.login;
        const hasMention = /@sellio/i.test(comment.body);

        if (hasMention && author && !isBot(author, comment.user?.type)) {
            const owner = payload.repository.owner?.login ?? this.org;
            const repo = payload.repository.name;

            const botPromise = (async () => {
                // Security: verify org membership before letting the bot act
                const isMember = await this.orgMemberGuard.isMember(this.org, author);
                if (!isMember) {
                    await this.aiPipelineService.gitOps.commentOnIssue(owner, repo, payload.issue.number,
                        `👋 Hi @${author}! I'm **Sellio Bot** — I only assist members of the **${this.org}** organization. If you believe this is an error, contact the squad admin.`);
                    return;
                }
                // Route to full agentic AI chat service
                await this.aiChatService.chatFromGitHub(
                    owner, repo, author,
                    payload.issue.number,
                    comment.body
                );
            })().catch(err => {
                this.logger.error({ err: err.message }, "Error in issue comment bot mention");
            });

            return { ...affected, botPromise };
        }

        return affected;
    }

    async handleReviewComment(payload: ReviewCommentPayload): Promise<WebhookHandlerResult> {
        const affected = await this.processComment(
            "review",
            payload.comment,
            payload.pull_request.number,
            payload.pull_request.id,
            payload.repository,
            payload.organization?.login,
        );

        const comment = payload.comment;
        const author = comment.user?.login;
        const hasMention = /@sellio/i.test(comment.body);

        if (hasMention && author && !isBot(author, comment.user?.type)) {
            const owner = payload.repository.owner?.login ?? this.org;
            const repo = payload.repository.name;

            const botPromise = (async () => {
                const isMember = await this.orgMemberGuard.isMember(this.org, author);
                if (!isMember) {
                    await this.aiPipelineService.gitOps.commentOnIssue(owner, repo, payload.pull_request.number,
                        `👋 Hi @${author}! I'm **Sellio Bot** — I only assist members of the **${this.org}** organization.`);
                    return;
                }
                const prNumber = payload.pull_request.number;
                const fileContext = comment.path ? `📁 File: \`${comment.path}\`` : "";
                const codeContext = comment.diff_hunk ? `📝 Code context:\n\`\`\`diff\n${comment.diff_hunk}\n\`\`\`` : "";
                const reviewerMessage = comment.body.replace(/@sellio[\-\w]*/gi, "").trim();

                const reviewPrompt = [
                    `@sellio — you've been mentioned in an inline review comment on PR #${prNumber}.`,
                    fileContext,
                    codeContext,
                    `💬 Reviewer's comment: "${reviewerMessage}"`,
                    `\nPlease review this PR fully using the \`review_pr\` tool, then address the reviewer's specific concern about the file above in your response.`
                ].filter(Boolean).join("\n\n");

                await this.aiChatService.chatFromGitHub(
                    owner, repo, author,
                    prNumber,
                    reviewPrompt
                );
            })().catch(err => {
                this.logger.error({ err: err.message }, "Error in review comment bot mention");
            });

            return { ...affected, botPromise };
        }

        return affected;
    }

    private async processComment(
        commentType: "issue" | "review",
        comment: { id: number; body: string; html_url: string; created_at: string; user?: { login: string; type: string; avatar_url: string } },
        prNumber: number,
        prId: number | undefined,
        repo: { id: number; full_name: string; name: string; html_url: string; owner?: { login: string } },
        orgLogin?: string,
    ): Promise<WebhookHandlerResult> {
        const affectedDevelopers: string[] = [];
        const org = orgLogin ?? repo.owner?.login ?? this.org;

        // Invalidate open-PRs cache (non-blocking, logged on error)
        this.invalidatePrCache(org);

        const author = comment.user?.login;
        if (!author || isBot(author, comment.user?.type)) {
            return { affectedDevelopers };
        }

        const repoOwner = repo.owner?.login ?? org;

        // Parallel: upsert repo + upsert developer (independent operations)
        const [repoId] = await Promise.all([
            this.reposRepo.upsertRepo(repo.id, repoOwner, repo.name, { htmlUrl: repo.html_url }),
            this.developerRepo.upsertDeveloper(author, comment.user?.avatar_url),
        ]);

        await this.commentsRepo.insertComment({
            id:          comment.id,
            prId:        prId ?? null as any,
            repoId,
            prNumber,
            author,
            body:        comment.body,
            commentType,
            htmlUrl:     comment.html_url,
            commentedAt: comment.created_at,
        });

        affectedDevelopers.push(author);
        return { affectedDevelopers };
    }

    // ─── Org Membership ─────────────────────────────────────

    async handleOrgMembership(payload: OrgMembershipPayload): Promise<WebhookHandlerResult> {
        const org = payload.organization?.login ?? this.org;
        await this.cache.members.del(`github:org-members:${org}`);
        return { affectedDevelopers: [] };
    }

    // ─── Push (direct commits) ──────────────────────────────

    async handlePush(payload: PushPayload): Promise<WebhookHandlerResult> {
        const affectedDevelopers: string[] = [];
        const repo   = payload.repository;
        const org    = payload.organization?.login ?? repo.owner?.login ?? this.org;
        const sender = payload.sender;

        // Extract branch name from ref (e.g. "refs/heads/development" → "development")
        const branch = payload.ref.replace(/^refs\/heads\//, "");

        // Skip tag pushes
        if (payload.ref.startsWith("refs/tags/")) {
            return { affectedDevelopers };
        }

        // Skip empty pushes (e.g. branch creation with no commits)
        if (!payload.commits || payload.commits.length === 0) {
            return { affectedDevelopers };
        }

        const repoOwner = repo.owner?.login ?? org;

        // Upsert the repo
        const repoId = await this.reposRepo.upsertRepo(repo.id, repoOwner, repo.name, { htmlUrl: repo.html_url });

        // Process each commit
        const commitRows: Array<{
            sha: string; repoId: number; author: string;
            message: string; branch: string; committedAt: string;
            htmlUrl: string; additions: number; deletions: number;
        }> = [];

        for (const commit of payload.commits) {
            // Resolve author: prefer commit.author.username (GitHub login), fall back to sender
            const author = commit.author?.username ?? sender?.login;
            if (!author || isBot(author, sender?.type)) continue;

            // Ensure developer exists
            await this.developerRepo.upsertDeveloper(author, sender?.avatar_url);

            // Count file changes (rough line proxy for display; not scored)
            const filesAdded    = commit.added?.length ?? 0;
            const filesRemoved  = commit.removed?.length ?? 0;
            const filesModified = commit.modified?.length ?? 0;

            commitRows.push({
                sha:         commit.id,
                repoId,
                author,
                message:     commit.message.split("\n")[0].slice(0, 255),
                branch,
                committedAt: commit.timestamp,
                htmlUrl:     commit.url,
                additions:   filesAdded + filesModified,  // approximate
                deletions:   filesRemoved,                // approximate
            });

            if (!affectedDevelopers.includes(author)) {
                affectedDevelopers.push(author);
            }
        }

        if (commitRows.length > 0) {
            const inserted = await this.commitsRepo.insertCommitBatch(commitRows);
            this.logger.info(
                { repo: `${repoOwner}/${repo.name}`, branch, total: commitRows.length, inserted },
                "Push webhook: commits processed",
            );
        }

        return { affectedDevelopers };
    }

    /**
     * Handles Projects v2 item events to catch when a card is moved to the "AI Implement" column.
     */
    async handleProjectItem(
        payload: any,
        aiColumnName: string
    ): Promise<{ affectedDevelopers: string[]; enqueueJob?: any; botPromise?: Promise<any> }> {
        const affectedDevelopers: string[] = [];
        const action = payload.action;
        const item = payload.projects_v2_item;

        if (!item) return { affectedDevelopers };
        
        // Supported actions: 'edited' (when moved), 'converted' (when draft is converted to repository issue), and 'created' (when added directly to column)
        if (action !== "edited" && action !== "converted" && action !== "created") {
            return { affectedDevelopers };
        }

        const isIssue = item.content_type === "Issue";
        const isDraft = item.content_type === "DraftIssue";

        if (!isIssue && !isDraft) {
            return { affectedDevelopers };
        }

        const changes = payload.changes;
        const fieldValue = changes?.field_value;

        // Check if the status column was changed to the AI Implement column name
        const isStatusChange = fieldValue?.field_name?.toLowerCase() === "status";
        const isAIColumn = fieldValue?.field_value_name === aiColumnName || fieldValue?.to?.name === aiColumnName;

        const providedFieldId = fieldValue?.field_id || fieldValue?.field_node_id;

        // Handle Draft Issue conversion
        if (isDraft && (action === "edited" || action === "created")) {
            if (action === "edited" && (!isStatusChange || !isAIColumn)) {
                return { affectedDevelopers };
            }

            const projectId = item.project_node_id;
            const itemId = item.node_id;

            this.logger.info({ projectId, itemId, action }, "Draft issue placed/created in column. Finding repository to convert...");
            
            const conversionPromise = (async () => {
                try {
                    if (!this.cachedGithubClient) {
                        this.logger.error("GitHub client not available to convert draft issue");
                        return;
                    }
                    const octokit = this.cachedGithubClient.raw;
                    
                    // If action is created, verify status via GraphQL first
                    if (action === "created") {
                        const statusRes: any = await octokit.graphql(
                            `query GetItemStatus($itemId: ID!) {
                              node(id: $itemId) {
                                ... on ProjectV2Item {
                                  fieldValueByName(name: "Status") {
                                    ... on ProjectV2ItemFieldSingleSelectValue {
                                      name
                                    }
                                  }
                                }
                              }
                            }`,
                            { itemId }
                        );
                        const currentStatus = statusRes?.node?.fieldValueByName?.name;
                        if (currentStatus !== aiColumnName) {
                            this.logger.info({ currentStatus, aiColumnName }, "Draft issue created but not in AI Implement column. Ignoring.");
                            return;
                        }
                    }

                    // 1. Query project's linked repositories
                    const projectRes: any = await octokit.graphql(
                        `query GetProjectLinkedRepositories($projectId: ID!) {
                          node(id: $projectId) {
                            ... on ProjectV2 {
                              repositories(first: 10) {
                                nodes {
                                  id
                                  name
                                  nameWithOwner
                                }
                              }
                            }
                          }
                        }`,
                        { projectId }
                    );

                    const repos = projectRes?.node?.repositories?.nodes || [];
                    if (repos.length === 0) {
                        this.logger.warn({ projectId }, "No repositories linked to the project. Cannot convert draft issue.");
                        return;
                    }

                    // Sort repositories alphabetically by nameWithOwner
                    const sortedRepos = [...repos].sort((a: any, b: any) =>
                        a.nameWithOwner.toLowerCase().localeCompare(b.nameWithOwner.toLowerCase())
                    );

                    const targetRepo = sortedRepos[0];
                    this.logger.info({ targetRepo: targetRepo.nameWithOwner, totalRepos: repos.length }, "Auto-selected repository for draft conversion");

                    // 2. Perform the conversion mutation
                    const convertRes: any = await octokit.graphql(
                        `mutation ConvertDraftToIssue($itemId: ID!, $repositoryId: ID!) {
                          convertProjectV2DraftIssueItemToIssue(input: {
                            itemId: $itemId,
                            repositoryId: $repositoryId
                          }) {
                            item {
                              id
                              content {
                                ... on Issue {
                                  number
                                  title
                                  body
                                  repository {
                                    name
                                    owner {
                                      login
                                    }
                                  }
                                }
                              }
                            }
                          }
                        }`,
                        { itemId, repositoryId: targetRepo.id }
                    );

                    const convertedItem = convertRes?.convertProjectV2DraftIssueItemToIssue?.item;
                    const convertedIssue = convertedItem?.content;

                    if (convertedIssue) {
                        this.logger.info({ issueNumber: convertedIssue.number, repo: targetRepo.nameWithOwner }, "Draft issue converted successfully");
                        
                        // If multiple repositories were linked, post a comment explaining the choice
                        if (repos.length > 1) {
                            const commentBody = `This draft issue was moved to the **AI Implement** column. Since multiple repositories are linked to this project, I automatically converted it to an issue in the first repository alphabetically: **${targetRepo.nameWithOwner}**.`;
                            await this.aiPipelineService.gitOps.commentOnIssue(
                                convertedIssue.repository.owner.login,
                                convertedIssue.repository.name,
                                convertedIssue.number,
                                commentBody
                            );
                        }
                    } else {
                        this.logger.error({ itemId }, "Failed to parse converted issue from mutation response");
                    }
                } catch (err: any) {
                    this.logger.error({ itemId, err: err.message }, "Error converting draft issue");
                }
            })();

            return { affectedDevelopers, botPromise: conversionPromise };
        }

        // Handle Issue processing
        let shouldTrigger = false;
        if (isIssue) {
            if (action === "edited" && isStatusChange && isAIColumn) {
                shouldTrigger = true;
            } else if (action === "converted") {
                shouldTrigger = true;
            } else if (action === "created") {
                shouldTrigger = true;
            }
        }

        if (shouldTrigger) {
            const issueId = item.content_node_id;
            const projectId = item.project_node_id;
            const itemId = item.node_id;

            this.logger.info({ issueId, projectId, itemId, action }, "AI implement trigger detected. Fetching details via GraphQL...");

            if (this.cachedGithubClient) {
                const octokit = this.cachedGithubClient.raw;
                const result: any = await octokit.graphql(
                    `query GetIssueAndItemDetails($issueId: ID!, $itemId: ID!) {
                      issueNode: node(id: $issueId) {
                        ... on Issue {
                          number
                          title
                          body
                          repository {
                            name
                            owner {
                              login
                            }
                          }
                        }
                      }
                      itemNode: node(id: $itemId) {
                        ... on ProjectV2Item {
                          fieldValueByName(name: "Status") {
                            ... on ProjectV2ItemFieldSingleSelectValue {
                              name
                              field {
                                ... on ProjectV2FieldCommon {
                                  id
                                }
                              }
                            }
                          }
                        }
                      }
                    }`,
                    { issueId, itemId }
                );

                const issue = result?.issueNode;
                const itemNode = result?.itemNode;

                if (issue && issue.repository) {
                    const statusName = itemNode?.fieldValueByName?.name;
                    const fieldId = itemNode?.fieldValueByName?.field?.id || providedFieldId;

                    this.logger.info({ statusName, fieldId, issueNumber: issue.number }, "GraphQL query completed");

                    // For 'converted' or 'created' action, verify if the status is actually the AI column
                    if ((action === "converted" || action === "created") && statusName !== aiColumnName) {
                        this.logger.info({ statusName, action }, "Issue is not in the AI Implement column. Ignoring.");
                        return { affectedDevelopers };
                    }

                    if (!fieldId) {
                        this.logger.error("Could not determine Status field ID from webhook payload or GraphQL query");
                        return { affectedDevelopers };
                    }

                    const owner = issue.repository.owner.login;
                    const repo = issue.repository.name;
                    
                    const enqueueJob = {
                        type: "ai_implement",
                        owner,
                        repo,
                        issueNumber: issue.number,
                        issueTitle: issue.title,
                        issueBody: issue.body,
                        projectId,
                        itemId,
                        fieldId,
                        agentType: "swe-agent",
                        phase: 1,
                        taskId: `${owner}-${repo}-${issue.number}-${Date.now()}`,
                    };

                    return { affectedDevelopers, enqueueJob };
                } else {
                    this.logger.warn({ issueId }, "Issue node or repository not found in GraphQL response");
                }
            } else {
                this.logger.error("GitHub client not available to fetch issue details");
            }
        }

        return { affectedDevelopers };
    }

    // ─── Helpers ─────────────────────────────────────────────

    private invalidatePrCache(org: string): void {
        this.openPrsService.invalidateCache(org).catch((err: any) => {
            this.logger.error({ err: (err as Error).message }, "Failed to invalidate open-PRs cache");
        });
    }
}
