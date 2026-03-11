# 🏛️ Sellio Metrics — Architecture Deep Dive

This document provides detailed architecture diagrams for every layer of the system.

---

## 1. System Context

```mermaid
graph TB
    Dev["👨‍💻 Developer<br/>(Sellio Squad)"]
    Frontend["📊 Sellio Metrics<br/>Cloudflare Pages (Flutter)"]
    Backend["⚡ Cloudflare Worker<br/>TypeScript API"]
    GitHub["🐙 GitHub API<br/>REST v3"]
    GHApp["🔑 GitHub App<br/>(Auth + Tokens)"]
    Google["🎬 Google Meet API<br/>REST v2"]
    D1["🗄️ Cloudflare D1<br/>(SQLite Events)"]

    Dev -->|"views metrics"| Frontend
    Frontend -->|"HTTPS /api/*"| Backend
    Backend -->|"paginate/list"| GitHub
    Backend -->|"JWT → token"| GHApp
    GHApp -->|"access token (1hr)"| GitHub
    Backend -->|"OAuth2 → create/end"| Google
    Backend <-->|"events, scores"| D1
```

---

## 2. Backend Layer Architecture

```mermaid
graph TD
    subgraph HTTP["🌐 Router (Worker Entry)"]
        R1["GET /api/health"]
        R2["GET /repo/*"]
        R3["GET /api/metrics/*"]
        R4["/api/meetings/*"]
        R5["/api/members/*"]
        CORS[" CORS & Auth Middleware"]
    end

    subgraph DI["⚙️ Awilix DI Container"]
        C["container.register({<br/>  env, logger,<br/>  githubClient,<br/>  reposService,<br/>  metricsService<br/>})"]
    end

    subgraph Services["🧠 Service Layer"]
        RS["ReposService<br/>(KV Cached)"]
        MS["MetricsService<br/>(Repo Analytics)"]
        ME["MeetingsService<br/>(Google LifeCycle)"]
        MB["MembersService<br/>(Status Analysis)"]
    end

    subgraph Mapper["🗺️ Mapper Layer"]
        MM["metrics.mapper.ts<br/>(pure functions)"]
    end

    subgraph Infra["🔧 Infrastructure"]
        GC["GitHubClient<br/>(Octokit + App Auth)"]
    end

    subgraph Core["💎 Core"]
        ERR["AppError hierarchy"]
        LOG["Pino Logger"]
        TYPES["Domain Types"]
        DATE["Date Utils"]
    end

    R2 --> RS
    R3 --> MS
    RS --> DI
    MS --> DI
    DI --> GC
    MS --> MM
    MM --> TYPES
    GC --> LOG

    style HTTP fill:#1e3a5f,stroke:#2563eb,color:#fff
    style DI fill:#3d2b69,stroke:#7c3aed,color:#fff
    style Services fill:#1a3d30,stroke:#16a34a,color:#fff
    style Mapper fill:#3d3000,stroke:#d97706,color:#fff
    style Infra fill:#3d1a1a,stroke:#dc2626,color:#fff
    style Core fill:#1a1a3d,stroke:#6366f1,color:#fff
```

---

## 3. PR Metrics Data Flow (Sequence)

```mermaid
sequenceDiagram
    participant F as Flutter App
    participant B as Cloudflare Worker
    participant KV as Workers KV
    participant G as GitHub API

    F->>B: GET /api/metrics/...
    B->>KV: Check Cache (sellio:metrics:...)
    
    alt Cache Hit
        KV-->>B: return JSON
    else Cache Miss
        B->>G: GitHub App Auth
        B->>G: Fetch PRs & Enrichment
        G-->>B: data
        B->>B: Transform (Mapper)
        B->>KV: Save result (1hr TTL)
    end

    B-->>F: HTTP 200 { metrics[] }
    F->>F: Re-render UI with Provider
```

---

## 4. Frontend State Architecture

```mermaid
graph LR
    subgraph UI["🎨 Presentation Layer"]
        P1["AnalyticsPage"]
        P2["DashboardPage"]
        P3["ChartsPage"]
        P4["TeamPage"]
        P5["OpenPRsPage"]
        W1["KpiCard"]
        W2["SpotlightCard"]
        W3["BottleneckItem"]
        W4["LeaderboardCard"]
        W5["PrListTile"]
    end

    subgraph Providers["📦 Providers"]
        DP["DashboardProvider<br/>ChangeNotifier"]
        AP["AppSettingsProvider<br/>ChangeNotifier"]
    end

    subgraph Domain["🏛️ Domain Layer"]
        BS["BottleneckService"]
        SS["SpotlightService"]
        CS["CollaborationService"]
        IR["IMetricsRepository<br/>(interface)"]
    end

    subgraph Data["💾 Data Layer"]
        RI["MetricsRepositoryImpl"]
        DS["RemoteDataSource"]
    end

    P1 & P2 & P3 & P4 & P5 --> DP
    W1 & W2 & W3 & W4 & W5 --> DP
    DP --> BS & SS & CS & IR
    IR -.->|"implements"| RI
    RI --> DS
    DS -->|"HTTP"| B["⚡ Backend API"]

    style UI fill:#1e3a5f,stroke:#2563eb,color:#fff
    style Providers fill:#3d2b69,stroke:#7c3aed,color:#fff
    style Domain fill:#1a3d30,stroke:#16a34a,color:#fff
    style Data fill:#3d1a1a,stroke:#dc2626,color:#fff
```

