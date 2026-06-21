/**
 * Sellio Metrics — Git Operations Service
 *
 * Performs git database and project automation operations:
 *   - Branch creation
 *   - Commit files via GitHub Tree/Blob Git DB API (no local repo checkout needed)
 *   - Pull Request creation
 *   - Commenting on issues
 *   - Assigning issues to the Sellio bot
 *   - Moving GitHub Projects v2 cards between columns
 */

import type { CachedGitHubClient } from "../../infra/github/cached-github.client";
import type { Logger } from "../../core/logger";
import { AppError, GitHubApiError } from "../../core/errors";
import type { CodeChange } from "./ai-pipeline.types";

const FIELD_OPTIONS_QUERY = `
  query GetProjectFieldOptions($projectId: ID!) {
    node(id: $projectId) {
      ... on ProjectV2 {
        fields(first: 50) {
          nodes {
            ... on ProjectV2SingleSelectField {
              id
              name
              options {
                id
                name
              }
            }
          }
        }
      }
    }
  }
`;

const UPDATE_FIELD_VALUE_MUTATION = `
  mutation UpdateProjectItemFieldValue($projectId: ID!, $itemId: ID!, $fieldId: ID!, $optionId: String!) {
    updateProjectV2ItemFieldValue(input: {
      projectId: $projectId,
      itemId: $itemId,
      fieldId: $fieldId,
      value: {
        singleSelectOptionId: $optionId
      }
    }) {
      projectV2Item {
        id
      }
    }
  }
`;

export class GitOpsService {
    private readonly github: CachedGitHubClient;
    private readonly logger: Logger;

    constructor({
        cachedGithubClient,
        logger,
    }: {
        cachedGithubClient: CachedGitHubClient;
        logger: Logger;
    }) {
        this.github = cachedGithubClient;
        this.logger = logger.child({ module: "git-ops" });
    }

    /**
     * Resolves default branch and gets its HEAD commit SHA.
     */
    async getDefaultBranchHead(owner: string, repo: string): Promise<{ branch: string; sha: string }> {
        try {
            const octokit = this.github.raw;
            const { data: repoInfo } = await octokit.repos.get({ owner, repo });
            const branch = repoInfo.default_branch;

            const { data: refInfo } = await octokit.git.getRef({
                owner,
                repo,
                ref: `heads/${branch}`,
            });

            return { branch, sha: refInfo.object.sha };
        } catch (err: any) {
            throw new GitHubApiError(`Failed to get default branch head: ${err.message}`);
        }
    }

    /**
     * Creates a new branch from a base SHA.
     */
    async createBranch(owner: string, repo: string, baseSha: string, branchName: string): Promise<void> {
        try {
            const octokit = this.github.raw;
            await octokit.git.createRef({
                owner,
                repo,
                ref: `refs/heads/${branchName}`,
                sha: baseSha,
            });
            this.logger.info({ owner, repo, branchName }, "Created new branch");
        } catch (err: any) {
            // If branch already exists, we will overwrite or log warning
            if (err.status === 422) {
                this.logger.warn({ owner, repo, branchName }, "Branch already exists");
                return;
            }
            throw new GitHubApiError(`Failed to create branch ${branchName}: ${err.message}`);
        }
    }

    /**
     * Commits multiple file changes directly using the Git Database API.
     */
    async commitFiles(
        owner: string,
        repo: string,
        branch: string,
        baseSha: string,
        changes: CodeChange[],
        commitMessage: string
    ): Promise<string> {
        try {
            const octokit = this.github.raw;

            // 1. Create blobs for each file
            this.logger.info({ count: changes.length }, "Creating blobs for modified files");
            const treeItems: any[] = [];

            for (const change of changes) {
                if (change.action === "delete") {
                    // For deletion, we don't create a blob. Instead, we omit it or mark it with mode/sha null
                    // But in GitHub Trees API, we can delete by sending tree item without sha to remove it
                    // Or set mode/sha to null
                    treeItems.push({
                        path: change.path,
                        mode: "100644",
                        type: "blob",
                        sha: null, // this deletes the file in the new tree
                    });
                    continue;
                }

                const { data: blob } = await octokit.git.createBlob({
                    owner,
                    repo,
                    content: change.content,
                    encoding: "utf-8",
                });

                treeItems.push({
                    path: change.path,
                    mode: "100644",
                    type: "blob",
                    sha: blob.sha,
                });
            }

            // 2. Create new tree based on the parent tree (baseSha)
            this.logger.info("Creating new Git tree");
            const { data: newTree } = await octokit.git.createTree({
                owner,
                repo,
                base_tree: baseSha,
                tree: treeItems,
            });

            // 3. Create the commit
            this.logger.info("Creating Git commit");
            const { data: commit } = await octokit.git.createCommit({
                owner,
                repo,
                message: commitMessage,
                tree: newTree.sha,
                parents: [baseSha],
            });

            // 4. Update the branch reference
            this.logger.info({ branch, commitSha: commit.sha }, "Updating branch reference");
            await octokit.git.updateRef({
                owner,
                repo,
                ref: `heads/${branch}`,
                sha: commit.sha,
                force: true,
            });

            return commit.sha;
        } catch (err: any) {
            throw new GitHubApiError(`Failed to commit files to branch ${branch}: ${err.message}`);
        }
    }

