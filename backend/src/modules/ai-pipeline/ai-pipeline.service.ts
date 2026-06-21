/**
 * Sellio Metrics — AI Pipeline Service
 *
 * Orchestrates the phased pipeline for AI ticket implementation:
 *   - Phase 1: Move card to In Progress, assign bot, gather context, generate plan.
 *   - Phase 2: Generate code changes file-by-file, self-validate with LLM, retry once.
 *   - Phase 3: Create branch, commit changes, open PR, comment, queue CI poll.
 *   - Poll CI: Retrieve check-runs periodically. Move card to For Review (if passes) or AI: Failed (if fails).
 */

import type { Logger } from "../../core/logger";
import type { CacheService } from "../../infra/cache/cache.service";
import type { AiProviderClient } from "../../infra/ai/ai-provider.client";
import type { ContextService } from "./context.service";
import type { GitOpsService } from "./git-ops.service";
import type { CodeValidatorService } from "./code-validator.service";
import type { CloudflareQueue } from "../../core/container";
import type { AiImplementJob, RepoContext, ImplementationPlan, CodeChange, AiRunRecord } from "./ai-pipeline.types";
import { AppError } from "../../core/errors";
import { WebSearchService } from "./web-search.service";

export interface CFDurableObjectNamespace {
    idFromName(name: string): { toString(): string };
    get(id: { toString(): string }): { fetch(req: Request): Promise<Response> };
}

export class AiPipelineService {
    private readonly cache: CacheService;
    private readonly ai: AiProviderClient;
    private readonly contextService: ContextService;
    public readonly gitOps: GitOpsService;
    private readonly codeValidator: CodeValidatorService;
    private readonly webSearch: WebSearchService;
    private readonly syncQueue: CloudflareQueue | null;
    private readonly webhookQueue: CloudflareQueue | null;
    private readonly logger: Logger;
    private readonly aiPipelineHub: CFDurableObjectNamespace | null;

    constructor({
        cacheService,
        aiProviderClient,
        contextService,
        gitOpsService,
        codeValidatorService,
        webSearchService,
        syncQueue,
        webhookQueue,
        logger,
        aiPipelineHub,
    }: {
        cacheService: CacheService;
        aiProviderClient: AiProviderClient;
        contextService: ContextService;
        gitOpsService: GitOpsService;
        codeValidatorService: CodeValidatorService;
        webSearchService: WebSearchService;
        syncQueue: CloudflareQueue | null;
        webhookQueue: CloudflareQueue | null;
        logger: Logger;
        aiPipelineHub?: CFDurableObjectNamespace | null;
    }) {
        this.cache = cacheService;
        this.ai = aiProviderClient;
        this.contextService = contextService;
        this.gitOps = gitOpsService;
        this.codeValidator = codeValidatorService;
        this.webSearch = webSearchService;
        this.syncQueue = syncQueue;
        this.webhookQueue = webhookQueue;
        this.logger = logger.child({ module: "ai-pipeline" });
        this.aiPipelineHub = aiPipelineHub ?? null;
    }

    /**
     * Entry point for executing any phase of the AI implement pipeline.
     */
    async execute(job: any): Promise<void> {
        this.logger.info({ taskId: job.taskId, phase: job.phase, type: job.type }, "Executing AI implement job");

        try {
            if (job.type === "ai_implement_poll") {
                await this.executePollCI(job);
                return;
            }

            switch (job.phase) {
                case 1:
                    await this.executePhase1(job);
                    break;
                case 2:
                    await this.executePhase2(job);
                    break;
                case 3:
                    await this.executePhase3(job);
                    break;
                default:
                    throw new AppError(`Unknown phase: ${job.phase}`, 400, "AI_UNKNOWN_PHASE");
            }
        } catch (err: any) {
            this.logger.error({ taskId: job.taskId, error: err.message, stack: err.stack }, "AI Implement pipeline failed");
            await this.handleFailure(job, err.message);
        }
    }

    // ─── Phase 1: Context & Plan ─────────────────────────────

