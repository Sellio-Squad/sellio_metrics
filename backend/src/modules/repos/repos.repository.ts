import type { D1Database } from "../../infra/database/d1.service";
import type { Logger } from "../../core/console-logger";

export interface Repo {
    id:              number;
    owner:           string;
    name:            string;
    htmlUrl?:        string;
    description?:    string;
    githubCreatedAt?: string;
    pushedAt?:       string;
}

export class ReposRepository {
    constructor(
        private readonly db: D1Database | null,
        private readonly logger: Logger,
    ) {
        this.logger = logger.child({ module: "repos-repository" });
    }

    async upsertRepo(
        id: number,
        owner: string,
        name: string,
        opts: { htmlUrl?: string; description?: string; githubCreatedAt?: string; pushedAt?: string } = {},
    ): Promise<number> {
        if (!this.db) return id;
        
        await this.db
            .prepare(
                `INSERT INTO repos (id, owner, name, html_url, description, github_created_at, pushed_at)
                 VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)
                 ON CONFLICT(owner, name) DO UPDATE SET
                     html_url          = COALESCE(?4, html_url),
                     description       = COALESCE(?5, description),
                     github_created_at = COALESCE(?6, github_created_at),
                     pushed_at         = COALESCE(?7, pushed_at)`
            )
            .bind(
                id, owner, name,
                opts.htmlUrl ?? null, opts.description ?? null,
                opts.githubCreatedAt ?? null, opts.pushedAt ?? null
            )
            .run();
            
        return id;
    }

    async listRepos(): Promise<Repo[]> {
        if (!this.db) return [];
        const res = await this.db
            .prepare("SELECT id, owner, name, html_url, description FROM repos ORDER BY owner, name")
            .all<any>();
            
        return res.results.map((r) => ({
            id:              r.id as number,
            owner:           r.owner,
            name:            r.name,
            htmlUrl:         r.html_url,
            description:     r.description,
        }));
    }
}