    /**
     * Creates a new Pull Request.
     */
    async createPR(
        owner: string,
        repo: string,
        params: {
            title: string;
            body: string;
            head: string;
            base: string;
        }
    ): Promise<{ number: number; url: string }> {
        try {
            const octokit = this.github.raw;
            const { data: pr } = await octokit.pulls.create({
                owner,
                repo,
                title: params.title,
                head: params.head,
                base: params.base,
                body: params.body,
            });

            this.logger.info({ prNumber: pr.number }, "Opened Pull Request successfully");
            return { number: pr.number, url: pr.html_url };
        } catch (err: any) {
            throw new GitHubApiError(`Failed to create PR: ${err.message}`);
        }
    }

    /**
     * Comments on a GitHub issue or pull request.
     */
    async commentOnIssue(owner: string, repo: string, issueNumber: number, commentBody: string): Promise<void> {
        try {
            const octokit = this.github.raw;
            await octokit.issues.createComment({
                owner,
                repo,
                issue_number: issueNumber,
                body: commentBody,
            });
            this.logger.info({ issueNumber }, "Added comment to issue");
        } catch (err: any) {
            this.logger.error({ issueNumber, error: err.message }, "Failed to comment on issue");
        }
    }

    /**
     * Assigns the ticket/issue to the "sellio bot".
     */
    async assignToBot(owner: string, repo: string, issueNumber: number): Promise<void> {
        try {
            const octokit = this.github.raw;
            const botUser = await this.getBotUsername();
            
            await octokit.issues.addAssignees({
                owner,
                repo,
                issue_number: issueNumber,
                assignees: [botUser],
            });
            this.logger.info({ issueNumber, botUser }, "Assigned issue to bot successfully");
        } catch (err: any) {
            this.logger.error({ issueNumber, error: err.message }, "Failed to assign issue to bot");
        }
    }

    /**
     * Queries the project field options using GraphQL to get Column names -> IDs mapping.
     */
    async getProjectFieldOptions(projectId: string, fieldId: string): Promise<Record<string, string>> {
        try {
            const octokit = this.github.raw;
            const result: any = await octokit.graphql(FIELD_OPTIONS_QUERY, {
                projectId,
            });

            const fields = result?.node?.fields?.nodes || [];
            const targetField = fields.find((f: any) => f.id === fieldId);
            const options = targetField?.options || [];
            
            const mapping: Record<string, string> = {};
            for (const opt of options) {
                if (opt.name && opt.id) {
                    mapping[opt.name.toLowerCase().trim()] = opt.id;
                }
            }
            return mapping;
        } catch (err: any) {
            this.logger.error({ projectId, fieldId, error: err.message }, "Failed to fetch project field options");
            return {};
        }
    }

    /**
     * Moves a project card to a specific column/option.
     */
    async moveProjectCard(projectId: string, itemId: string, fieldId: string, optionId: string): Promise<void> {
        try {
            const octokit = this.github.raw;
            await octokit.graphql(UPDATE_FIELD_VALUE_MUTATION, {
                projectId,
                itemId,
                fieldId,
                optionId,
            });
            this.logger.info({ itemId, optionId }, "Moved project card successfully");
        } catch (err: any) {
            this.logger.error({ itemId, optionId, error: err.message }, "Failed to move project card");
            throw new GitHubApiError(`Failed to move project card: ${err.message}`);
        }
    }