    private async executePhase1(job: AiImplementJob): Promise<void> {
        this.logger.info({ taskId: job.taskId }, "Running Phase 1: Gathering context and planning");

        await this.emitEvent(job, "phase1", "Initializing Task", "Moving project card and assigning bot...", "running");

        // 1. Move card to In Progress column
        await this.gitOps.moveProjectCardByName(job.projectId, job.itemId, job.fieldId, "In Progress");

        // 2. Assign issue to the Sellio bot
        await this.gitOps.assignToBot(job.owner, job.repo, job.issueNumber);

        // 3. Comment on the issue that AI is starting
        await this.gitOps.commentOnIssue(
            job.owner,
            job.repo,
            job.issueNumber,
            `🤖 **Sellio AI Agent** has picked up this ticket!\n- *Phase 1:* Gathering repository context and planning implementation...`
        );

        // 4. Gather 4-layer context (cached where appropriate)
        const context = await this.contextService.gatherContext(
            job.owner,
            job.repo,
            job.issueNumber,
            job.issueTitle,
            job.issueBody
        );

        // Extract and cache images
        const images = await this.extractAndFetchImages(job.issueBody || "");
        if (images.length > 0) {
            await this.cache.set(`ai:task:${job.taskId}:images`, images, 3600);
        }

        // 5. Determine if web search is needed dynamically based on the task
        const searchDecision = await this.determineSearchNeeds(job.issueTitle, job.issueBody);
        let searchContext = "";

        if (searchDecision.needsSearch) {
            await this.gitOps.commentOnIssue(
                job.owner,
                job.repo,
                job.issueNumber,
                `🤖 **Sellio AI Agent**\n- *Phase 1:* Performing web search and package registry checks for the implementation...`
            );
            searchContext = await this.searchPackagesAndDocs(searchDecision.packages, searchDecision.queries, context.fileTree);
        } else {
            this.logger.info({ taskId: job.taskId }, "Skipping web search: Task classified as local and does not need external references.");
        }

        // 6. Generate plan using LLM
        const plan = await this.generatePlan(context, job.issueTitle, job.issueBody, searchContext, images);

        // Comment with plan summary
        await this.gitOps.commentOnIssue(
            job.owner,
            job.repo,
            job.issueNumber,
            `🤖 **Sellio AI Agent** — Plan Generated:\n- **Files to Modify:** ${plan.filesToModify.map(f => `\`${f}\``).join(", ") || "*None*"}\n- **New Files:** ${plan.newFiles.map(f => `\`${f}\``).join(", ") || "*None*"}\n\n*Approach Summary:*\n${plan.summary}`
        );

        await this.emitEvent(job, "phase1", "Initializing Task", "Moving project card and assigning bot...", "done");
        await this.emitEvent(job, "phase1", "Planning Completed", `Generated plan: ${plan.summary}`, "done");

        // 7. Save context, plan, and search context to KV cache (TTL 1 hour)
        await Promise.all([
            this.cache.set(`ai:task:${job.taskId}:context`, context, 3600),
            this.cache.set(`ai:task:${job.taskId}:plan`, plan, 3600),
            this.cache.set(`ai:task:${job.taskId}:search_context`, searchContext, 3600),
        ]);

        // 7. Enqueue Phase 2 in the syncQueue (which has longer budget)
        if (this.syncQueue) {
            await this.syncQueue.send({
                ...job,
                phase: 2,
            });
            this.logger.info({ taskId: job.taskId }, "Phase 1 complete. Enqueued Phase 2");
        } else {
            // Local fallback if no queue
            this.logger.warn("No SYNC_QUEUE bound, executing Phase 2 synchronously");
            await this.executePhase2({ ...job, phase: 2 });
        }
    }

    // ─── Phase 2: Code Gen & Self-Validation ──────────────────

    private async executePhase2(job: AiImplementJob): Promise<void> {
        this.logger.info({ taskId: job.taskId }, "Running Phase 2: Code Generation and Self-Validation");

        await this.emitEvent(job, "phase2", "Generating Code", "Generating code changes file-by-file...", "running");

        // 1. Retrieve plan, context, and images from KV
        const [contextVal, planVal, imagesVal, searchContextVal] = await Promise.all([
            this.cache.get<RepoContext>(`ai:task:${job.taskId}:context`),
            this.cache.get<ImplementationPlan>(`ai:task:${job.taskId}:plan`),
            this.cache.get<{ mimeType: string; data: string }[]>(`ai:task:${job.taskId}:images`),
            this.cache.get<string>(`ai:task:${job.taskId}:search_context`),
        ]);

        if (!contextVal || !planVal) {
            throw new AppError("Context or plan not found in KV cache. Phase 2 aborted.", 400, "AI_CACHE_MISS");
        }

        const context = contextVal.data;
        const plan = planVal.data;
        const images = imagesVal?.data || [];
        const searchContext = searchContextVal?.data || "";

        // Comment on issue that code generation has started
        await this.gitOps.commentOnIssue(
            job.owner,
            job.repo,
            job.issueNumber,
            `🤖 **Sellio AI Agent**\n- *Phase 2:* Generating code modifications and performing self-validation checks...`
        );

        let changes: CodeChange[] = [];
        let validated = false;
        let attempt = 1;
        let feedback = "";

        while (attempt <= 3 && !validated) {
            this.logger.info({ taskId: job.taskId, attempt }, "Code generation attempt");
            changes = [];

            // Generate code for modified files
            for (const filePath of plan.filesToModify) {
                const existingFile = context.relevantFiles.find((f: any) => f.path === filePath);
                const existingContent = existingFile ? existingFile.content : "";
                
                const content = await this.generateCodeForFile(
                    filePath,
                    existingContent,
                    plan,
                    context,
                    searchContext,
                    feedback,
                    images
                );
                changes.push({ path: filePath, content, action: "modify" });
            }

            // Generate code for new files
            for (const filePath of plan.newFiles) {
                const content = await this.generateCodeForFile(
                    filePath,
                    "",
                    plan,
                    context,
                    searchContext,
                    feedback,
                    images
                );
                changes.push({ path: filePath, content, action: "create" });
            }

            // ── Mark code generation as done BEFORE validation starts ──
            // This ensures the UI timeline shows steps in chronological order:
            // "Generating Code" done → then "Validating Code Structure" running → done
            // (Not: "Generating Code" still running while "Validating" shows done)
            await this.emitEvent(job, "phase2", "Generating Code", `Generated ${changes.length} file change(s). Running validation...`, "done");

            // ── STEP 1: Cloudflare-side structural validation (pre-GitHub CI check) ──
            // This runs INSIDE Workers before any code reaches GitHub.
            // Catches real import errors, missing deps, bracket mismatches, etc.
            await this.emitEvent(job, "phase2", "Validating Code Structure", "Running pre-GitHub structural checks (imports, deps, syntax)...", "running");

            const structuralResult = await this.codeValidator.validate(changes, context, plan);

            if (!structuralResult.success) {
                // Build targeted feedback from real errors — not a vague "try again"
                const errorSummary = structuralResult.errors
                    .map(e => `- [${e.type}] ${e.file}${e.line ? ` (line ${e.line})` : ""}: ${e.message}`)
                    .join("\n");

                feedback = `Your previous attempt failed STRUCTURAL VALIDATION with the following specific errors:\n${errorSummary}\n\nPlease fix EXACTLY these issues. Focus on:\n- Ensuring all imports point to files that actually exist\n- Fixing any bracket/brace mismatches\n- Adding any missing package dependencies you reference`;

                this.logger.warn({ taskId: job.taskId, attempt, errors: structuralResult.errors.length }, "Structural validation failed, regenerating");
                // Reset events for next attempt so the user sees a clean retry in the timeline
                await this.emitEvent(job, "phase2", "Validating Code Structure", `Attempt ${attempt} failed — retrying code generation...`, "running");
                await this.emitEvent(job, "phase2", "Generating Code", `Attempt ${attempt} failed. Regenerating with targeted feedback...`, "running");
                attempt++;
                continue;
            }

            await this.emitEvent(job, "phase2", "Validating Code Structure", structuralResult.summary, "done");

            // ── STEP 2: LLM semantic validation (logic, types, architecture) ──
            // Only runs after structural checks pass — avoids wasting tokens on broken code.
            const semanticResult = await this.selfValidateChanges(changes, context);
            if (semanticResult.success) {
                validated = true;
                this.logger.info({ taskId: job.taskId, attempt }, "All validation checks passed");
            } else {
                const semanticErrors = semanticResult.errors.join("\n");
                feedback = `Your previous attempt failed SEMANTIC VALIDATION with logic/type errors:\n${semanticErrors}\nPlease fix these architectural and type-level issues.`;
                this.logger.warn({ taskId: job.taskId, attempt, errors: semanticResult.errors }, "Semantic validation failed, retrying");
                // Reset events for the retry so the UI timeline reflects the re-attempt
                await this.emitEvent(job, "phase2", "Validating Code Structure", `Semantic check failed on attempt ${attempt} — retrying...`, "running");
                await this.emitEvent(job, "phase2", "Generating Code", `Attempt ${attempt} failed semantic check. Regenerating...`, "running");
                attempt++;
            }
        }

        if (!validated) {
            throw new AppError(`LLM self-validation failed after retries: ${feedback}`, 422, "AI_VALIDATION_FAILED");
        }

        await this.emitEvent(job, "phase2", "Code Validation Passed", "All validation checks passed successfully.", "done");

        // Save generated changes to KV
        await this.cache.set(`ai:task:${job.taskId}:code`, changes, 3600);

        // Enqueue Phase 3
        if (this.syncQueue) {
            // Using syncQueue for safety since polling is in Phase 3
            await this.syncQueue.send({
                ...job,
                phase: 3,
            });
            this.logger.info({ taskId: job.taskId }, "Phase 2 complete. Enqueued Phase 3");
        } else {
            this.logger.warn("No SYNC_QUEUE bound, executing Phase 3 synchronously");
            await this.executePhase3({ ...job, phase: 3 });
        }
    }

    // ─── Phase 3: Ship & Monitor ─────────────────────────────

    private async executePhase3(job: AiImplementJob): Promise<void> {
        this.logger.info({ taskId: job.taskId }, "Running Phase 3: Commit and Pull Request");

        const slug = job.issueTitle
            .toLowerCase()
            .replace(/[^a-z0-9]+/g, "-")
            .replace(/(^-|-$)/g, "")
            .slice(0, 40);
        const branchName = `ai/${job.issueNumber}-${slug}`;

        await this.emitEvent(job, "phase3", "Shipping Changes", "Creating branch and committing files...", "running", { branchName });

        // 1. Retrieve generated changes from KV
        const codeVal = await this.cache.get<CodeChange[]>(`ai:task:${job.taskId}:code`);
        if (!codeVal) {
            throw new AppError("Generated code changes not found in KV cache. Phase 3 aborted.", 400, "AI_CACHE_MISS");
        }

        const changes = codeVal.data;

        // 2. Perform git ops
        const { branch: defaultBranch, sha: baseSha } = await this.gitOps.getDefaultBranchHead(job.owner, job.repo);

        // Create branch
        await this.gitOps.createBranch(job.owner, job.repo, baseSha, branchName);

        // Commit files
        const commitMessage = `auto(ai): implement ticket #${job.issueNumber}\n\nGenerated by Sellio Metrics AI Agent.`;
        const commitSha = await this.gitOps.commitFiles(
            job.owner,
            job.repo,
            branchName,
            baseSha,
            changes,
            commitMessage
        );

