export class AppError extends Error {
    constructor(
        public readonly message: string,
        public readonly statusCode: number = 400,
        public readonly details?: Record<string, any>
    ) {
        super(message);
        this.name = "AppError";
        // Ensure instanceof works
        Object.setPrototypeOf(this, new.target.prototype);
    }
}
