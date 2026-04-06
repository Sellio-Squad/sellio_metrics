/**
 * Sellio Metrics Backend — Application Errors
 *
 * Structured error hierarchy for central error handling.
 * Every error has a `statusCode`, `code`, and `message`.
 */

export class AppError extends Error {
    public readonly statusCode: number;
    public readonly code: string;
    public readonly isOperational: boolean;
    public readonly details?: Record<string, any>;

    constructor(
        message: string,
        statusCode = 500,
        code = "INTERNAL_ERROR",
        isOperational = true,
        details?: Record<string, any>
    ) {
        super(message);
        this.name = this.constructor.name;
        this.statusCode = statusCode;
        this.code = code;
        this.isOperational = isOperational;
        this.details = details;

        if (typeof Error.captureStackTrace === "function") {
            Error.captureStackTrace(this, this.constructor);
        } else {
            Object.setPrototypeOf(this, new.target.prototype);
        }
    }
}

export class NotFoundError extends AppError {
    constructor(resource: string) {
        super(`${resource} not found`, 404, "NOT_FOUND");
    }
}

export class BadRequestError extends AppError {
    constructor(message: string) {
        super(message, 400, "BAD_REQUEST");
    }
}

export class GitHubApiError extends AppError {
    constructor(message: string, statusCode = 502) {
        super(message, statusCode, "GITHUB_API_ERROR");
    }
}

export class RateLimitError extends AppError {
    constructor() {
        super("GitHub API rate limit exceeded. Try again later.", 429, "RATE_LIMIT");
    }
}
