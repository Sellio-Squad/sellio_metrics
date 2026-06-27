/**
 * Sellio Metrics — AI Chat Module Types
 */

export type MessageRole = "user" | "assistant" | "tool_result";

export interface ChatMessage {
    role: MessageRole;
    content: string;
    toolName?: string;
    toolArgs?: unknown;
    toolResult?: unknown;
    timestamp: string;
}

export interface ChatSession {
    sessionId: string;
    owner: string;
    repo: string;
    messages: ChatMessage[];
    createdAt: string;
    updatedAt: string;
}

export interface ToolCallRecord {
    name: string;
    args: unknown;
    result: unknown;
}

export interface ChatRequest {
    owner: string;
    repo: string;
    message: string;
    githubLogin: string;
    sessionId?: string;
}

export interface ChatResponse {
    sessionId: string;
    message: string;
    toolCallsMade: ToolCallRecord[];
}

export interface ToolDeps {
    owner: string;
    repo: string;
    org: string;
    octokit: any;
    gqlClient: any;
    contextService: any;
    openTicketsService: any;
    reviewService: any;
    scoreAggregationService: any;
    gitOpsService: any;
    syncQueue: any | null;
    logger: any;
}

export interface AgentTool {
    name: string;
    description: string;
    parameters: Record<string, unknown>;
    execute(args: any, deps: ToolDeps): Promise<unknown>;
}