        // Open PR
        const prTitle = `auto(ai): ${job.issueTitle}`;
        const prBody = `## 🤖 AI Implementation for #${job.issueNumber}

This Pull Request was automatically generated by the Sellio Metrics AI Agent.

Fixes #${job.issueNumber}

### Changes Implemented:
${changes.map((c: CodeChange) => `- **${c.action === "create" ? "[NEW]" : "[MOD]"}** \`${c.path}\``).join("\n")}

Please review the changes and run the build tests.`;

        const pr = await this.gitOps.createPR(job.owner, job.repo, {
            title: prTitle,
            body: prBody,
            head: branchName,
            base: defaultBranch,
        });

        const prUrl = `https://github.com/${job.owner}/${job.repo}/pull/${pr.number}`;

        // Comment on issue that PR is opened
        const fileList = changes.map((c: CodeChange) => `- \`${c.path}\` (${c.action})`).join("\n");
        await this.gitOps.commentOnIssue(
            job.owner,
            job.repo,
            job.issueNumber,
            `🤖 **Sellio AI Agent** — Phase 3 PR Opened!\n- **PR:** [PR #${pr.number}](${prUrl})\n- **Files Changed:**\n${fileList}\n\nMonitoring CI status (polling Checks API for up to 5 minutes)...`
        );

        await this.emitEvent(job, "phase3", "Shipping Changes", "Creating branch and committing files...", "done", { branchName });
        await this.emitEvent(job, "phase3", "PR Opened", `PR #${pr.number} opened successfully.`, "done", {
            prNumber: pr.number,
            prUrl,
            branchName
        });

        // Enqueue CI polling
        if (this.syncQueue) {
            await this.syncQueue.send({
                type: "ai_implement_poll",
                owner: job.owner,
                repo: job.repo,
                issueNumber: job.issueNumber,
                issueTitle: job.issueTitle,
                prNumber: pr.number,
                prHeadSha: commitSha,
                projectId: job.projectId,
                itemId: job.itemId,
                fieldId: job.fieldId,
                pollAttempt: 1,
                taskId: job.taskId,
            }, { delaySeconds: 30 }); // Start polling in 30 seconds
            this.logger.info({ taskId: job.taskId }, "PR opened. Enqueued CI status polling");
        } else {
            this.logger.warn("No SYNC_QUEUE bound to poll CI. Moving card to For Review");
            await this.gitOps.moveProjectCardByName(job.projectId, job.itemId, job.fieldId, "For Review");
            await this.cleanupTask(job.taskId);
        }
    }

    // ─── CI Status Polling ───────────────────────────────────

    private async executePollCI(job: {
        type: "ai_implement_poll";
        owner: string;
        repo: string;
        issueNumber: number;
        prNumber: number;
        prHeadSha: string;
        projectId: string;
        itemId: string;
        fieldId: string;
        pollAttempt: number;
        taskId: string;
        issueTitle?: string;
        retryCount?: number;
    }): Promise<void> {
        this.logger.info({ prNumber: job.prNumber, attempt: job.pollAttempt, retryCount: job.retryCount }, "Polling CI status");

        const prUrl = `https://github.com/${job.owner}/${job.repo}/pull/${job.prNumber}`;
        const issueTitle = job.issueTitle || `Issue #${job.issueNumber}`;
        
        await this.emitEvent(
            { ...job, issueTitle },
            "ci_poll",
            "Polling CI Status",
            `Attempt ${job.pollAttempt}: checking check-runs for SHA: ${job.prHeadSha.slice(0, 7)}...`,
            "running",
            { prNumber: job.prNumber, prUrl }
        );

        let checks: any;

        try {
            checks = await this.gitOps.listCheckRuns(job.owner, job.repo, job.prHeadSha);
        } catch (err: any) {
            this.logger.warn({ error: err.message }, "Failed to fetch check runs, retrying");
            // Re-enqueue
            await this.requeueCI(job);
            return;
        }

        const checkRuns = checks.data?.check_runs || [];
        const totalRuns = checkRuns.length;

        if (totalRuns === 0) {
            this.logger.info("No check runs registered yet");
            await this.requeueCI(job);
            return;
        }

        const pending = checkRuns.some((run: any) => run.status !== "completed");
        
        if (pending) {
            this.logger.info("CI check runs are still pending/in progress");
            await this.requeueCI(job);
            return;
        }

        // All completed! Check conclusions
        const failedRun = checkRuns.find(
            (run: any) => run.conclusion && ["failure", "cancelled", "timed_out", "action_required"].includes(run.conclusion)
        );

        if (failedRun) {
            // Build failed!
            const logsUrl = failedRun.html_url || "";
            const currentRetryCount = job.retryCount || 0;
            const newRetryCount = currentRetryCount + 1;

            if (newRetryCount <= 5) {
                await this.emitEvent(
                    { ...job, issueTitle },
                    "ci_poll",
                    `CI Failed (Retry ${newRetryCount}/5)`,
                    `CI build failed. Fetching logs and self-correcting...`,
                    "running",
                    { prNumber: job.prNumber, prUrl }
                );

                try {
                    // 1. Fetch branch name from PR
                    const octokit = this.gitOps["github"].raw;
                    const { data: prInfo } = await octokit.pulls.get({
                        owner: job.owner,
                        repo: job.repo,
                        pull_number: job.prNumber
                    });
                    const branchName = prInfo.head.ref;
                    
                    // 2. List workflow runs to download failed log
                    const runs = await this.gitOps.listWorkflowRunsForBranch(job.owner, job.repo, branchName);
                    const matchingRun = runs.find(run => run.head_sha === job.prHeadSha);
                    const runId = matchingRun ? matchingRun.id : (runs[0] ? runs[0].id : null);
                    
                    let logs = "";
                    if (runId) {
                        logs = await this.gitOps.getWorkflowJobLogs(job.owner, job.repo, runId);
                    } else {
                        logs = "Could not locate workflow run ID for commit SHA " + job.prHeadSha;
                    }
                    
                    // 3. Classify failure (infra vs code)
                    const failureClass = await this.classifyFailure(logs);
                    this.logger.info({ taskId: job.taskId, failureClass }, "Classified CI failure");
                    
                    if (failureClass === "infra") {
                        await this.emitEvent(
                            { ...job, issueTitle },
                            "failed",
                            "CI Failed (Infra Error)",
                            "Failed due to Infrastructure/Env error. No self-correction.",
                            "failed"
                        );
                        await this.gitOps.commentOnIssue(
                            job.owner,
                            job.repo,
                            job.issueNumber,
                            `❌ **CI build failed due to an infrastructure/environment issue** (e.g., runner, secrets, network, dependencies setup).\nSince this is not a code error, I cannot resolve it automatically. Stopping self-correction.\n- Move card to **AI: Failed**.\n- Check [CI Logs](${logsUrl}) for details.`
                        );
                        await this.gitOps.moveProjectCardByName(job.projectId, job.itemId, job.fieldId, "AI: Failed");
                        await this.cleanupTask(job.taskId);
                        return;
                    }
                    
                    // Code/Test error - perform self-correction
                    await this.gitOps.commentOnIssue(
                        job.owner,
                        job.repo,
                        job.issueNumber,
                        `🔄 **CI build failed with a code/test error** (Attempt ${newRetryCount}/5).\nLogs analyzed. Self-correcting the code modifications and pushing a new fix commit...\n- [Check Failed Run Logs](${logsUrl})`
                    );
                    
                    // Load plan, context and images
                    const [contextVal, planVal, imagesVal] = await Promise.all([
                        this.cache.get<RepoContext>(`ai:task:${job.taskId}:context`),
                        this.cache.get<ImplementationPlan>(`ai:task:${job.taskId}:plan`),
                        this.cache.get<{ mimeType: string; data: string }[]>(`ai:task:${job.taskId}:images`),
                    ]);
                    
                    const context = contextVal?.data;
                    const plan = planVal?.data;
                    const images = imagesVal?.data || [];
                    
                    if (!context || !plan) {
                        throw new Error("Context or plan not found in KV cache during self-correction.");
                    }

                    // Dynamically determine if the CI error logs need a web search
                    const errorSearchDecision = await this.determineSearchNeeds(
                        `Resolve CI Error for: ${job.issueTitle || issueTitle}`,
                        `The build failed with the following logs. Find compatible package versions or solutions to this conflict:\n\n${logs.substring(0, 1500)}`
                    );
                    let errorSearchContext = "";
                    if (errorSearchDecision.needsSearch) {
                        this.logger.info({ taskId: job.taskId }, "CI error requires web search for solutions");
                        errorSearchContext = await this.searchPackagesAndDocs(
                            errorSearchDecision.packages,
                            errorSearchDecision.queries,
                            context.fileTree
                        );
                    }
                    
                    // Ask LLM to generate patched/fixed code changes
                    const systemPrompt = `You are a principal engineer. A pull request was generated but failed the CI checks.
Your task is to analyze the failure logs and correct the code modifications.
Generate the corrected contents for the files. Return ONLY the files that need to be updated.

You MUST respond with a valid JSON object matching this schema:
{
  "files": [
    {
      "path": "path/to/file",
      "content": "Full corrected content of the file",
      "action": "modify" | "create" | "delete"
    }
  ]
}`;
                    let userPrompt = `Issue Title: ${job.issueTitle || issueTitle}
Issue Body: ${context.recentPrs[0]?.body || ""}

Failed CI Logs:
${logs}

Original Implementation Plan:
Summary: ${plan.summary}
Approach: ${plan.approach}

Files Modified originally: ${plan.filesToModify.join(", ")}
New Files originally: ${plan.newFiles.join(", ")}
`;

                    if (errorSearchContext) {
                        userPrompt += `\n\nWeb Search & Dependency Resolution Context:\n${errorSearchContext}\n`;
                    }
                    const response = await this.ai.generateCompletion({
                        systemPrompt,
                        userPrompt,
                        jsonMode: true,
                        images
                    }, "premium"); // Self-correction requires premium LLM to generate accurate code fixes
                    
                    const parsed = JSON.parse(response);
                    const fixedFiles: CodeChange[] = parsed.files || [];
                    
                    if (fixedFiles.length === 0) {
                        throw new Error("LLM did not generate any code changes for the fix.");
                    }
                    
                    // Push fix commit to the same branch
                    const ref = await octokit.git.getRef({
                        owner: job.owner,
                        repo: job.repo,
                        ref: `heads/${branchName}`
                    });
                    const branchHeadSha = ref.data.object.sha;
                    
                    this.logger.info({ branchName, branchHeadSha }, "Pushing self-correction commit to branch");
                    const newCommitSha = await this.gitOps.commitFiles(
                        job.owner,
                        job.repo,
                        branchName,
                        branchHeadSha,
                        fixedFiles,
                        `Fix CI check failures - Retry #${newRetryCount}`
                    );
                    
                    // Requeue CI polling job with pollAttempt: 1, prHeadSha: newCommitSha, retryCount: newRetryCount
                    if (this.syncQueue) {
                        await this.syncQueue.send({
                            ...job,
                            pollAttempt: 1,
                            prHeadSha: newCommitSha,
                            retryCount: newRetryCount
                        }, { delaySeconds: 30 });
                        
                        this.logger.info({ taskId: job.taskId, newCommitSha }, "Enqueued new CI status polling after self-correction");
                    } else {
                        await this.executePollCI({
                            ...job,
                            pollAttempt: 1,
                            prHeadSha: newCommitSha,
                            retryCount: newRetryCount
                        });
                    }
                } catch (corrErr: any) {
                    this.logger.error({ taskId: job.taskId, error: corrErr.message }, "Self-correction failed, halting");
                    await this.gitOps.commentOnIssue(
                        job.owner,
                        job.repo,
                        job.issueNumber,
                        `❌ **Self-correction failed** during execution: ${corrErr.message}. Moving card to **AI: Failed**.`
                    );
                    await this.gitOps.moveProjectCardByName(job.projectId, job.itemId, job.fieldId, "AI: Failed");
                    await this.cleanupTask(job.taskId);
                }
            } else {
                await this.emitEvent(
                    { ...job, issueTitle },
                    "ci_poll",
                    "CI Failed (Max Retries)",
                    "CI build failed and retry limit reached.",
                    "failed"
                );
                await this.gitOps.commentOnIssue(
                    job.owner,
                    job.repo,
                    job.issueNumber,
                    `❌ **CI build failed** after 5 attempts at self-correction. Moving card to **AI: Failed**.\n- Check [CI Logs](${logsUrl}) for details.`
                );
                await this.gitOps.moveProjectCardByName(job.projectId, job.itemId, job.fieldId, "AI: Failed");
                await this.cleanupTask(job.taskId);
            }
        } else {
            // Build passed!
            await this.emitEvent(
                { ...job, issueTitle },
                "ci_poll",
                "CI Passed",
                "All check-runs passed successfully.",
                "done"
            );
            await this.gitOps.commentOnIssue(
                job.owner,
                job.repo,
                job.issueNumber,
                `✅ **Build passed** successfully on CI!\n- PR #${job.prNumber} is ready for human review.\n- Moving card to **For Review**.`
            );
            await this.gitOps.moveProjectCardByName(job.projectId, job.itemId, job.fieldId, "For Review");
            await this.cleanupTask(job.taskId);
        }
    }

    private async requeueCI(job: any): Promise<void> {
        const issueTitle = job.issueTitle || `Issue #${job.issueNumber}`;
        if (job.pollAttempt >= 10) {
            // Timed out (5 minutes)
            await this.emitEvent(
                { ...job, issueTitle },
                "ci_poll",
                "CI Polling Timeout",
                "CI check-runs timed out after 5 minutes.",
                "failed"
            );
            await this.gitOps.commentOnIssue(
                job.owner,
                job.repo,
                job.issueNumber,
                `⏳ CI check-runs are still running after 5 minutes.\n- PR #${job.prNumber} status needs to be checked manually.\n- Moving card to **For Review** as fallback.`
            );
            await this.gitOps.moveProjectCardByName(job.projectId, job.itemId, job.fieldId, "For Review");
            await this.cleanupTask(job.taskId);
            return;
        }

        if (this.syncQueue) {
            await this.syncQueue.send({
                ...job,
                pollAttempt: job.pollAttempt + 1,
            }, { delaySeconds: 30 });
        }
    }

    // ─── Helpers & LLM Calls ──────────────────────────────────

    private async generatePlan(
        context: RepoContext,
        title: string,
        body: string | null,
        searchContext: string,
        images?: { mimeType: string; data: string }[]
    ): Promise<ImplementationPlan> {
        const systemPrompt = `You are a senior principal developer. Given a repository's context (file tree, docs, dependencies, recent PRs) and a ticket, create a complete implementation plan.
Analyze the issue and list:
1. A summary of the approach
2. Detailed architectural steps
3. The files that need to be modified (must exist in the repository file tree)
4. The files that need to be created (new files)

You MUST respond with a valid JSON object ONLY. Do not include markdown codeblocks or extra text.
JSON Schema:
{
  "summary": "brief summary",
  "approach": "detailed steps",
  "filesToModify": ["path/to/file1.ts"],
  "newFiles": ["path/to/newfile.ts"]
}`;

        let userPrompt = `Issue:
Title: ${title}
Description:
${body ?? "No description provided"}

Repository Files:
${context.fileTree.join("\n")}

Architecture & Config Files:
${context.architectureDocs.map(d => `--- File: ${d.path} ---\n${d.content}`).join("\n\n")}

Dependencies:
${JSON.stringify(context.dependencies, null, 2)}
`;

        if (searchContext) {
            userPrompt += `\n\nWeb Search & Package Registry Info:\n${searchContext}\n`;
        }

        const raw = await this.ai.generateCompletion({
            systemPrompt,
            userPrompt,
            jsonMode: true,
            images,
        }, "premium"); // Planning requires premium LLM for high-quality implementation plans

        // Defensive coercion: some provider edge cases return non-string (e.g. Workers AI thinking models)
        const rawStr = typeof raw === "string" ? raw : JSON.stringify(raw ?? "");
        const cleaned = rawStr.trim().replace(/^```json/, "").replace(/```$/, "").trim();
        return JSON.parse(cleaned) as ImplementationPlan;
    }

    private async generateCodeForFile(
        filePath: string,
        existingContent: string,
        plan: ImplementationPlan,
        context: RepoContext,
        searchContext: string,
        feedback: string,
        images?: { mimeType: string; data: string }[]
    ): Promise<string> {
        const systemPrompt = `You are a world-class principal developer. You write clean, production-grade, well-tested code that adheres to the styles of the existing codebase.
Given:
- The implementation plan
- The repository context (structure, dependencies, file tree)
- The file we are currently working on: ${filePath}
- The existing file content (if modifying)

Write the complete code for ${filePath}.
Adhere to the styles of other files in the repository.
Respond with the code ONLY. Do not include markdown codeblocks, explanations, or comments unless they are part of the source code.`;

        let userPrompt = `Target File: ${filePath}
${existingContent ? `Existing Content:\n\`\`\`\n${existingContent}\n\`\`\`\n` : "This is a NEW file.\n"}

