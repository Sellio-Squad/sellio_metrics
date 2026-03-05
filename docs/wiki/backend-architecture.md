## 🧱 Backend Architecture (TypeScript + Fastify)

The backend is a **Fastify** application written in **TypeScript**. It exposes a small REST API used by the Flutter web frontend and is organized into clearly separated layers:

- **Config & Core** (`src/config`, `src/core`)
- **Infrastructure** (`src/infra`)
- **Feature Modules** (`src/modules`)
- **Cross‑cutting Plugins** (`src/plugins`)
- **App & Server bootstrap** (`src/app.ts`, `src/server.ts`)

### 1. Entry Points & Application Lifecycle

- `server.ts` builds the application and starts listening:
  - Validates environment via `config/env.ts`.
  - Builds the Awilix DI container via `core/container.ts`.
  - Logs a private‑key diagnostics snapshot.
  - Calls `buildApp({ container, logLevel })` from `app.ts`.
  - Starts the Fastify server (default `0.0.0.0:3001`).
- `app.ts` is the **app factory**:
  - Creates the `FastifyInstance` with a Pino logger.
  - Registers global plugins:
    - CORS (`@fastify/cors`)
    - Central error handler (`plugins/error-handler.ts`)
    - Rate limiting (`plugins/rate-limit.ts`)
    - Awilix DI integration (`@fastify/awilix`)
  - Copies registrations from the core Awilix container into Fastify’s DI scope.
  - Registers feature routes with prefixes:
    - `/api/health`
    - `/api/repos`
    - `/api/metrics`
    - `/api/webhooks`

> **Testing note**: Because `buildApp` is separate from `server.ts`, the Fastify app can be instantiated in tests without binding to a real port.

### 2. Configuration & Core Layer

- `config/env.ts`
  - Reads and validates environment variables (`APP_ID`, `INSTALLATION_ID`, `APP_PRIVATE_KEY`, `GITHUB_ORG`, `PORT`, `LOG_LEVEL`, etc.).
  - Ensures the RSA private key is present and well‑formed.
- `core/types.ts`
  - Shared **domain model** definitions used across modules:
    - `UserInfo`, `CommentGroup`, `Approval`, `DiffStats`
    - `PrMetric` (canonical backend PR metric type)
    - `RepoInfo` (repository metadata)
    - `LeaderboardEntry` (backend‑side leaderboard record)
- `core/logger.ts`
  - Configures Pino logger used everywhere.
- `core/errors.ts`
  - `AppError` base class plus specific errors (`GitHubApiError`, etc.).
- `core/container.ts`
  - Builds an Awilix container (`Cradle`) that wires:
    - `env`, `logger`
    - `GitHubClient`, `CachedGitHubClient`, `CacheService`, `RateLimitGuard`
    - `ReposService`, `MetricsService`, and other module services.

These core pieces are **framework‑agnostic** where possible: they know about domain concepts and infrastructure but not about HTTP specifics.

### 3. Infrastructure Layer

#### 3.1 GitHub Client (`src/infra/github`)

- `github.client.ts`
  - Wraps `Octokit` with `@octokit/auth-app`:
    - Signs JWTs using the GitHub App’s ID and private key.
    - Exchanges JWTs for installation access tokens.
    - Automatically caches and refreshes tokens before expiry.
  - This is the **only module** that directly knows about Octokit.

- `cached-github.client.ts`
  - Cache‑first wrapper around `GitHubClient` that:
    - Uses `CacheService` to store:
      - Organization repos (24h TTL).
      - PR lists per repo (3 min TTL).
      - Individual PR details, reviews, comments (TTL varies by open/closed).
    - Uses `RateLimitGuard` to throttle GitHub calls when quota is low.
    - Exposes high‑level methods:
      - `listOrgRepos(org)`
      - `listPulls(owner, repo, state, perPage)`
      - `getPull(owner, repo, pullNumber, isOpen)`
      - `listReviews`, `listIssueComments`, `listReviewComments`

- `github.types.ts`
  - Typed representations of the raw GitHub API responses used by mappers.

- `rate-limit-guard.ts`
  - Tracks GitHub rate‑limit headers (`x-ratelimit-*`).
  - `checkAndWait()`:
    - If remaining requests are above a configurable threshold, continues.
    - If they are low, waits until reset (up to a max wait) before proceeding.
  - Provides `getStatus()` for debugging and monitoring.

#### 3.2 Cache Service (`src/infra/cache/cache.service.ts`)

- Wraps **Cloudflare Workers KV** (or no‑op for local dev without KV).
- Uses a `KVNamespace` interface:
  - `get(key, { type })`
  - `put(key, value, { expirationTtl })`
  - `delete(key)`