---

## 5. Clean Architecture Dependency Rule

```mermaid
graph TD
    subgraph presentation["🎨 Presentation Layer"]
        PAGES["Pages & Widgets"]
        PROV["Providers"]
    end

    subgraph domain["🏛️ Domain Layer (NO DEPENDENCIES)"]
        ENT["Entities<br/>PrEntity, BottleneckEntity…"]
        REPO["Repository Interfaces<br/>IMetricsRepository"]
        SVC["Domain Services<br/>SpotlightService, BottleneckService…"]
        ENUM["Enums<br/>PrType, PrStatus"]
    end

    subgraph data["💾 Data Layer"]
        IMPL["Repository Implementations"]
        MODELS["DTO Models"]
        REMOTE["Remote Data Source"]
    end

    subgraph external["🌐 External"]
        API["Backend REST API"]
    end

    PAGES --> ENT
    PAGES --> REPO
    PROV --> SVC
    PROV --> REPO
    IMPL --> REPO
    IMPL --> ENT
    REMOTE --> API

    SVC --> ENT
    SVC --> ENUM

    classDef domainStyle fill:#1a3d30,stroke:#16a34a,color:#fff
    classDef presentationStyle fill:#1e3a5f,stroke:#2563eb,color:#fff
    classDef dataStyle fill:#3d1a1a,stroke:#dc2626,color:#fff
    class ENT,REPO,SVC,ENUM domainStyle
    class PAGES,PROV presentationStyle
    class IMPL,MODELS,REMOTE dataStyle
```

> **🔑 The Dependency Rule:** Source code dependencies must point only **inward**.  
> Domain knows nothing about Presentation or Data. Data knows about Domain (implements its interfaces). Presentation knows about Domain (uses its types and interfaces).

---

## 6. GitHub App Authentication Flow

```mermaid
sequenceDiagram
    participant B as Backend
    participant JWT as JWT Library
    participant G as GitHub

    Note over B: On every API call...
    
    B->>JWT: sign({ iss: APP_ID, exp: now+10min }, privateKey)
    JWT-->>B: jwt_token

    alt Token not cached or expired
        B->>G: POST /app/installations/:id/access_tokens<br/>Authorization: Bearer jwt_token
        G-->>B: { token, expires_at } (1 hour TTL)
        B->>B: cache token until expires_at - 60s
    end

    B->>G: GET /repos/...  Authorization: token {cached_token}
    G-->>B: data
```

---

## 7. Error Handling Architecture

```mermaid
graph TD
    subgraph Sources["Error Sources"]
        GH["GitHub API Error<br/>(4xx, 5xx, network)"]
        VAL["Validation Error<br/>(JSON Schema)"]
        APP["Application Error<br/>(business logic)"]
        UNK["Unknown Error<br/>(unexpected)"]
    end

    subgraph Hierarchy["AppError Hierarchy"]
        BASE["AppError<br/>statusCode, code, message"]
        NF["NotFoundError<br/>404 NOT_FOUND"]
        BR["BadRequestError<br/>400 BAD_REQUEST"]
        GE["GitHubApiError<br/>502 GITHUB_API_ERROR"]
        RE["RateLimitError<br/>429 RATE_LIMITED"]
    end

    subgraph Handler["Central Error Handler Plugin"]
        FEH["Fastify setErrorHandler()"]
    end

    subgraph Response["HTTP Response"]
        JSON["{ error, code, statusCode, message }"]
    end

    GH --> GE
    VAL --> BR
    APP --> NF & BR
    UNK --> BASE

    BASE --> FEH
    NF --> FEH
    BR --> FEH
    GE --> FEH
    RE --> FEH

    FEH --> JSON

    style Hierarchy fill:#3d1a1a,stroke:#dc2626,color:#fff
    style Handler fill:#3d2b00,stroke:#d97706,color:#fff
    style Response fill:#1a3d30,stroke:#16a34a,color:#fff
```

---

## 8. Module Structure (Feature Slice)

Each feature module is a self-contained vertical slice:

```
modules/metrics/
├── metrics.route.ts     ← HTTP boundary (JSON Schema, DI resolution)
│                           knows: Fastify, Cradle, MetricsQuerySchema
│                           does NOT know: GitHub, Octokit
│
├── metrics.service.ts   ← Business orchestration
│                           knows: GitHubClient, domain types
│                           does NOT know: HTTP, response format
│
├── metrics.mapper.ts    ← Data transformation (PURE FUNCTIONS)
│                           knows: RawGitHubPr → PrMetric
│                           does NOT know: services, routes, HTTP
│
└── metrics.types.ts     ← Module-specific types
                            MetricsQueryParams, MetricsResponse
```

