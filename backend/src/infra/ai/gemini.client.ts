/**
 * Sellio Metrics — Gemini AI Client
 *
 * Direct REST integration with Google Gemini API.
 * Uses fetch() (no SDK) so it works on Cloudflare Workers.
 *
 * Sends PR diffs to Gemini and parses the structured code review response.
 */

import type { Logger } from "../../core/logger";

// ─── Response Types ─────────────────────────────────────────

export type IssueSeverity = "critical" | "warning" | "info";

export interface ReviewFinding {
    file: string;
    line?: number | null;
    severity: IssueSeverity;
    title: string;
    description: string;
    suggestion?: string;
}

export interface GeminiReviewResult {
    prSummary: string;
    bugs: ReviewFinding[];
    bestPractices: ReviewFinding[];
    security: ReviewFinding[];
    performance: ReviewFinding[];
    hasIssues: boolean;
}

// ─── Client ─────────────────────────────────────────────────

export class GeminiClient {
    private readonly apiKey: string;
    private readonly logger: Logger;
    private readonly model = "gemini-2.0-flash";
    private readonly baseUrl = "https://generativelanguage.googleapis.com/v1beta/models";

    constructor({ geminiApiKey, logger }: { geminiApiKey: string; logger: Logger }) {
        this.apiKey = geminiApiKey;
        this.logger = logger.child({ module: "gemini" });
    }

    async analyzeCode(params: {
        prTitle: string;
        prAuthor: string;
        prBody: string | null;
        files: Array<{
            filename: string;
            status: string;
            additions: number;
            deletions: number;
            patch?: string;
        }>;
    }): Promise<GeminiReviewResult> {
        const prompt = this._buildPrompt(params);

        this.logger.info({ files: params.files.length }, "Sending PR to Gemini for review");

        const url = `${this.baseUrl}/${this.model}:generateContent?key=${this.apiKey}`;

        const body = {
            contents: [{ parts: [{ text: prompt }] }],
            generationConfig: {
                temperature: 0.2,
                maxOutputTokens: 8192,
                responseMimeType: "application/json",
            },
        };

        let response: Response;
        try {
            response = await fetch(url, {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify(body),
            });
        } catch (e: any) {
            this.logger.error({ err: e.message }, "Gemini fetch failed");
            throw new Error(`Gemini API request failed: ${e.message}`);
        }

        if (!response.ok) {
            const errText = await response.text();
            this.logger.error({ status: response.status, body: errText }, "Gemini API error");
            throw new Error(`Gemini API error (${response.status}): ${errText}`);
        }

        const raw: any = await response.json();
        const text: string = raw?.candidates?.[0]?.content?.parts?.[0]?.text ?? "{}";

        let parsed: any;
        try {
            parsed = JSON.parse(text);
        } catch {
            this.logger.warn({ text }, "Failed to parse Gemini JSON output");
            parsed = {};
        }

        return this._normalize(parsed);
    }

    // ─── Private ────────────────────────────────────────────

    private _buildPrompt(params: {
        prTitle: string;
        prAuthor: string;
        prBody: string | null;
        files: Array<{ filename: string; status: string; additions: number; deletions: number; patch?: string }>;
    }): string {
        const fileSection = params.files
            .slice(0, 30) // Limit to 30 files to stay within token budget
            .map((f) => {
                const patch = f.patch
                    ? `\`\`\`diff\n${f.patch.slice(0, 4000)}\n\`\`\`` // Cap patch at 4000 chars per file
                    : "(binary or empty file)";
                return `### File: ${f.filename} [${f.status}] (+${f.additions} -${f.deletions})\n${patch}`;
            })
            .join("\n\n");

        return `You are a senior software engineer doing a production-level code review. Analyze the following PR and return a structured JSON review.

## PR Information
- Title: ${params.prTitle}
- Author: ${params.prAuthor}
- Description: ${params.prBody ?? "No description provided"}

## Changed Files
${fileSection}

## Instructions
Return ONLY a JSON object (no markdown, no explanation) with this exact structure:
{
  "prSummary": "2-3 sentence summary of what this PR does and overall quality",
  "bugs": [
    {
      "file": "filename",
      "line": null,
      "severity": "critical | warning | info",
      "title": "short title",
      "description": "clear explanation of the bug or logic error",
      "suggestion": "how to fix it"
    }
  ],
  "bestPractices": [ ...same shape... ],
  "security": [ ...same shape... ],
  "performance": [ ...same shape... ]
}

Rules:
- severity must be one of: "critical", "warning", "info"
- Only include meaningful issues (skip trivial comments)
- Map each issue to a specific file if possible
- If a category has no issues, return an empty array []
- Assume production-level standards
- Be concise and actionable
- Do NOT repeat the same issue multiple times`;
    }

    private _normalize(raw: any): GeminiReviewResult {
        const bugs = this._sanitizeFindings(raw?.bugs);
        const bestPractices = this._sanitizeFindings(raw?.bestPractices);
        const security = this._sanitizeFindings(raw?.security);
        const performance = this._sanitizeFindings(raw?.performance);

        return {
            prSummary: typeof raw?.prSummary === "string" ? raw.prSummary : "No summary available.",
            bugs,
            bestPractices,
            security,
            performance,
            hasIssues: bugs.length + bestPractices.length + security.length + performance.length > 0,
        };
    }

    private _sanitizeFindings(raw: unknown): ReviewFinding[] {
        if (!Array.isArray(raw)) return [];
        return raw
            .filter((f: any) => f && typeof f === "object")
            .map((f: any) => ({
                file: typeof f.file === "string" ? f.file : "unknown",
                line: typeof f.line === "number" ? f.line : null,
                severity: (["critical", "warning", "info"].includes(f.severity) ? f.severity : "info") as IssueSeverity,
                title: typeof f.title === "string" ? f.title : "Issue",
                description: typeof f.description === "string" ? f.description : "",
                suggestion: typeof f.suggestion === "string" ? f.suggestion : undefined,
            }));
    }
}
