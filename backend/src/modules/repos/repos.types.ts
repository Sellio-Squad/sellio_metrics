/**
 * Repos Module — Types
 */

export interface ReposListResponse {
    org: string;
    count: number;
    repos: Array<{
        name: string;
        full_name: string;
        description: string | null;
        html_url: string;
        private: boolean;
        default_branch: string;
    }>;
}
