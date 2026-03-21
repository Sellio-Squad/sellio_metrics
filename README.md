<div align="center">

# 📊 Sellio Metrics

**A full-stack GitHub PR analytics platform for engineering teams**

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![TypeScript](https://img.shields.io/badge/TypeScript-5.x-3178C6?logo=typescript&logoColor=white)](https://www.typescriptlang.org)
[![Cloudflare Workers](https://img.shields.io/badge/Cloudflare_Workers-F38020?logo=cloudflare&logoColor=white)](https://workers.cloudflare.com)
[![Workers KV](https://img.shields.io/badge/Workers_KV-F38020?logo=cloudflare&logoColor=white)](https://developers.cloudflare.com/kv/)
[![Cloudflare Pages](https://img.shields.io/badge/Cloudflare_Pages-F38020?logo=cloudflare&logoColor=white)](https://pages.cloudflare.com)
[![GitHub App](https://img.shields.io/badge/GitHub_App-Authenticated-181717?logo=github&logoColor=white)](https://docs.github.com/en/apps)
[![CI/CD](https://img.shields.io/badge/CI%2FCD-GitHub_Actions-2088FF?logo=githubactions&logoColor=white)](https://github.com/features/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

*Track pull requests, review velocity, team performance, and collaboration patterns — all in one beautiful dashboard deployed on Cloudflare's edge network.*

---

[🚀 Features](#-features) · [🏗️ Architecture](#️-architecture) · [🛠️ Tech Stack](#️-tech-stack) · [⚡ Quick Start](#-quick-start) · [☁️ Deployment](#️-deployment) · [🔌 API](#-api-reference)

</div>

---

## 🚀 Features

| Feature | Description |
|---------|-------------|
| 📈 **PR Metrics Dashboard** | Open/merged/closed counts, velocity trends, weekly activity charts |
| 🏆 **Team Leaderboard** | Ranked team members by merged PRs, reviews, comments, and code volume |
| 👥 **Team Members Status**| Real-time active/inactive status based on organization activity |
| 🔥 **Team Spotlights** | Hot streaks, fastest reviewers, top commenters |
| ⏱️ **Review Velocity** | Time-to-first-review, time-to-merge, reviewer load analytics |
| 🐢 **Bottleneck Detection** | Slow PRs ranked by wait time with severity coloring |
| 🧩 **PR Type Distribution** | Feature / Fix / Refactor / Chore breakdown via title conventions |
| 📊 **Code Volume** | Additions vs deletions per week with stacked bar charts |
| 📹 **Google Meet Integration**| Create and end meetings directly, track attendees and analytics |
| 🔄 **Real-Time Webhooks** | GitHub webhooks invalidate cache — new PRs appear immediately |
| 🌍 **Bilingual (EN/AR)** | Full localization with RTL support |
| 🎨 **Dark/Light Theme** | Custom design system with smooth theme transitions |
| 📱 **Responsive** | Sidebar on desktop, bottom nav on mobile, adaptive layouts |
| ⚡ **Edge-Deployed** | Backend on Cloudflare Workers (0ms cold start), frontend on Pages |

---

## 🏗️ Architecture & Design Deep Dive

### 1) System Architecture Overview

```mermaid
graph TD
    User([Developer User])
    GitHubWeb([GitHub Webhooks])
    PubSub([Google Cloud Pub/Sub])
    
    subgraph Edge ["Cloudflare Edge Network"]
        SPA[Flutter Web SPA<br/>Cloudflare Pages]
        API[Hono Router + DI<br/>Cloudflare Worker]
    end
    
    subgraph Store ["Cloudflare Serverless Persistence"]
        KV[(Workers KV<br/>Caches & Auth)]
        D1[(D1 SQLite<br/>Relational Log)]
        Queue>Cloudflare Queue<br/>Async Job Queue]
    end
    
    subgraph External ["External APIs"]
        GHAPI[GitHub REST API]
        MeetAPI[Google Meet API]
    end
    
    User -->|Views Dashboards/HTTPS| SPA
    SPA -->|JSON Queries| API
    GitHubWeb -->|Sends Event Streams| API
    PubSub -->|Pushes Workspace Events| API
    
    API <--> KV
    API <--> D1
    API -->|Submit Background Job| Queue
    Queue -->|Consume & Compute| API
    
    API -->|App Auth / JWT| GHAPI
    API -->|OAuth2 Tokens| MeetAPI
    
    classDef External fill:#2D3748,color:#fff,stroke:#4A5568
    classDef Edge fill:#C05621,color:#fff,stroke:#9C4221
    classDef Store fill:#2B6CB0,color:#fff,stroke:#2C5282
    
    class External External
    class Edge Edge
    class Store,KV,D1,Queue Store
```

**System Purpose:**  
Sellio Metrics is a full-stack engineering operations platform designed to measure and visualize engineering team velocity. It tracks pull requests, reviewer engagement, code collaboration patterns, team activity, and meeting durations. The platform operates completely on the edge to provide real-time dashboards with extremely low latency.

**Main Features:**
- **PR Tracking & Analytics:** Real-time visibility into open/merged pull requests, code volume (additions/deletions), PR classifications (features, chores, bugs), and bottlenecks (stale PRs).
- **Leaderboards & Gamification:** Points-based system tracking merged PRs, code contributions, review activity, and attendance.
- **Team Activity Status:** Real-time visibility into active/inactive team members based on organization engagement.
- **Meeting Lifecycles:** Google Meet integration for creating, tracking duration (via explicit check-in/out), and automatically terminating meetings.
- **Real-Time Data Sync:** Webhook-driven invalidation and background recalculation of metrics.

**Main Actors:**
- **Developers / Users:** The engineering team using the Flutter web frontend to monitor performance.
- **GitHub API:** Source of truth for all repository, PR, and engagement metrics via authenticated App connections.
- **Google Meet API & Workspace Events:** Handles meeting creation, OAuth2 user consent, and pushes real-time event notifications via Google Cloud Pub/Sub.
- **Infrastructure (Cloudflare Edge):** Powers execution, caching, and serving.

**Architecture Style:**  
**Edge-Native Modular Monolith (Serverless) + Single Page Application (SPA)**

**Reasoning:**
- **Codebase Analysis Structure:** The backend is packaged as a single deployable Cloudflare Worker (`backend/src/worker.ts`), routing requests using Hono via distinct feature modules (`/api/repos`, `/api/prs`, etc.). Because it is deployed as a single runtime rather than distributed decoupled services, it functions as a monolith. However, internally it utilizes Awilix Dependency Injection and Clean Architecture to keep the service execution completely modular (resembling a Micro-Modular Monolith).  
- **Edge Deployment First:** The system delegates standard long-running service capabilities to serverless edge equivalents: D1 (relational data), KV (edge caching), and Cloudflare Queues (asynchronous message queuing).

**Boundaries:**
- **Frontend ⟷ API Layer:** Secured HTTPS REST communication. The UI requests parsed JSON aggregates; does not understand where data originates.
- **API Router ⟷ Service Layer:** The boundary enforced by the DI Container. Routes orchestrate input (Hono request parsing) and pass POJOs to strictly-typed domain services.
- **Service Layer ⟷ External Dependencies (DB, Cache, GitHub):** Business logic interacts only with unified Repositories or Client abstractions (`GitHubClient`, `CacheService`).

---

### 2) Core Components & Backend Modules

```mermaid
graph TB
    subgraph HTTP ["HTTP & Router Boundary (worker.ts)"]
        Controller[Hono Middleware & Route Endpoints]
    end
    
    subgraph Services ["Business Domain"]
        RepServ(Repos Service)
        PrServ(PRs Metrics Service)
        LeadServ(Score Aggregation Subsystem)
        HookServ(Webhook Ingest Orchestrator)
        MeetServ(Meeting Lifecycle Tracker)
        MeetEventsServ(Google PubSub Event Handler)
    end
    
    subgraph Repositories ["Data Storage Interfaces"]
        RepoD1(SQLite Query Builders)
        CacheSV(Namespaced Edge KV Store)
    end
    
    subgraph Infra ["Infrastructure Wrappers"]
        GHClient[Rate-Limited GitHub App Client]
        GoogAuth[Google Tokens & Endpoints]
        WsClient[Workspace Events Client]
    end
    
    Controller -.-> RepServ & PrServ & LeadServ & HookServ & MeetServ & MeetEventsServ
    
    RepServ & PrServ -.-> GHClient
    RepServ & PrServ -.-> RepoD1 & CacheSV
    
    HookServ -.-> RepoD1
    HookServ -.-> |Invalidates| CacheSV
    
    MeetEventsServ -.-> WsClient
    MeetEventsServ -.-> |Push Decoded Payload| CacheSV
    
    LeadServ -.-> RepoD1 & CacheSV
    
    MeetServ -.-> GoogAuth
    MeetServ -.-> RepoD1 & CacheSV
```

#### Frontend (Flutter Web)
- **Presentation Layer (Pages & Widgets):** Displays the UI (e.g., Hux Design System charts, Leaderboards).
- **Providers (State Management):** Co-located reactive state handlers that orchestrate fetching data and updating the UI.
- **Domain Layer (Entities & Services):** Contains business object representations (`BottleneckEntity`, `PrEntity`) and rules (NO UI dependencies).
- **Data Layer (Repositories & RemoteDataSources):** Implements interfaces defined by the Domain to fetch data from the REST API.

#### Backend (Cloudflare Workers)
- **Hono Router:** Entry point that applies CORS, parses requests, and delegates endpoints to specific feature modules.
- **Service Layer (Feature Modules):**
  - **Metrics & Repos Services:** Uses Git client to fetch organization state and caches the results.
  - **ScoreAggregationService:** Aggregates PR, code, and attendance data into leaderboard structures.
  - **Attendance & Meetings Service:** Handles checking in/out of meetings via `ATTENDANCE_KV` and Google APIs.
  - **MeetEventsService:** Subscribes Spaces to Workspace Events and ingests pushes via Google Cloud Pub/Sub (`WEBHOOK_QUEUE` / `/api/meet-events/webhook`) to track real-time participant joins, drops, and durations.
  - **WebhookService:** Ingests external GitHub triggers and delegates caching invalidation / point creation.
- **Infrastructure Integrations (Octokit + D1):**
  - **D1 Service**: Abstracted query builder for SQLite interacting with `merged_prs`, `pr_comments`, etc.
  - **CachedGitHubClient:** Wrapper around Octokit resolving App Auth (JWT to temporary access token), enforcing Rate Limit protections.

**Backend Endpoint Organization:**
- **System:** `/api/health`, `/api/logs`, `/api/debug` (telemetry and connectivity).
- **GitHub Sync:** `/api/repos`, `/api/prs`, `/api/sync/github`, `/api/webhooks` (system automation boundary).
- **User Activity:** `/api/scores`, `/api/points`, `/api/members` (Leaderboards & organization states).
- **Meetings/Attendance:** `/api/meetings`, `/api/meet-events`, `/api/attendance` (Temporal lifecycle management).

**Services / Business Logic:**
- Strict `Controller -> Service -> Mapper -> Result` pipeline. Mappers are explicitly isolated as pure functions without dependencies.
- Score derivation relies entirely on SQL aggregations (`SUM(r.points) JOIN point_rules`) instead of hardcoding points natively in the `merged_prs` tables.

**Background Workers (Cron & Queues):**
- **Cron:** Bound in `worker.ts`'s `scheduled()` export. Executes `precomputeSnapshots()` continuously to ensure high data-heavy queries do not impact normal user navigation times.
- **Queue Consumers:** Built-in Cloudflare Queues bound to `queue()` in `worker.ts` handle asynchronous message batches, specifically mapping `recompute_scores` so immediate user operations aren't blocked.

**Performance & Resiliency:**
- **Caching:** Distributed KV edge caching across 4 namespaces (`CACHE`, `SCORES_KV`, `MEMBERS_KV`, `ATTENDANCE_KV`).
- **Rate Limiting:** Managed implicitly through aggressive caching (reducing upstream dependency) combined with `RateLimitGuard` built into the `CachedGitHubClient`.
- **Error Handling:** Standardized error handler translating exceptions (`GitHubApiError`, `RateLimitError`) into unified JSON constructs (`message`, `statusCode`).
- **Retries:** The Queueing interface handles failures natively using standard Cloudflare retries (`msg.retry()`).

---

### 3) Webhook Handling & Data Flow Context

```mermaid
sequenceDiagram
    participant GitHub
    participant Worker HTTP
    participant Webhook Service
    participant D1 Relational
    participant Queue
    participant Background CPU
    participant Cache
    
    GitHub->>Worker HTTP: POST /api/webhooks (PR Merged Content)
    Worker HTTP->>Webhook Service: Forward JSON Body
    Webhook Service->>D1 Relational: INSERT OR IGNORE merged_prs (Idempotent)
    D1 Relational-->>Webhook Service: Inserted successfully
    Webhook Service->>Queue: Submit Job: { type: 'recompute_scores' }
    Webhook Service-->>Worker HTTP: Yield Control Flow
    Worker HTTP-->>GitHub: HTTP 202 Accepted (Fast Return)
    
    Note over Queue, Cache: Asynchronous Background Execution
    
    Queue-->>Background CPU: Process Batch Job (Queue Consumer)
    Background CPU->>D1 Relational: RUN SUM(points) Query Aggregation
    D1 Relational-->>Background CPU: Raw Score Values
    Background CPU->>Cache: Set Key `sellio:leaderboard:all` (TTL 6H)
```

```mermaid
flowchart LR
    Origin[GitHub State Changes] --> |Webhooks| IngestLayer[Webhook Route]
    IngestLayer --> |Normalize / Pure Mapping| DBStore[(D1 Relational Entities)]
    
    Client[Flutter Frontend UI] --> |GET /api/scores| ScoreLayer[Score Calculation]
    
    DBStore --> |SQL JOIN points_rules| ScoreLayer
    ScoreLayer --> |Cache Read / Write| KVCache[(Workers KV Snapshots)]
    
    KVCache --> |JSON Return Payload| Client
    
    Client2[Metrics Dashboard UI] --> |GET /api/prs| PrLayer[PR Fetch Controller]
    PrLayer --> |Fall through Cache| ExternalApi[GitHub REST API]
    ExternalApi --> |JSON Data| PrLayer
    PrLayer --> Client2
```

Data flows sync for user queries, and async for system updates.

- **Synchronous User Query (e.g., Load Dashboard):**
  1. Frontend requests `/api/metrics/repo`.
  2. Worker queries `CACHE` KV namespace.
  3. **Cache Hit:** Return JSON immediately (< 20ms).
  4. **Cache Miss:** Request App token -> Fetch from GitHub API -> Transform via pure Mapping layer -> Write to KV with 1hr TTL -> Return to client.

- **Asynchronous Webhooks (Event-Driven Updates):**
  1. Developer interacts with GitHub (merges a PR) or joins a Google Meet.
  2. GitHub Webhook POSTs to `/api/webhooks` / Google Cloud Pub/Sub POSTs to `/api/meet-events/webhook`.
  3. Webhook worker writes to the D1 database (idempotent `INSERT OR IGNORE`) or caches the Meet Event into `EVENTS_CACHE_KEY` limit 200 items.
  4. Worker queues a background task to `WEBHOOK_QUEUE` indicating caching should be invalidated.
  5. The queue consumer picks up the event and triggers backend recomputation / cache dropping.

- **Chronological / Background Jobs:**
  1. A Cron schedule hits `scheduled(ScheduledEvent)` running naturally every 6 hours.
  2. Worker precomputes massive queries (e.g., All Time Leaderboard Snapshot) and drops them in `SCORES_KV`.

**Important Design Decisions:**
- **Execution over Storage:** The system avoids computing rigid scores synchronously. `merged_prs` is an immutable log. "Points" are deduced dynamically in `SCORES_KV` using `point_rules`. Upgrading point calculations for past behavior only requires changing rule tables.
- **Cloudflare V8 Isolates:** Relying on Cloudflare Workers guarantees sub-millisecond cold starts globally without warming layers, perfect for dashboard analytics.
- **Dependency Rule:** Enters strict boundary constraints utilizing `Awilix` proxy mode scopes. Domain functions cannot import framework-level HTTP constructs, which means the domain logic is runtime-agnostic.
- **Temporal Decoupling:** Instead of synchronous webhook processing, Webhooks issue state insertions to DB and hand invalidations off to Queues. Immediate GitHub API success is returned to avoid GitHub timeout dropping.

---

### 4) Deployment, Frontend & Integrations

```mermaid
graph TD
    node1["Developer Machine"]
    
    subgraph GitHubPipelines ["CI/CD Execution Environment"]
        act1["Actions: Flutter UI Builder"]
        act2["Actions: TypeScript Transpiler"]
    end
    
    subgraph Prod ["Cloudflare Global Edge"]
        subgraph DNS ["Anycast Routing Network"]
            page["Cloudflare Pages<br/>(Statics)"]
            work["Cloudflare Worker Runtime<br/>(Isolates)"]
        end
        d1["D1 (SQLite Distributed Hub)"]
        kv["Workers KV Edge Nodes"]
    end
    
    node1 -->|Push Code| GitHubPipelines
    act1 -->|Upload Artifacts| page
    act2 -->|Deploy via Wrangler| work
    
    page -->|Rest API Cross-Origin| work
    work --> d1 & kv
```

**External Integrations:**
- **GitHub App API:** Core engine source. Used to query Repos, PRs, comments, additions, and review lifecycle stages. Relies on App private keys (JWT payload) mapped to installation tokens.
- **Google Authenticator (OAuth2):** Handles user consent required to generate calendar/meeting links.
- **Google Meet API (REST v2) & Workspace Events:** Used via authenticated endpoints to initialize video chat instances dynamically and administratively close spaces. Leverages Google Cloud Pub/Sub to push real-time participant/meeting lifecycle events.

**Frontend State Management & UI:**
- **App Pattern:** Relies on Provider mapped conceptually by feature boundary (e.g., Dashboard metrics are bound to a singular domain Provider component).
- **API Communication pattern:** Widgets consume DI-registered `IMetricsRepository` implementations, ensuring the UI remains completely isolated from the HTTP layer. Data deserialization occurs at the boundaries parsing clean `Entities`.
- **UI:** Designed symmetrically utilizing the `Hux Design System`. Fully i18n standardized supporting both Left-to-Right English and Right-to-Left Arabic. Relies heavily on cached backend aggregates to immediately load without skeleton screen fatigue.

---

### 5) Database Design (ER)

```mermaid
erDiagram
    REPOS ||--o{ MERGED_PRS : contains
    MEMBERS ||--o{ MERGED_PRS : authors
    MERGED_PRS ||--o{ PR_COMMENTS : receives
    MEMBERS ||--o{ PR_COMMENTS : comments
    MEETING_SESSIONS ||--o{ MEETING_ATTENDANCE : hosts
    MEMBERS ||--o{ MEETING_ATTENDANCE : attends
    
    REPOS {
        int id PK
        string owner 
        string name 
        string pushed_at 
    }
    
    MEMBERS {
        string login PK 
        string display_name 
        string avatar_url 
    }
    
    MERGED_PRS {
        int id PK 
        int pr_number 
        string author FK 
        int repo_id FK 
        int additions 
        int deletions 
        datetime merged_at 
    }
    
    PR_COMMENTS {
        int id PK
        int pr_id FK 
        string author FK
        string comment_type
    }
    
    MEETING_ATTENDANCE {
        string id PK
        string developer_login FK
        string session_id FK
        int duration_minutes
    }
    
    POINT_RULES {
        string event_type PK
        float points 
        string description 
    }
```

The Cloudflare D1 (SQLite) instance forms an idempotent registry tracking historical engineering milestones.

- `repos` (1) ─━ (N) `merged_prs`
- `members` (1) ─━ (N) `merged_prs` (Author)
- `merged_prs` (1) ─━ (N) `pr_comments`
- `meeting_sessions` (1) ─━ (N) `meeting_attendance`
- `point_rules` (Dictionary table mapping Event Name -> Points -> Description)

Data is strictly normalized. Bots are excluded upstream upon ingest, eliminating noise from `is_bot` queries. Additions, deletions, statuses, bodies, and creation times are maintained natively for analytics processing.

---

## 🛠️ Tech Stack

### Backend
| Technology | Purpose |
|-----------|---------|
| **TypeScript** | Type-safe API development |
| **Cloudflare Workers** | Serverless edge compute (0ms cold start, 100k+ req/day free) |
| **Workers KV** | Edge-distributed caching with TTL (100k reads/day free) |
| **Cloudflare D1** | Serverless SQLite relational database accessed via the Repository Pattern |
| **Hono** | Ultrafast, lightweight web framework built for Edge runtimes |
| **Awilix** | Dependency injection (PROXY mode, scoped lifetimes) |
| **Octokit** | GitHub REST API client with App authentication |
| **GitHub App Auth** | JWT → Installation token (5,000 req/hr, auto-refresh) |
| **Google Meet API**| Native REST API via `fetch` (Cloudflare Worker compatible) |
| **Google Auth Library**| Managing OAuth2 user consent flow and handling permissions |

### Frontend
| Technology | Purpose |
|-----------|---------|
| **Flutter Web** | Cross-platform UI framework |
| **Provider** | Reactive state management |
| **Hux Design System** | Custom component library (badges, buttons, charts, sidebar) |
| **Lucide Icons** | Modern icon set |
| **AppLocalizations** | Built-in i18n (English + Arabic with RTL) |

### Infrastructure
| Technology | Purpose |
|-----------|---------|
| **Cloudflare Pages** | Static site hosting with global CDN |
| **GitHub Actions** | Separate CI/CD pipelines for frontend and backend |
| **GitHub Webhooks** | Real-time cache invalidation on PR events |

---

## ⚡ Quick Start

### Prerequisites

| Tool | Version | Link |
|------|---------|------|
| Node.js | 22+ | [nodejs.org](https://nodejs.org) |
| Flutter | 3.x | [flutter.dev](https://flutter.dev/docs/get-started/install) |
| Wrangler CLI | 4.x | `npm i -g wrangler` |
| GitHub App | — | [Create one](https://docs.github.com/en/apps/creating-github-apps) |

### 1. Clone & Install

```bash
git clone https://github.com/Sellio-Squad/sellio_metrics.git
cd sellio_metrics

# Backend
cd backend && npm install

# Frontend
cd ../frontend && flutter pub get
```

### 2. Configure Backend

```bash
cd backend
cp .env.example .env
```

Edit `.env`:
```env
APP_ID=123456
INSTALLATION_ID=12345678
GITHUB_ORG=Sellio-Squad

# Paste your private key with literal \n for line breaks:
APP_PRIVATE_KEY="-----BEGIN RSA PRIVATE KEY-----\nMIIEpAIB...\n-----END RSA PRIVATE KEY-----"

# Google Meet Credentials
GOOGLE_CLIENT_ID=your_oauth2_client_id.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=your_oauth2_client_secret
GOOGLE_REDIRECT_URI=https://sellio-metrics.abdoessam743.workers.dev/api/meetings/oauth2callback
```

> **💡 Private Key Tip (PowerShell):**
> ```powershell
> (Get-Content backend\github-app.pem -Raw).Replace("`r`n", "\n").Replace("`n", "\n")
> ```
> Copy the output and paste as `APP_PRIVATE_KEY` value.

### 3. Run Locally

**Terminal 1 — Backend** (starts at `http://localhost:3001`):
```bash
cd backend
npm run dev
```

**Terminal 2 — Frontend** (opens in Chrome):
```bash
cd frontend
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:3001
```

### 4. Verify

```bash
# Health check
curl http://localhost:3001/api/health
# → {"status":"ok","org":"Sellio-Squad","timestamp":"..."}

# Repos list
curl http://localhost:3001/api/repos

# PR metrics
curl "http://localhost:3001/api/metrics/Sellio-Squad/sellio_mobile?state=all"
```

---

## ☁️ Deployment

Both frontend and backend deploy automatically via **GitHub Actions** when changes are pushed to `main`.

### Pipeline Overview

| Push changes to... | Frontend deploys? | Backend deploys? |
|---|---|---|
| `frontend/` | ✅ | ❌ |
| `backend/` | ❌ | ✅ |
| Both | ✅ | ✅ |

### One-Time Setup

#### 1. Cloudflare API Token
1. [dash.cloudflare.com/profile/api-tokens](https://dash.cloudflare.com/profile/api-tokens) → **Create Token**
2. Permissions: `Cloudflare Pages: Edit`, `Workers Scripts: Edit`, `Workers KV Storage: Edit`

#### 2. Create KV Namespace
```bash
cd backend
npx wrangler kv namespace create CACHE
```
Copy the `id` into `backend/wrangler.toml`.

#### 3. Set Worker Secrets
```bash
cd backend
npx wrangler secret put APP_ID
npx wrangler secret put INSTALLATION_ID
npx wrangler secret put APP_PRIVATE_KEY
npx wrangler secret put GOOGLE_CLIENT_ID
npx wrangler secret put GOOGLE_CLIENT_SECRET
```

#### 4. GitHub Repository Settings

**Secrets** (Settings → Secrets → Actions):
| Name | Value |
|------|-------|
| `CLOUDFLARE_API_TOKEN` | Your API token |
| `CLOUDFLARE_ACCOUNT_ID` | Your account ID |

**Variables** (Settings → Variables → Actions):
| Name | Value |
|------|-------|
| `API_BASE_URL` | `https://your-worker.workers.dev` |

#### 5. GitHub Webhook (for real-time PR updates)
1. Go to your GitHub App settings → **Webhooks**
2. **Webhook URL**: `https://your-worker.workers.dev/api/webhooks/github`
3. **Content type**: `application/json`
4. **Events**: Select `Pull requests`, `Pull request reviews`, `Issue comments`, `Pull request review comments`

When a PR is opened/merged/reviewed, the webhook invalidates the cached metrics, so the dashboard shows changes immediately.

#### 6. Push & Deploy
```bash
git add -A
git commit -m "deploy: initial production deployment"
git push origin main
```

---

## 🔌 API Reference

**Production**: `https://sellio-metrics.abdoessam743.workers.dev`  
**Local**: `http://localhost:3001`

### `GET /api/health`
Server health check.

```json
{ "status": "ok", "org": "Sellio-Squad", "timestamp": "2026-02-28T15:21:48Z" }
```

### `GET /api/repos`
List all organization repositories.

```json
{
  "org": "Sellio-Squad",
  "count": 6,
  "repos": [{ "name": "sellio_mobile", "full_name": "Sellio-Squad/sellio_mobile", ... }]
}
```

### `GET /api/metrics/:owner/:repo`
Fetch PR metrics for a repository.

| Param | Type | Default | Description |
|-------|------|---------|-------------|
| `state` | `string` | `all` | `open`, `closed`, `all` |
| `per_page` | `number` | `100` | Results per page |

```json
{
  "owner": "Sellio-Squad",
  "repo": "sellio_mobile",
  "count": 127,
  "metrics": [{ "prNumber": 42, "title": "feat: checkout flow", "state": "merged", ... }]
}
```

### `POST /api/metrics/leaderboard`
Calculate leaderboard from PR data (sent in body).

### `GET /api/meetings/auth-url`
Retrieves the target Google OAuth2 login link for Google Meet consent page.

### `GET /api/meetings/auth-status`
Checks if the backend currently possesses a valid Google OAuth2 token.

### `POST /api/meetings/auth-logout`
Clears the current Google OAuth2 tokens from persistent storage.

### `POST /api/meetings`
Creates a brand new Google workspace, returning the direct link to jump into the call. Only works if authenticated.

### `POST /api/meetings/:id/end`
Removes all users and terminates an ongoing meeting via the Google Meet infrastructure.

### `POST /api/members/status`
Returns activity status (Active/Inactive) for all organization members.

### `POST /api/webhooks/github`
GitHub webhook endpoint — invalidates cached metrics on PR events.

---

## 📁 Project Structure

```
sellio_metrics/
├── .github/workflows/
│   ├── deploy-frontend.yml    ← Flutter build → Cloudflare Pages
│   └── deploy-backend.yml     ← Type check → Cloudflare Workers
│
├── backend/                   ← TypeScript API (Cloudflare Workers)
│   ├── src/
│   │   ├── config/env.ts      ← Validated environment config
│   │   ├── core/              ← DI container, errors, logger, types
│   │   ├── infra/
│   │   │   ├── cache/         ← CacheService (Workers KV)
│   │   │   └── github/        ← GitHubClient, CachedGitHubClient, RateLimitGuard
│   │   ├── modules/
│   │   │   ├── health/        ← GET /api/health
│   │   │   ├── repos/         ← GET /api/repos
│   │   │   ├── metrics/       ← GET /api/metrics/:owner/:repo
│   │   │   ├── leaderboard/   ← POST /api/metrics/leaderboard
│   │   │   └── webhook/       ← POST /api/webhooks/github
│   │   └── worker.ts          ← Workers entry point (router + handlers)
│   ├── wrangler.toml          ← Workers + KV config
│   └── package.json
│
└── frontend/                  ← Flutter Web (Cloudflare Pages)
    └── lib/
        ├── core/              ← Constants, extensions, l10n, navigation, theme
        ├── design_system/     ← Hux component barrel exports
        ├── domain/            ← Entities, repositories (interfaces), services
        ├── data/              ← Models, datasources, repository implementations
        └── presentation/      ← Pages, providers, widgets
```

---

## 🔐 Environment Variables

### Backend (Cloudflare Worker Secrets)

| Variable | Required | Description |
|----------|----------|-------------|
| `APP_ID` | ✅ | GitHub App ID |
| `APP_PRIVATE_KEY` | ✅ | RSA private key (PKCS#8 PEM) |
| `INSTALLATION_ID` | ✅ | GitHub App installation ID |
| `GOOGLE_CLIENT_ID`| ✅ | Google OAuth2 Client ID |
| `GOOGLE_CLIENT_SECRET`| ✅ | Google OAuth2 Client Secret |

### Backend (wrangler.toml vars)

| Variable | Default | Description |
|----------|---------|-------------|
| `GITHUB_ORG` | `Sellio-Squad` | Organization name |
| `GOOGLE_REDIRECT_URI`| `/api/meetings/oauth2callback` | URI Google uses after user consent |
| `LOG_LEVEL` | `info` | `trace`, `debug`, `info`, `warn`, `error` |
| `NODE_ENV` | `production` | Environment |

### Frontend (compile-time)

| Variable | Default | Description |
|----------|---------|-------------|
| `API_BASE_URL` | `http://localhost:3001` | Backend URL, passed via `--dart-define` |

---

## 🧩 Design Decisions

| Decision | Rationale |
|----------|-----------|
| **Cloudflare Workers** over traditional server | 0ms cold start, free tier (100k req/day), global edge deployment |
| **Workers KV** over Redis | Free tier, no server to manage, edge-distributed, built-in TTL |
| **GitHub App** over PAT | 5,000 req/hr, org-level access, auto-rotating tokens |
| **Awilix DI** | No decorators, PROXY mode, scoped lifetimes, easy testing |
| **Provider** over Bloc/Riverpod | Lower boilerplate for dashboard use-case, native Flutter integration |
| **Separate CI/CD** | Frontend and backend deploy independently — faster feedback loops |

---

## 🐛 Troubleshooting

<details>
<summary><b>Private key error: <code>unsupported</code></b></summary>

Convert your RSA key to PKCS#8:
```bash
openssl pkcs8 -topk8 -inform PEM -outform PEM -nocrypt -in private-key.pem -out private-key-pkcs8.pem
```
Then set the PKCS#8 key as `APP_PRIVATE_KEY`.
</details>

<details>
<summary><b>New PRs don't appear</b></summary>

1. Ensure the GitHub webhook is configured (see [Deployment → Step 5](#5-github-webhook-for-real-time-pr-updates))
2. Or use the **Refresh** button in the dashboard to force re-fetch
3. Check KV cache TTL — cached results expire automatically based on TTL
</details>

<details>
<summary><b>CORS errors in development</b></summary>

Make sure you pass `--dart-define=API_BASE_URL=http://localhost:3001` when running Flutter.
The Worker includes `Access-Control-Allow-Origin: *` on all responses.
</details>

<details>
<summary><b>Flutter <code>gen-l10n</code> not generating</b></summary>

Ensure `pubspec.yaml` has `flutter: generate: true` and run from `frontend/` directory.
</details>

---

## 📄 License

MIT — see [LICENSE](LICENSE) for details.

---

<div align="center">

Built with ❤️ by the **Sellio Squad**

*Measure what matters. Ship with confidence.*

</div>