    /**
     * Utility to move project card by column name (case-insensitive).
     */
    async moveProjectCardByName(projectId: string, itemId: string, fieldId: string, columnName: string): Promise<void> {
        this.logger.info({ itemId, columnName }, "Attempting to move project card by name");
        const optionsMapping = await this.getProjectFieldOptions(projectId, fieldId);
        const targetOptionId = optionsMapping[columnName.toLowerCase().trim()];

        if (!targetOptionId) {
            this.logger.warn({ columnName, availableColumns: Object.keys(optionsMapping) }, "Target project column not found");
            return;
        }

        await this.moveProjectCard(projectId, itemId, fieldId, targetOptionId);
    }

    /**
     * Lists the check runs for a commit ref.
     */
    async listCheckRuns(owner: string, repo: string, ref: string): Promise<any> {
        try {
            const octokit = this.github.raw;
            return await octokit.checks.listForRef({
                owner,
                repo,
                ref,
            });
        } catch (err: any) {
            throw new GitHubApiError(`Failed to list check runs for ref ${ref}: ${err.message}`);
        }
    }

    /**
     * Replies to a pull request review comment.
     */
    async replyToReviewComment(
        owner: string,
        repo: string,
        pullNumber: number,
        commentId: number,
        body: string
    ): Promise<void> {
        try {
            const octokit = this.github.raw;
            await octokit.pulls.createReplyForReviewComment({
                owner,
                repo,
                pull_number: pullNumber,
                comment_id: commentId,
                body,
            });
            this.logger.info({ pullNumber, commentId }, "Created reply to review comment");
        } catch (err: any) {
            this.logger.error({ pullNumber, commentId, error: err.message }, "Failed to reply to review comment");
            throw new GitHubApiError(`Failed to reply to review comment: ${err.message}`);
        }
    }

    /**
     * Fetches the logs of the failed jobs in a workflow run.
     */
    async getWorkflowJobLogs(owner: string, repo: string, runId: number): Promise<string> {
        try {
            const octokit = this.github.raw;
            const { data: jobsResult } = await octokit.actions.listJobsForWorkflowRun({
                owner,
                repo,
                run_id: runId,
            });

            const failedJobs = jobsResult.jobs.filter(job => job.conclusion === "failure");
            if (failedJobs.length === 0) {
                return "No failed jobs found in the workflow run.";
            }

            const logsParts: string[] = [];
            for (const job of failedJobs) {
                try {
                    this.logger.info({ jobId: job.id, jobName: job.name }, "Downloading logs for failed job");
                    const { data: logText } = await octokit.actions.downloadJobLogsForWorkflowRun({
                        owner,
                        repo,
                        job_id: job.id,
                    });
                    
                    if (typeof logText === "string") {
                        const lines = logText.split("\n");
                        const truncatedLogs = lines.slice(-250).join("\n");
                        logsParts.push(`Job [${job.name}] (ID: ${job.id}) failed:\n...\n${truncatedLogs}`);
                    } else {
                        logsParts.push(`Job [${job.name}] (ID: ${job.id}) failed, but logs couldn't be parsed.`);
                    }
                } catch (jobErr: any) {
                    this.logger.error({ jobId: job.id, error: jobErr.message }, "Failed to download logs for job");
                    logsParts.push(`Job [${job.name}] (ID: ${job.id}) failed, and downloading logs failed: ${jobErr.message}`);
                }
            }

            return logsParts.join("\n\n");
        } catch (err: any) {
            this.logger.error({ runId, error: err.message }, "Failed to get workflow job logs");
            throw new GitHubApiError(`Failed to get workflow job logs: ${err.message}`);
        }
    }

    /**
     * Finds the workflow runs for a branch.
     */
    async listWorkflowRunsForBranch(owner: string, repo: string, branch: string): Promise<any[]> {
        try {
            const octokit = this.github.raw;
            const { data } = await octokit.actions.listWorkflowRunsForRepo({
                owner,
                repo,
                branch,
                per_page: 5,
            });
            return data.workflow_runs || [];
        } catch (err: any) {
            this.logger.error({ branch, error: err.message }, "Failed to list workflow runs for branch");
            return [];
        }
    }

    // ─── Private helpers ────────────────────────────────────

    private async getBotUsername(): Promise<string> {
        try {
            const octokit = this.github.raw;
            const { data } = await octokit.apps.getAuthenticated();
            if (data && typeof data === "object" && "slug" in data && data.slug) {
                return `${data.slug}[bot]`;
            }
        } catch (err: any) {
            this.logger.warn({ error: err.message }, "Failed to fetch authenticated app slug, using fallback");
        }
        return "sellio-metrics[bot]";
    }
}
