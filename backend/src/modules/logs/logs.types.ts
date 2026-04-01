export type LogSeverity = "info" | "warning" | "error" | "success";
export type LogCategory = "github" | "googleMeet" | "system" | "webhook";

export interface LogEntry {
    id: string;
    timestamp: string;
    message: string;
    severity: LogSeverity;
    category: LogCategory;
    metadata?: Record<string, any>;
}