- Stores typed `CachedValue<T>` objects:
  - `{ data, etag?, cachedAt }`
- Namespaces all keys with a `sellio:` prefix.
- Handles serialization, TTL, and basic error logging.

### 4. Feature Modules

Each backend feature is a **vertical slice** under `src/modules/<feature>`:

- **Health** (`modules/health/health.route.ts`)
  - Simple `GET /api/health` endpoint reporting service and org information.

- **Repos** (`modules/repos`)
  - `repos.route.ts`:
    - Fastify route that handles `GET /api/repos`.
    - Resolves `ReposService` from DI (`request.diScope.cradle`).
  - `repos.service.ts`:
    - Uses `CachedGitHubClient.listOrgRepos(org)` to fetch all repos.
    - Maps raw GitHub repository objects to `RepoInfo`.
    - Logs count and handles `GitHubApiError`.
  - `repos.types.ts`:
    - DTOs / schemas for the repos API.

- **Metrics** (`modules/metrics`)
  - `metrics.route.ts`:
    - HTTP boundary for `GET /api/metrics/:owner/:repo`.
    - Validates query (`state`, `per_page`, etc.).
    - Resolves `MetricsService` from DI and returns the resulting `PrMetric[]`.
  - `metrics.service.ts`:
    - Orchestrates metrics computation:
      - Builds a KV cache key: `result:metrics:${owner}/${repo}:${state}`.
      - On **result cache hit**:
        - Returns `PrMetric[]` from KV immediately.
      - On **miss**:
        - Uses `CachedGitHubClient.listPulls` to paginate PRs.
        - Enriches PRs in batches (`BATCH_SIZE = 10`) to reduce rate‑limit risk:
          - For each PR:
            - `getPull`, `listReviews`, `listIssueComments`, `listReviewComments`.
          - Delegates transformation to `metrics.mapper.ts`.
        - Stores the final `PrMetric[]` array in KV (default TTL 1 hour).
    - Wraps lower‑level errors in `GitHubApiError` when appropriate.
  - `metrics.mapper.ts`:
    - Pure functions that turn raw GitHub data into `PrMetric`:
      - `toUserInfo` maps raw GitHub user → `UserInfo`.
      - `groupComments` groups comments per author with first/last timestamps.
      - `processApprovals` deduplicates approvals and prefers current‑commit reviews.
      - `determinePrStatus` normalizes PR state (`pending`, `approved`, `merged`, `closed`).
      - `mapToPrMetric` is the main entry:
        - Computes time‑to‑first‑approval and time‑to‑required‑approvals (minutes).
        - Calculates ISO week using `toISOWeek`.
        - Assembles labels, milestone, diff stats, review requests, etc.
  - `metrics.types.ts`:
    - Module‑specific DTOs and query parameter types.

- **Webhook** (`modules/webhook/webhook.route.ts`)
  - Handles GitHub webhooks (`POST /api/webhooks/github`).
  - Responsible for **cache invalidation**:
    - When PR/review/comment events arrive from GitHub, it deletes or updates the relevant KV keys (`github:*`, `result:metrics:*`) so new metrics are computed on next request.

> The wiki’s `domain-and-metrics.md` page explains how these backend `PrMetric` objects are interpreted and enriched on the frontend side.

### 5. Cross‑Cutting Plugins

- `plugins/error-handler.ts`
  - Central Fastify error handler that:
    - Normalizes all errors to a JSON payload with:
      - `error`, `code`, `statusCode`, `message`.
    - Understands `AppError` subclasses and maps them to HTTP codes.

- `plugins/rate-limit.ts`
  - Attaches `@fastify/rate-limit` with configuration derived from env (`RATE_LIMIT_MAX`, `RATE_LIMIT_WINDOW_MS`).
  - Protects the API itself from abusive clients (separate from GitHub’s own limits, which are guarded by `RateLimitGuard`).

### 6. HTTP API Surface

The backend exposes a small, well‑defined API:

- `GET /api/health`
  - Service health and basic org info.

- `GET /api/repos`
  - Returns a list of repositories (`RepoInfo[]`) for the configured organization.
  - Response is cached for 24h using the cached GitHub client.

- `GET /api/metrics/:owner/:repo`
  - Returns PR metrics for a repo:
    - `{ owner, repo, count, metrics: PrMetric[] }`.
  - Applies both **resource‑level caching** (per GitHub call) and **result‑level caching** (the final metrics array).

- `POST /api/webhooks/github`
  - Optional webhook endpoint to receive GitHub events and invalidate caches in near‑real‑time.

For endpoint parameters and examples, see `backend/README.md`. This page focuses on how the code and layers are structured internally.