```mermaid
graph LR
    Route["metrics.route.ts<br/>HTTP layer"] -->|"calls"| Service["metrics.service.ts<br/>Business logic"]
    Service -->|"calls"| Client["github.client.ts<br/>Infrastructure"]
    Service -->|"calls"| Mapper["metrics.mapper.ts<br/>Pure transforms"]
    Client -->|"HTTP"| API["GitHub API"]
    API -->|"raw data"| Mapper
    Mapper -->|"domain types"| Service
    Service -->|"PrMetric[]"| Route
    Route -->|"JSON"| HTTP["Response"]

    style Route fill:#1e3a5f,stroke:#2563eb,color:#fff
    style Service fill:#1a3d30,stroke:#16a34a,color:#fff
    style Mapper fill:#3d3000,stroke:#d97706,color:#fff
    style Client fill:#3d1a1a,stroke:#dc2626,color:#fff
```

---

## 9. Caching Strategy & KV Namespace Layout

| Namespace | Data | TTL |
|---|---|---|
| `CACHE` | GitHub API cache (re-fetched fresh) | Varies |
| `SCORES_KV` | Point rules, leaderboard snapshots, rule change log, score locks | No TTL for rules; 6h for snapshots |
| `DEVELOPERS_KV` | Developer profiles | No TTL |
| `ATTENDANCE_KV` | Active attendance sessions (current check-ins) | No TTL |

```mermaid
graph TD
    REQ["Incoming Request"] --> CHECK{"SCORES_KV hit?"}
    CHECK -->|"YES"| RETURN["Return from KV<br/>(~5-20ms)"]
    CHECK -->|"NO"| D1Q["D1: events JOIN point_rules<br/>(SQL aggregation)"]
    D1Q --> STORE["Store in SCORES_KV<br/>with 6h TTL"]
    STORE --> RETURN2["Return fresh data"]

    subgraph Namespaces["Cloudflare Workers KV"]
        K1["CACHE: GitHub API cache"]
        K2["SCORES_KV: leaderboard snapshots"]
        K3["DEVELOPERS_KV: profiles"]
        K4["ATTENDANCE_KV: active sessions"]
    end

    subgraph Database["Cloudflare D1 (SQLite)"]
        T1["events: immutable log"]
        T2["point_rules: scoring weights"]
        T3["events_archive: old events"]
    end

    D1Q --> Database
    STORE --> Namespaces
```

---

## 10. Event-Driven Scoring Architecture

```mermaid
sequenceDiagram
    participant GH as GitHub Webhook
    participant W as Worker
    participant ES as EventsService
    participant D1 as D1 Database
    participant KV as SCORES_KV
    participant F as Frontend

    GH->>W: POST /api/webhooks/github
    W->>ES: ingestEvent(PR_CREATED)
    ES->>D1: INSERT OR IGNORE (idempotent)
    D1-->>ES: inserted: true
    ES->>KV: Invalidate developer cache

    Note over W: No points stored in events!<br/>Points derived via JOIN at query time.

    F->>W: GET /api/scores/leaderboard
    W->>KV: Check cache
    alt Cache Hit
        KV-->>W: cached result
    else Cache Miss
        W->>D1: SELECT developer_id, SUM(r.points)<br/>FROM events e JOIN point_rules r ...
        D1-->>W: aggregated scores
        W->>KV: Cache result (6h TTL)
    end
    W-->>F: leaderboard JSON
```

### Attendance Duration Flow

```mermaid
sequenceDiagram
    participant C as Client
    participant W as Worker
    participant AKV as ATTENDANCE_KV
    participant D1 as D1 Database

    C->>W: POST /api/attendance/check-in
    W->>D1: INSERT CHECK_IN event
    W->>AKV: Store active session
    W-->>C: { eventId, inserted: true }

    Note over C: Time passes...

    C->>W: POST /api/attendance/check-out
    W->>AKV: Find matching CHECK_IN
    W->>W: Calculate duration (90 min)
    W->>D1: INSERT CHECK_OUT event
    W->>D1: INSERT ATTENDANCE_DURATION event<br/>(6 blocks × 15 min)
    W->>AKV: Clear active session
    W-->>C: { eventId, durationMinutes: 90 }
```

---

## 10. Deployment Architecture

```mermaid
graph TB
    subgraph Local["🖥️ Development (Local)"]
        FL["Flutter run -d chrome<br/>localhost:3000"]
        TS["tsx watch src/server.ts<br/>localhost:3001"]
    end

    subgraph CI["⚙️ GitHub Actions"]
        BOT["sellio-metrics-bot.yml<br/>Runs every 6 hours"]
    end

    subgraph Deployment["🚀 Production (Cloudflare Edge)"]
        WEB["Cloudflare Pages<br/>(Flutter Web)"]
        API["Cloudflare Workers<br/>(Serverless API)"]
        KV["Cloudflare KV<br/>(4 Namespaces)"]
        DB["Cloudflare D1<br/>(SQLite Events)"]
        CRON["Cron Trigger<br/>(every 6 hours)"]
    end

    BOT --> API
    API <--> KV
    API <--> DB
    CRON --> API
    WEB <--> API
```

---

*Last updated: March 2026 | Sellio Squad*

