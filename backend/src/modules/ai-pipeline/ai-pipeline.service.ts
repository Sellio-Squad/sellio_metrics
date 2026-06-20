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
import type { CloudflareQueue } from "../../core/container";
import type { AiImplementJob, RepoContext, ImplementationPlan, CodeChange } from "./ai-pipeline.types";
import { AppError } from "../../core/errors";

export class AiPipelineService {
    private readonly cache: CacheService;
    private readonly ai: AiProviderClient;
    private readonly contextService: ContextService;
    private readonly gitOps: GitOpsService;
    private readonly syncQueue: CloudflareQueue | null;
    private readonly webhookQueue: CloudflareQueue | null;
    private readonly logger: Logger;

    constructor({
        cacheService,
        aiProviderClient,
        contextService,
        gitOpsService,
        syncQueue,
        webhookQueue,
        logger,
    }: {
        cacheService: CacheService;
        aiProviderClient: AiProviderClient;
        contextService: ContextService;
        gitOpsService: GitOpsService;
        syncQueue: CloudflareQueue | null;
        webhookQueue: CloudflareQueue | null;
        logger: Logger;
    }) {
        this.cache = cacheService;
        this.ai = aiProviderClient;
        this.contextService = contextService;
        this.gitOps = gitOpsService;
        this.syncQueue = syncQueue;
        this.webhookQueue = webhookQueue;
        this.logger = logger.child({ module: "ai-pipeline" });
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

        // 5. Generate plan using LLM
        const plan = await this.generatePlan(context, job.issueTitle, job.issueBody);

        // 6. Save context & plan to KV cache (TTL 1 hour)
        await Promise.all([
            this.cache.set(`ai:task:${job.taskId}:context`, context, 3600),
            this.cache.set(`ai:task:${job.taskId}:plan`, plan, 3600),
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

        // 1. Retrieve plan and context from KV
        const [contextVal, planVal] = await Promise.all([
            this.cache.get<RepoContext>(`ai:task:${job.taskId}:context`),
            this.cache.get<ImplementationPlan>(`ai:task:${job.taskId}:plan`),
        ]);

        if (!contextVal || !planVal) {
            throw new AppError("Context or plan not found in KV cache. Phase 2 aborted.", 400, "AI_CACHE_MISS");
        }

        const context = contextVal.data;
        const plan = planVal.data;

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

        while (attempt <= 2 && !validated) {
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
                    feedback
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
                    feedback
                );
                changes.push({ path: filePath, content, action: "create" });
            }

            // Self-validate changes
            const validationResult = await this.selfValidateChanges(changes, context);
            if (validationResult.success) {
                validated = true;
                this.logger.info({ taskId: job.taskId }, "Self-validation passed");
            } else {
                feedback = `Your previous attempt failed validation with the following errors:\n${validationResult.errors.join("\n")}\nPlease correct these errors.`;
                this.logger.warn({ taskId: job.taskId, errors: validationResult.errors }, "Self-validation failed, retrying");
                attempt++;
            }
        }

        if (!validated) {
            throw new AppError(`LLM self-validation failed after retries: ${feedback}`, 422, "AI_VALIDATION_FAILED");
        }

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

        // 1. Retrieve generated changes from KV
        const codeVal = await this.cache.get<CodeChange[]>(`ai:task:${job.taskId}:code`);
        if (!codeVal) {
            throw new AppError("Generated code changes not found in KV cache. Phase 3 aborted.", 400, "AI_CACHE_MISS");
        }

        const changes = codeVal.data;

        // 2. Perform git ops
        const { branch: defaultBranch, sha: baseSha } = await this.gitOps.getDefaultBranchHead(job.owner, job.repo);
        
        // Branch format: ai/{issueNumber}-{slugified-title}
        const slug = job.issueTitle
            .toLowerCase()
            .replace(/[^a-z0-9]+/g, "-")
            .replace(/(^-|-$)/g, "")
            .slice(0, 40);
        const branchName = `ai/${job.issueNumber}-${slug}`;

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

### Changes Implemented:
${changes.map((c: CodeChange) => `- **${c.action === "create" ? "[NEW]" : "[MOD]"}** \`${c.path}\``).join("\n")}

Please review the changes and run the build tests.`;

        const pr = await this.gitOps.createPR(job.owner, job.repo, {
            title: prTitle,
            body: prBody,
            head: branchName,
            base: defaultBranch,
        });

        // Comment on issue that PR is opened
        await this.gitOps.commentOnIssue(
            job.owner,
            job.repo,
            job.issueNumber,
            `🤖 **Sellio AI Agent**\n- *Phase 3:* PR opened successfully: [PR #${pr.number}](${pr.url})\n- Monitoring CI status (polling Checks API for up to 5 minutes)...`
        );

        // Enqueue CI polling
        if (this.syncQueue) {
            await this.syncQueue.send({
                type: "ai_implement_poll",
                owner: job.owner,
                repo: job.repo,
                issueNumber: job.issueNumber,
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
    }): Promise<void> {
        this.logger.info({ prNumber: job.prNumber, attempt: job.pollAttempt }, "Polling CI status");

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
            await this.gitOps.commentOnIssue(
                job.owner,
                job.repo,
                job.issueNumber,
                `❌ **Build failed** on CI. Moving card to **AI: Failed**.\n- Check [CI Logs](${logsUrl}) for details.`
            );
            await this.gitOps.moveProjectCardByName(job.projectId, job.itemId, job.fieldId, "AI: Failed");
            await this.cleanupTask(job.taskId);
        } else {
            // Build passed!
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
        if (job.pollAttempt >= 10) {
            // Timed out (5 minutes)
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

    private async generatePlan(context: RepoContext, title: string, body: string | null): Promise<ImplementationPlan> {
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

        const userPrompt = `Issue:
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

        const raw = await this.ai.generateCompletion({
            systemPrompt,
            userPrompt,
            jsonMode: true,
        });

        const cleaned = raw.trim().replace(/^```json/, "").replace(/```$/, "").trim();
        return JSON.parse(cleaned) as ImplementationPlan;
    }

    private async generateCodeForFile(
        filePath: string,
        existingContent: string,
        plan: ImplementationPlan,
        context: RepoContext,
        feedback: string
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

        if (feedback) {
            userPrompt += `\n\nValidation Feedback:\n${feedback}`;
        }

        const raw = await this.ai.generateCompletion({
            systemPrompt,
            userPrompt,
            jsonMode: false,
        });

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
        });

        const cleaned = raw.trim().replace(/^```json/, "").replace(/```$/, "").trim();
        return JSON.parse(cleaned);
    }

    private cleanCodeContent(raw: string): string {
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
}