Implementation Plan:
Summary: ${plan.summary}
Approach: ${plan.approach}

Modified Files List: ${plan.filesToModify.join(", ")}
New Files List: ${plan.newFiles.join(", ")}

Repository Structure:
${context.fileTree.join("\n")}
`;

        if (searchContext) {
            userPrompt += `\n\nWeb Search & Package Registry Info:\n${searchContext}\n`;
        }

        if (feedback) {
            userPrompt += `\n\nValidation Feedback:\n${feedback}`;
        }

        const raw = await this.ai.generateCompletion({
            systemPrompt,
            userPrompt,
            jsonMode: false,
            images,
        }, "premium"); // Code generation requires premium LLM for accurate, production-grade code

        return this.cleanCodeContent(raw);
    }

    private async selfValidateChanges(changes: CodeChange[], context: RepoContext): Promise<{ success: boolean; errors: string[] }> {
        const systemPrompt = `You are a static code analyzer and compiler. Review the proposed changes to the files in the repository and check for:
1. Syntax errors
2. Missing imports / broken references
3. Type mismatches
4. Logic bugs

Respond with a JSON object ONLY:
{
  "success": true, 
  "errors": [] 
}
If success is false, list clear descriptions of all errors in the "errors" array.`;

        const userPrompt = `Proposed Changes:
${changes.map(c => `--- File: ${c.path} (${c.action}) ---\n${c.content}`).join("\n\n")}

File Tree Context:
${context.fileTree.join("\n")}
`;

        const raw = await this.ai.generateCompletion({
            systemPrompt,
            userPrompt,
            jsonMode: true,
        }, "fast"); // Semantic validation is a structured JSON check — fast tier (Workers AI) is sufficient

        // Defensive coercion: guard against non-string returns from Workers AI edge cases
        const rawStr = typeof raw === "string" ? raw : JSON.stringify(raw ?? "{}");
        const cleaned = rawStr.trim().replace(/^```json/, "").replace(/```$/, "").trim();
        return JSON.parse(cleaned);
    }

    private cleanCodeContent(raw: string): string {
        // Defensive coercion: guard against non-string returns from AI providers (e.g. Workers AI thinking models)
        if (typeof raw !== "string") {
            this.logger.warn({ rawType: typeof raw }, "generateCodeForFile: AI returned non-string, coercing to string");
            raw = typeof raw === "object" && raw !== null ? JSON.stringify(raw) : String(raw ?? "");
        }
        let cleaned = raw.trim();
        if (cleaned.startsWith("```")) {
            const firstNewline = cleaned.indexOf("\n");
            if (firstNewline !== -1) {
                cleaned = cleaned.substring(firstNewline + 1);
            }
            if (cleaned.endsWith("```")) {
                cleaned = cleaned.substring(0, cleaned.length - 3);
            }
        }
        return cleaned.trim();
    }

    private async handleFailure(job: any, errorMessage: string): Promise<void> {
        try {
            const issueTitle = job.issueTitle || `Issue #${job.issueNumber}`;
            await this.emitEvent({ ...job, issueTitle }, "failed", "Execution Failed", errorMessage, "failed");
            await this.gitOps.commentOnIssue(
                job.owner,
                job.repo,
                job.issueNumber,
                `❌ **AI implementation failed** during processing.\n- **Error:** ${errorMessage}\n- Moving card to **AI: Failed**.`
            );
            await this.gitOps.moveProjectCardByName(job.projectId, job.itemId, job.fieldId, "AI: Failed");
            await this.cleanupTask(job.taskId);
        } catch (e: any) {
            this.logger.error({ error: e.message }, "Failed to handle AI task failure");
        }
    }

    private async cleanupTask(taskId: string): Promise<void> {
        this.logger.info({ taskId }, "Cleaning up task data from KV");
        await Promise.all([
            this.cache.del(`ai:task:${taskId}:context`),
            this.cache.del(`ai:task:${taskId}:plan`),
            this.cache.del(`ai:task:${taskId}:code`),
        ]);
    }

    private async emitEvent(
        job: { taskId: string; owner: string; repo: string; issueNumber: number; issueTitle: string },
        phase: "phase1" | "phase2" | "phase3" | "ci_poll" | "failed",
        label: string,
        detail?: string,
        status: "running" | "done" | "failed" = "running",
        extra?: { prNumber?: number; prUrl?: string; branchName?: string }
    ): Promise<void> {
        try {
            const taskId = job.taskId;
            this.logger.info({ taskId, phase, label, status }, "Emitting pipeline trace event");

            const recordKey = `ai:runs:${taskId}`;
            const existingVal = await this.cache.get<AiRunRecord>(recordKey);
            
            let record: AiRunRecord;
            const nowStr = new Date().toISOString();

            if (existingVal && existingVal.data) {
                record = existingVal.data;
                record.updatedAt = nowStr;
                
                const existingEventIndex = record.events.findIndex(e => e.phase === phase && e.label === label);
                if (existingEventIndex !== -1) {
                    record.events[existingEventIndex].status = status;
                    record.events[existingEventIndex].timestamp = nowStr;
                    if (detail !== undefined) {
                        record.events[existingEventIndex].detail = detail;
                    }
                } else {
                    record.events.push({
                        phase,
                        label,
                        detail,
                        timestamp: nowStr,
                        status
                    });
                }

                if (status === "failed") {
                    record.status = "failed";
                    // Mark all running events as failed to avoid infinite spinners
                    for (const ev of record.events) {
                        if (ev.status === "running") {
                            ev.status = "failed";
                        }
                    }
                } else if (phase === "ci_poll" && status === "done") {
                    record.status = "completed";
                } else if (phase === "ci_poll" && status === "running") {
                    record.status = "ci_polling";
                } else {
                    record.status = "in_progress";
                }
            } else {
                const issueUrl = `https://github.com/${job.owner}/${job.repo}/issues/${job.issueNumber}`;
                record = {
                    taskId,
                    owner: job.owner,
                    repo: job.repo,
                    issueNumber: job.issueNumber,
                    issueTitle: job.issueTitle,
                    issueUrl,
                    status: status === "failed" ? "failed" : "in_progress",
                    startedAt: nowStr,
                    updatedAt: nowStr,
                    events: [{
                        phase,
                        label,
                        detail,
                        timestamp: nowStr,
                        status
                    }]
                };

                await this.updateRunsIndex(taskId);
            }

            if (extra) {
                if (extra.prNumber !== undefined) record.prNumber = extra.prNumber;
                if (extra.prUrl !== undefined) record.prUrl = extra.prUrl;
                if (extra.branchName !== undefined) record.branchName = extra.branchName;
            }

            await this.cache.set(recordKey, record, 7 * 24 * 3600);

            if (this.aiPipelineHub) {
                try {
                    const doId = this.aiPipelineHub.idFromName("global");
                    const doStub = this.aiPipelineHub.get(doId);
                    
                    const req = new Request("https://ai-pipeline-hub/event", {
                        method: "POST",
                        headers: { "Content-Type": "application/json" },
                        body: JSON.stringify(record)
                    });
                    const res = await doStub.fetch(req);
                    if (!res.ok) {
                        this.logger.warn({ status: res.status }, "Durable Object returned non-OK status for /event");
                    }
                } catch (doErr: any) {
                    this.logger.error({ err: doErr?.message }, "Failed to POST event to Durable Object stub");
                }
            }
        } catch (err: any) {
            this.logger.error({ err: err?.message }, "Failed to emit event");
        }
    }

    private async updateRunsIndex(newTaskId: string): Promise<void> {
        try {
            const indexKey = "ai:runs:index";
            const indexVal = await this.cache.get<string[]>(indexKey);
            let taskIds: string[] = [];
            if (indexVal && indexVal.data) {
                taskIds = indexVal.data;
            }
            
            if (!taskIds.includes(newTaskId)) {
                taskIds.unshift(newTaskId);
                if (taskIds.length > 50) {
                    taskIds = taskIds.slice(0, 50);
                }
                await this.cache.set(indexKey, taskIds);
            }
        } catch (err: any) {
            this.logger.error({ err: err?.message }, "Failed to update runs index in KV");
        }
    }

    async deleteRun(taskId: string): Promise<void> {
        try {
            const indexKey = "ai:runs:index";
            const indexVal = await this.cache.get<string[]>(indexKey);
            if (indexVal && indexVal.data) {
                const taskIds = indexVal.data.filter(id => id !== taskId);
                await this.cache.set(indexKey, taskIds);
            }
            await this.cache.del(`ai:runs:${taskId}`);
            await Promise.all([
                this.cache.del(`ai:task:${taskId}:context`),
                this.cache.del(`ai:task:${taskId}:plan`),
                this.cache.del(`ai:task:${taskId}:code`),
                this.cache.del(`ai:task:${taskId}:images`),
            ]);
            this.logger.info({ taskId }, "Deleted run from KV and index");
        } catch (err: any) {
            this.logger.error({ taskId, err: err?.message }, "Failed to delete run");
            throw err;
        }
    }

    async deleteAllRuns(): Promise<void> {
        try {
            const indexKey = "ai:runs:index";
            const indexVal = await this.cache.get<string[]>(indexKey);
            if (indexVal && indexVal.data) {
                const taskIds = indexVal.data;
                await Promise.all(
                    taskIds.map(async (taskId) => {
                        await this.cache.del(`ai:runs:${taskId}`);
                        await Promise.all([
                            this.cache.del(`ai:task:${taskId}:context`),
                            this.cache.del(`ai:task:${taskId}:plan`),
                            this.cache.del(`ai:task:${taskId}:code`),
                            this.cache.del(`ai:task:${taskId}:images`),
                        ]);
                    })
                );
            }
            await this.cache.set(indexKey, []);
            this.logger.info("Cleared all run history from KV");
        } catch (err: any) {
            this.logger.error({ err: err?.message }, "Failed to clear all runs");
            throw err;
        }
    }

    async handleCommentMention(
        owner: string,
        repo: string,
        issueNumber: number,
        commentId: number,
        commentBody: string,
        author: string
    ): Promise<void> {
        this.logger.info({ owner, repo, issueNumber, commentId }, "Handling bot mention in issue comment");
        
        try {
            const octokit = this.gitOps["github"].raw;
            
            // 1. Fetch issue details
            const { data: issue } = await octokit.issues.get({
                owner,
                repo,
                issue_number: issueNumber
            });
            
            // 2. Fetch last 20 comments
            const { data: comments } = await octokit.issues.listComments({
                owner,
                repo,
                issue_number: issueNumber,
                per_page: 20
            });
            
            // Build conversation history
            let conversationText = `Issue Title: ${issue.title}\nIssue Body:\n${issue.body || ""}\n\n`;
            conversationText += "Conversation History:\n";
            for (const c of comments) {
                conversationText += `- **${c.user?.login || "anonymous"}**: ${c.body}\n`;
            }
            
            // 3. Extract and fetch images from issue body and comments
            const allText = (issue.body || "") + "\n" + comments.map(c => c.body || "").join("\n");
            const images = await this.extractAndFetchImages(allText);
            
            // 4. Call LLM to respond to the mention
            const systemPrompt = `You are Sellio Bot, an advanced AI Coding Assistant built by the engineering team.
You are helping the developers solve issues in the repository.
Analyze the issue details, the conversation history, and any attached images (screenshots) to answer the user's questions or address their request.
Keep your response professional, friendly, clear, and focused on helping the developers.`;
            
            const response = await this.ai.generateCompletion({
                systemPrompt,
                userPrompt: conversationText,
                images
            }, "fast"); // Bot reply is conversational — Workers AI / Groq handles it for free
            
            // 5. Post comment
            await this.gitOps.commentOnIssue(owner, repo, issueNumber, response);
        } catch (err: any) {
            this.logger.error({ issueNumber, error: err.message }, "Failed to handle comment mention");
        }
    }

    async handleReviewComment(
        owner: string,
        repo: string,
        pullNumber: number,
        commentId: number,
        commentBody: string,
        author: string,
        path: string,
        line: number | null,
        diffHunk: string
    ): Promise<void> {
        this.logger.info({ owner, repo, pullNumber, commentId, path, line }, "Handling review comment mention");
        
        try {
            const systemPrompt = `You are Sellio Bot, an advanced AI Coding Assistant.
You have been mentioned in a code review comment on a pull request.
Analyze the comment, the file path, the line number, and the surrounding diff hunk to address the user's question or request.

If the user wants a code fix or correction, you can output a code suggestion using a markdown suggestion block:
\`\`\`suggestion
corrected lines of code
\`\`\`
Keep your answer clear, helpful, and concise.`;

            const userPrompt = `File Path: ${path}
Line: ${line || "unknown"}
Diff Hunk:
\`\`\`diff
${diffHunk}
\`\`\`

User Comment by @${author}:
${commentBody}
`;
            const response = await this.ai.generateCompletion({
                systemPrompt,
                userPrompt
            }, "fast"); // Code review reply is conversational — Workers AI handles it for free
            
            // Reply in the same thread
            await this.gitOps.replyToReviewComment(owner, repo, pullNumber, commentId, response);
        } catch (err: any) {
            this.logger.error({ commentId, error: err.message }, "Failed to handle review comment mention");
        }
    }

    /**
     * Dynamically determines if the ticket requires web searches and returns the package list and queries.
     */
    private async determineSearchNeeds(title: string, body: string | null): Promise<{ needsSearch: boolean; packages: string[]; queries: string[] }> {
        const systemPrompt = `You are a search query router for a coding assistant.
Analyze the ticket title and description, and determine:
1. Does solving this ticket require external web searches (e.g. finding documentation, getting latest package versions, or looking up API usage guidelines for external libraries)?
2. If yes, extract:
   - Any package/library names to lookup (e.g. ["dio", "network_inspector"]).
   - Any queries (general setup queries or specific URLs to scrape, e.g. ["https://pub.dev/packages/network_inspector", "network_inspector setup in flutter"]).

Classification guidelines:
- Set "needsSearch": true if the task involves:
  - Adding a new package, dependency, or library.
  - Upgrading/downgrading packages.
  - Using an external API, service, or library that is not a standard built-in.
  - Resolving a dependency conflict or version-solving error.
  - Refactoring complex third-party library calls.
- Set "needsSearch": false for tasks that can be solved locally without external documentation, such as:
  - Modifying internal business logic, UI layouts, styling, button colors, text formatting.
  - Adding a simple unit test for an existing local class.
  - Trivial fixes (syntax errors, null pointer checks, simple refactors of local code).

Format your output as a JSON object ONLY:
{
  "needsSearch": boolean,
  "packages": ["package_name1"],
  "queries": ["how to use package_name1 in flutter" or "https://pub.dev/packages/package_name1"]
}`;

        const userPrompt = `Ticket:
Title: ${title}
Description:
${body ?? "No description provided"}
`;

        try {
            const rawResponse = await this.ai.generateCompletion({
                systemPrompt,
                userPrompt,
                jsonMode: true
            }, "fast"); // Fast model is sufficient for extracting search terms

            const cleaned = rawResponse.trim().replace(/^```json/, "").replace(/```$/, "").trim();
            const parsed = JSON.parse(cleaned);
            return {
                needsSearch: !!parsed?.needsSearch,
                packages: Array.isArray(parsed?.packages) ? parsed.packages : [],
                queries: Array.isArray(parsed?.queries) ? parsed.queries : [],
            };
        } catch (err: any) {
            this.logger.error({ error: err.message }, "Failed to classify search needs, defaulting to false");
            return { needsSearch: false, packages: [], queries: [] };
        }
    }

    /**
     * Resolves latest package versions from registries and performs web searches or URL scraping.
     */
    private async searchPackagesAndDocs(packages: string[], queries: string[], fileTree: string[]): Promise<string> {
        const isFlutter = fileTree.some(f => f.endsWith("pubspec.yaml") || f.endsWith(".dart"));
        const isNode = fileTree.some(f => f.endsWith("package.json") || f.endsWith(".ts") || f.endsWith(".js"));

        let searchContext = "=== Web Search Context ===\n";

        // 1. Check Package Versions
        for (const pkg of packages) {
            if (isFlutter) {
                const pubVer = await this.webSearch.getPackageLatestVersion("pub", pkg);
                if (pubVer) {
                    searchContext += `- Dart/Flutter package "${pkg}" latest version: ^${pubVer}\n`;
                }
            }
            if (isNode) {
                const npmVer = await this.webSearch.getPackageLatestVersion("npm", pkg);
                if (npmVer) {
                    searchContext += `- Node/npm package "${pkg}" latest version: ^${npmVer}\n`;
                }
            }
        }

        // 2. Perform Web Searches
        for (const query of queries) {
            const results = await this.webSearch.searchDocs(query);
            searchContext += `\nResults for "${query}":\n${results}\n`;
        }

        return searchContext;
    }

    private async classifyFailure(logs: string): Promise<"infra" | "code"> {
        const systemPrompt = `You are a DevOps and CI classification expert.
Analyze the provided build log output and classify whether the failure is a Code/Test error or an Infrastructure/Environment/Network/Auth/Secrets/Dependency-Registry error.

Classification criteria:
- "code": Any compiler error, syntax error, unit test failure, code lint violation, import/module not found for files in the repo, type mismatch, dependency version-solving errors (e.g. "doesn't match any versions", package not found in registry because of incorrect version written in pubspec.yaml or package.json), or run-time test crash. These are errors that can be fixed by modifying the source code or configuration files of the application.
- "infra": Infrastructure/Env/Network issues like missing secrets, environment variables not set, runner out of disk space, API/network timeouts, service/database connection failures during setup, Docker daemon not running, npm/yarn/pub registry timeout, authentication failure, or permission issues. These cannot be resolved by editing application source code or configuration.

Example of "code":
- "Because sellio_mobile depends on network_inspector ^3.0.0 which doesn't match any versions, version solving failed." -> This is "code" because it means the developer/agent wrote an invalid version in pubspec.yaml/package.json, which can be corrected by editing pubspec.yaml/package.json.

You MUST respond with a JSON object ONLY:
{
  "classification": "code" | "infra",
  "reason": "Short explanation of why it fits this class"
}`;
        const userPrompt = `Build log output:\n\n${logs}`;
        try {
            const response = await this.ai.generateCompletion({
                systemPrompt,
                userPrompt,
                jsonMode: true
            }, "fast"); // CI classification is a simple JSON task — Workers AI handles it for free
            const parsed = JSON.parse(response);
            return parsed.classification === "infra" ? "infra" : "code";
        } catch (err: any) {
            this.logger.error({ err: err.message }, "Error classifying failure, defaulting to code");
            return "code";
        }
    }

    private async extractAndFetchImages(text: string): Promise<{ mimeType: string; data: string }[]> {
        if (!text) return [];
        
        const imageUrls: string[] = [];
        
        // Match Markdown images: ![alt](url)
        const mdRegex = /!\[.*?\]\((https?:\/\/[^\s\)]+)\)/g;
        let match;
        while ((match = mdRegex.exec(text)) !== null) {
            imageUrls.push(match[1]);
        }
        
        // Match HTML images: <img src="url">
        const htmlRegex = /<img[^>]+src=["'](https?:\/\/[^"']+)["']/g;
        while ((match = htmlRegex.exec(text)) !== null) {
            imageUrls.push(match[1]);
        }
        
        // Deduplicate and limit to first 3 images
        const uniqueUrls = Array.from(new Set(imageUrls)).slice(0, 3);
        const results: { mimeType: string; data: string }[] = [];
        
        for (const url of uniqueUrls) {
            try {
                this.logger.info({ url }, "Fetching ticket image attachment");
                
                let base64Data = "";
                let contentType = "image/png";

                if (url.includes("github")) {
                    const octokit = this.gitOps["github"].raw;
                    // Fetch via octokit.request so it uses app installation auth automatically!
                    const res = await octokit.request({
                        method: "GET",
                        url,
                        responseType: "arraybuffer"
                    });
                    
                    const arrayBuffer = res.data as ArrayBuffer;
                    const uint8 = new Uint8Array(arrayBuffer);
                    let binary = "";
                    const len = uint8.byteLength;
                    for (let i = 0; i < len; i++) {
                        binary += String.fromCharCode(uint8[i]);
                    }
                    base64Data = btoa(binary);
                    contentType = res.headers["content-type"] || "image/png";
                } else {
                    const res = await fetch(url);
                    if (!res.ok) {
                        this.logger.warn({ url, status: res.status }, "Failed to fetch image attachment");
                        continue;
                    }
                    const arrayBuffer = await res.arrayBuffer();
                    const uint8 = new Uint8Array(arrayBuffer);
                    let binary = "";
                    const len = uint8.byteLength;
                    for (let i = 0; i < len; i++) {
                        binary += String.fromCharCode(uint8[i]);
                    }
                    base64Data = btoa(binary);
                    contentType = res.headers.get("content-type") || "image/png";
                }
                
                results.push({
                    mimeType: contentType,
                    data: base64Data
                });
            } catch (err: any) {
                this.logger.warn({ url, error: err.message }, "Error downloading image attachment");
            }
        }
        
        return results;
    }
}
