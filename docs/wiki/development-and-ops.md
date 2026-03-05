## 🛠️ Development & Operations

This page collects **how to work on Sellio Metrics** day‑to‑day: local development, configuration, testing, deployment, and operational concerns.

---

### 1. Local Development

All commands assume you are in the repo root (`sellio_metrics/`). See also `LOCAL_DEV_COMMANDS.md` for a quick reference.

#### 1.1 Frontend (Flutter Web)

- Run Flutter web (Chrome) against the local backend:

```bash
cd frontend
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:3001
```

- Build Flutter web for release:

```bash
cd frontend
flutter build web --dart-define=API_BASE_URL=http://localhost:3001
```

- Run with **fake data only** (no backend required):

```bash
cd frontend
flutter run -d chrome --dart-define=USE_FAKE_DATA=true
```

`ApiConfig` in `lib/core/constants/app_constants.dart` wires `API_BASE_URL` and `USE_FAKE_DATA` into the data layer. When `USE_FAKE_DATA` is `true`, `setupDependencies()` registers `FakeMetricsDataSource` instead of the remote data source.

#### 1.2 Backend (Fastify + TypeScript)

- Install dependencies:

```bash
cd backend
npm install
```

- Run backend in development mode (with `tsx` watch):

```bash
cd backend
npm run dev
```

- Type‑check / lint:

```bash
cd backend
npm run lint
```

- Build & run the compiled backend:

```bash
cd backend
npm run build
npm start
```

#### 1.3 Frontend + Backend Together

Run both in separate terminals:

```bash
# Terminal 1 — backend
cd backend
npm install
npm run dev

# Terminal 2 — frontend
cd frontend
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:3001
```

---

### 2. Configuration & Environment

#### 2.1 Backend Environment

See `backend/README.md` for full details. Key environment variables include:

- `APP_ID` (required) — GitHub App numeric ID.
- `INSTALLATION_ID` (required) — GitHub App installation ID.
- `APP_PRIVATE_KEY` or `PRIVATE_KEY_PATH` — private key used to sign JWTs.
- `GITHUB_ORG` — GitHub org slug (default `Sellio-Squad`).
- `PORT` — HTTP port (default `3001`).
- `LOG_LEVEL` — logging level (`trace`, `debug`, `info`, `warn`, `error`).
- Rate‑limit and approval config:
  - `REQUIRED_APPROVALS` — number of approvals for “approved” status.
  - `RATE_LIMIT_MAX`, `RATE_LIMIT_WINDOW_MS` — API rate‑limit settings.

The server validates config on startup via `config/env.ts` and logs a private‑key format diagnostic (first line / last line / line count) to help debug OpenSSL issues.

#### 2.2 Frontend Compile‑Time Config

- `API_BASE_URL` (via `--dart-define`) — base URL for the backend API.
- `USE_FAKE_DATA` (via `--dart-define`) — toggles fake metrics mode.

These values are consumed by `ApiConfig` and used when constructing the data sources.

---

### 3. Caching & Webhooks (Operational View)

#### 3.1 Caching Strategy

The backend employs a **multi‑layer caching strategy**:

- **Workers KV cache** via `CacheService`:
  - Used by `CachedGitHubClient` for:
    - Org repo list (`REPO_LIST` TTL ~24h).
    - Paginated PR lists per repo (`PR_LIST` TTL ~3 minutes).
    - Per‑PR details, reviews, and comments (TTL varies by open/closed).
  - Used by `MetricsService` for **result‑level** caching:
    - Final `PrMetric[]` arrays for a given repo and state (e.g. key `result:metrics:owner/repo:all`).
    - Default TTL ~1 hour.
  - All keys are prefixed with `sellio:` for isolation.

This approach dramatically reduces GitHub API calls for frequently viewed repos and speeds up dashboard loads after the first request.

#### 3.2 Webhooks & Cache Invalidation

- GitHub webhooks (configured in the GitHub App) can notify the backend of PR events:
  - Pull requests (opened, synchronized, closed, merged).
  - Pull request reviews.
  - Issue comments and review comments.
- These events are sent to:

```text
POST /api/webhooks/github
```

- The webhook handler:
  - Parses the event payload.
  - Determines which repo/PR is affected.
  - Invalidates related cache keys in KV (both GitHub‑level and result‑level).
  - Ensures the next metrics request returns up‑to‑date data without waiting for TTL expiry.

If webhooks are not configured, users can still press **Refresh** in the UI, which calls `DashboardProvider.refresh()` to force re‑fetch results from the backend (bypassing older cache entries as necessary).

---

### 4. CI/CD & Deployment (Conceptual)

The monorepo is set up for **separate frontend and backend pipelines**, as described in the root `README.md` and `.github/workflows/*.yml`:

- Backend pipeline:
  - Installs dependencies.
  - Type‑checks and builds the TypeScript backend.
  - Deploys to Cloudflare Workers using Wrangler (or to another Node runtime, depending on your environment configuration).
- Frontend pipeline:
  - Runs `flutter pub get`.
  - Builds Flutter Web (`flutter build web --release`).
  - Deploys the contents of `build/web` to a static host (e.g., Cloudflare Pages).

The exact host and credentials (e.g., `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID`, `API_BASE_URL`) are set as Actions **secrets** and **variables** in the GitHub repository settings.

---

### 5. Observability & Troubleshooting

#### 5.1 Backend Logs

The backend uses `pino` for structured logging:

- On startup:
  - Logs private‑key diagnostics.
  - Logs DI container build and server listen information.
- During runtime:
  - `ReposService` and `MetricsService` log:
    - Cache hits/misses.
    - Fetched counts and enrichment progress.
  - `CacheService` logs cache failures as warnings.
  - `RateLimitGuard` logs when GitHub rate limit is low and when it waits.
- The error handler plugin logs unhandled exceptions and returns normalized error responses.

#### 5.2 Common Issues

See the **Troubleshooting** sections in `README.md` and `backend/README.md` for:

- Private key format/OpenSSL errors.
- Missing GitHub App configuration.
- Webhook not firing or cache not invalidating.
- CORS or API URL mismatch problems in development.

---

### 6. How to Safely Extend the System

When adding new features or metrics:

1. **Backend first**:
   - Extend `PrMetric` in `core/types.ts` if new raw data is required.
   - Update `metrics.mapper.ts` to compute and populate the new field.
   - Optionally create a new module under `src/modules/<feature>` for additional endpoints.
2. **Frontend data & domain**:
   - Update DTOs in `lib/data/models/pr_model.dart` to parse the new JSON field(s).
   - Extend `PrEntity` or add new entities/services as needed.
3. **Presentation**:
   - Wire the new metrics into `DashboardProvider` (or another provider).
   - Build new widgets/pages to visualize the data, using the existing design system.

The clean layering (backend modules + frontend domain/data/presentation) helps keep these changes localized and testable. 

