<div align="center">

# 📊 Sellio Metrics

**A real-time GitHub PR analytics platform for the Sellio Squad**

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![TypeScript](https://img.shields.io/badge/TypeScript-5.7-3178C6?logo=typescript&logoColor=white)](https://www.typescriptlang.org)
[![Fastify](https://img.shields.io/badge/Fastify-5.x-000000?logo=fastify&logoColor=white)](https://fastify.dev)
[![Node.js](https://img.shields.io/badge/Node.js-22.x-339933?logo=node.js&logoColor=white)](https://nodejs.org)
[![GitHub App](https://img.shields.io/badge/GitHub_App-Authenticated-181717?logo=github&logoColor=white)](https://docs.github.com/en/apps)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

*Track pull requests, review velocity, code quality, and collaboration patterns — all in one beautiful dashboard.*

---

[🚀 Features](#-features) • [🏗️ Architecture](#️-architecture) • [📁 Project Structure](#-project-structure) • [⚙️ Setup](#️-setup) • [🔌 API Reference](#-api-reference) • [🎨 Design System](#-design-system)

</div>

---

## 🚀 Features

| Feature | Description |
|---------|-------------|
| 📈 **PR Metrics Dashboard** | Open/merged/closed counts, velocity trends, weekly activity charts |
| 🧩 **Type Distribution** | Feature / Fix / Refactor / Chore breakdown via PR title conventions |
| ⏱️ **Review Velocity** | Time-to-first-review, time-to-merge, reviewer load charts |
| 🔥 **Team Spotlights** | Hot streaks, fastest reviewers, top commenters |
| 🐢 **Bottleneck Detection** | Slow PRs ranked by wait time with severity coloring |
| 🏆 **Leaderboard** | Ranked team members by merged PRs, reviews, and comments |
| 📊 **Code Volume** | Additions vs deletions per week with stacked bar charts |
| 🌍 **Localization Ready** | Full `AppLocalizations` integration (Arabic/English) |
| 🎨 **Dark/Light Theme** | Full `ThemeData` with a custom Design System |
| ⚡ **Live API** | Authenticated GitHub App — no rate-limit issues |

---

## 🏗️ Architecture

Sellio Metrics follows a **clean architecture** across both frontend and backend, with strong **separation of concerns** and **dependency injection** throughout.

### System Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Sellio Metrics                              │
│                                                                     │
│  ┌──────────────────────────┐    HTTP /api/*    ┌────────────────┐  │
│  │   Flutter Web Frontend   │ ─────────────────▶│ Fastify Backend│  │
│  │                          │ ◀─────────────────│                │  │
│  │  Presentation            │    JSON responses  │  Routes        │  │
│  │    └── Pages             │                   │  Services      │  │
│  │    └── Widgets           │                   │  Mappers       │  │
│  │    └── Providers         │                   │  Infra         │  │
│  │  Domain                  │                   │                │  │
│  │    └── Entities          │                   │       │        │  │
│  │    └── Repositories      │                   │       ▼        │  │
│  │    └── Services          │                   │  GitHub App    │  │
│  │  Data                    │                   │    (Octokit)   │  │
│  │    └── Remote Sources    │                   │       │        │  │
│  └──────────────────────────┘                   └───────┼────────┘  │
│                                                         │           │
│                                                         ▼           │
│                                               ┌─────────────────┐   │
│                                               │  GitHub REST    │   │
│                                               │  API v3         │   │
│                                               └─────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

---

### 🖥️ Backend Architecture (Fastify + TypeScript)

The backend follows a strict **layered clean architecture** with **Awilix dependency injection**.

```
src/
├── config/
│   └── env.ts              ← Validated env config (fail-fast on startup)
│
├── core/                   ← Framework-agnostic business core
│   ├── container.ts        ← Awilix DI container (PROXY injection mode)
│   ├── errors.ts           ← Typed error hierarchy (AppError → subclasses)
│   ├── logger.ts           ← Pino logger (pretty in dev, JSON in prod)
│   ├── types.ts            ← Shared domain types (PrMetric, RepoInfo…)
│   └── utils/
│       └── date.ts         ← Pure date utilities (toISOWeek, minutesBetween)
│
├── infra/
│   └── github/
│       ├── github.client.ts ← Octokit + GitHub App Auth (auto token refresh)
│       └── github.types.ts  ← Raw GitHub API types (isolated from domain)
│
├── modules/                ← Feature modules (Route → Service → Mapper)
│   ├── health/
│   │   └── health.route.ts ← GET /api/health
│   │
│   ├── repos/
│   │   ├── repos.service.ts ← Business logic + 5-min in-memory cache
│   │   ├── repos.route.ts   ← JSON Schema input validation
│   │   └── repos.types.ts   ← Module-specific types
│   │
│   └── metrics/
│       ├── metrics.service.ts ← Orchestrates paginated + parallel API calls
│       ├── metrics.mapper.ts  ← Pure function: raw GitHub → domain PrMetric
│       ├── metrics.route.ts   ← Input validation + DI scope resolution
│       └── metrics.types.ts   ← Module-specific types
│
├── plugins/
│   ├── error-handler.ts    ← Central Fastify error → JSON response
│   └── rate-limit.ts       ← @fastify/rate-limit with env config
│
├── app.ts                  ← Fastify factory (testable, no side-effects)
└── server.ts               ← Entry point: config → DI → app → listen
```

#### Layer Responsibilities

| Layer | Knows About | Does NOT Know About |
|-------|-------------|---------------------|
| **Route** (Controller) | HTTP, JSON Schema, DI container | Business logic, GitHub API |
| **Service** | Domain types, infrastructure clients | HTTP, Fastify, JSON format |
| **Mapper** | Raw API types, domain types | Everything else (pure functions) |
| **Infra/Client** | Octokit, GitHub API | Business rules, routing |
| **Core** | Nothing (framework-agnostic) | Fastify, GitHub, anything external |

#### Data Flow

```
HTTP Request
     │
     ▼
 Route Handler
 (JSON Schema validation, DI scope)
     │
     ▼
 Service
 (Business logic, orchestration, caching)
     ├──────────────────────────────┐
     ▼                              ▼
 GitHub Client              Mapper (pure fn)
 (Octokit + App Auth)       (raw → domain)
     │
     ▼
 GitHub REST API
 (paginate, parallel batch)
     │
     ▼ (raw data)
 Mapper.mapToPrMetric()
     │
     ▼
 JSON Response
```

#### Dependency Injection (Awilix)

```typescript
// All services declared by name — no `new` anywhere in business code
container.register({
  env:           asValue(env),
  logger:        asValue(logger),
  githubClient:  asClass(GitHubClient).singleton(),
  reposService:  asClass(ReposService).scoped(),
  metricsService: asClass(MetricsService).scoped(),
});

// Resolved automatically by constructor parameter name
class MetricsService {
  constructor({ githubClient, logger, env }: Cradle) { ... }
}
```

---

### 📱 Frontend Architecture (Flutter Web)

The frontend uses a clean **layered architecture** with Provider state management:

```
lib/
├── main.dart               ← App entry point
├── app.dart                ← MaterialApp + theme + routing + providers
│
├── core/                   ← Framework-agnostic utilities
│   ├── constants/          ← Layout, animation constants
│   ├── extensions/         ← ThemeData, BuildContext extensions
│   ├── theme/              ← AppTheme, AppTypography, SellioColors, AppSpacing
│   └── utils/              ← Date formatting utilities
│
├── design_system/          ← Component library (re-exports all Hux widgets)
│   └── design_system.dart  ← Single barrel export
│
├── domain/                 ← Business logic layer (no Flutter/HTTP dependency)
│   ├── entities/           ← PrEntity, BottleneckEntity, CollaborationEntity…
│   ├── enums/              ← PrType, PrStatus
│   ├── repositories/       ← IMetricsRepository (interface)
│   └── services/           ← SpotlightService, BottleneckService…
│
├── data/                   ← Data layer (implements domain interfaces)
│   ├── models/             ← JSON-serializable DTO models
│   ├── remote/             ← HTTP data source (calls backend API)
│   └── repositories/       ← MetricsRepositoryImpl
│
├── di/                     ← Dependency injection setup (GetIt/manual)
│
├── presentation/           ← Flutter UI layer
│   ├── providers/          ← DashboardProvider, AppSettingsProvider…
│   ├── pages/              ← Analytics, Dashboard, Charts, OpenPRs, Team, About
│   ├── widgets/            ← KpiCard, PrListTile, LeaderboardCard, SpotlightCard…
│   └── extensions/         ← Presentation-layer enum extensions
│
└── l10n/                   ← Localization (ARB + generated Dart)
    ├── app_en.arb
    └── app_localizations.dart
```

#### Dependency Rule

```
presentation  →  domain  ←  data
     │              │
     └──────────────┘
           ↓
     (via Provider / DI)
```

> **The domain layer has zero dependencies on Flutter, HTTP, or any external package.**  
> Only `dart:core` types. This makes domain logic fully unit-testable.

#### State Management Flow

```
User Interaction
     │
     ▼
Provider.notifyListeners()
     │
     ▼
DashboardProvider
 ├── loadMetrics()  ──▶  IMetricsRepository
 │                           │
 │                           ▼ (via DI)
 │                       MetricsRepositoryImpl
 │                           │
 │                           ▼
 │                       RemoteDataSource  ──▶  GET /api/metrics
 │                                                   │
 │                           ◀───────────────────────┘
 │                       PrEntity list
 │
 ├── bottlenecks  (BottleneckService.compute)
 ├── leaderboard  (CollaborationService.compute)
 ├── spotlights   (SpotlightService.compute)
 └── weekFilteredPrs (filtered by date range)
     │
     ▼
Widget.build() reacts to state
```

---

## 📁 Project Structure

```
sellio_metrics/
├── backend/                ← Fastify + TypeScript backend
│   ├── src/
│   │   ├── config/         ← Environment config
│   │   ├── core/           ← DI, errors, logger, types, utils
│   │   ├── infra/github/   ← GitHub App client
│   │   ├── modules/        ← health / repos / metrics
│   │   ├── plugins/        ← error handler, rate limiter
│   │   ├── app.ts          ← Fastify factory
│   │   └── server.ts       ← Entry point
│   ├── .env.example        ← Copy to .env and fill in
│   ├── package.json
│   └── tsconfig.json
│
└── frontend/               ← Flutter Web app
    ├── lib/
    │   ├── core/           ← Theme, constants, utils
    │   ├── design_system/  ← Component barrels
    │   ├── domain/         ← Entities, interfaces, services
    │   ├── data/           ← HTTP client, models, repository impls
    │   ├── di/             ← Dependency injection
    │   ├── presentation/   ← Pages, widgets, providers
    │   └── l10n/           ← Localization
    ├── web/                ← Flutter web entrypoint
    └── pubspec.yaml
```

---

## ⚙️ Setup

### Prerequisites

| Tool | Version | Installation |
|------|---------|--------------|
| Node.js | 20+ | [nodejs.org](https://nodejs.org) |
| Flutter | 3.x | [flutter.dev](https://flutter.dev/docs/get-started/install) |
| GitHub App | — | [Create a GitHub App](https://docs.github.com/en/apps/creating-github-apps) |

---

### 1. GitHub App Configuration

You need a **GitHub App** with the following permissions:

| Permission | Level |
|------------|-------|
| `Pull requests` | Read |
| `Contents` | Read |
| `Members` | Read |

1. Go to `GitHub → Settings → Developer settings → GitHub Apps → New GitHub App`
2. Set **Homepage URL** to `http://localhost:3001`
3. Set **Webhook** to inactive (not needed)
4. Generate a **private key** and download the `.pem` file
5. Install the app on your organization
6. Note the **App ID** and **Installation ID**

---

### 2. Backend Setup

```bash
cd backend

# Install dependencies
npm install

# Configure environment
cp .env.example .env
```

Edit `.env`:

```env
APP_ID=123456
INSTALLATION_ID=12345678
GITHUB_ORG=Sellio-Squad

# Paste your private key with literal \n for line breaks:
APP_PRIVATE_KEY="-----BEGIN RSA PRIVATE KEY-----\nMIIEpAIB...\n-----END RSA PRIVATE KEY-----"
```

> **Private Key Tip:** The easiest way to format your `.pem` file for `.env`:
> ```bash
> # PowerShell
> (Get-Content backend\github-app.pem -Raw).Replace("`r`n", "\n").Replace("`n", "\n")
> ```
> Copy the output and paste it as the value for `APP_PRIVATE_KEY` (keep the double quotes).

```bash
# Start development server (auto-reload)
npm run dev

# Server starts at http://localhost:3001
```

---

### 3. Frontend Setup

```bash
cd frontend

# Get dependencies
flutter pub get

# Generate localization files
flutter gen-l10n

# Run in Chrome (web mode)
flutter run -d chrome

# Or build for web
flutter build web
```

---

### 4. Verify Everything Works

```bash
# Check backend health
curl http://localhost:3001/api/health

# Expected:
# {"status":"ok","version":"1.0.0","uptime":12.3}

# Fetch repos
curl http://localhost:3001/api/repos

# Fetch PR metrics
curl "http://localhost:3001/api/metrics/Sellio-Squad/sellio_mobile?state=all"
```

---

## 🔌 API Reference

Base URL: `http://localhost:3001`

### `GET /api/health`

Returns server health status.

**Response** `200 OK`
```json
{
  "status": "ok",
  "version": "1.0.0",
  "uptime": 42.1,
  "org": "Sellio-Squad"
}
```

---

### `GET /api/repos`

Returns all repositories for the configured organization.

**Query Parameters**

| Param | Type | Default | Description |
|-------|------|---------|-------------|
| `type` | `string` | `all` | `all`, `public`, `private`, `forks`, `sources`, `member` |

**Response** `200 OK`
```json
{
  "org": "Sellio-Squad",
  "count": 5,
  "repos": [
    {
      "name": "sellio_mobile",
      "full_name": "Sellio-Squad/sellio_mobile",
      "description": "Flutter mobile app for Sellio",
      "html_url": "https://github.com/Sellio-Squad/sellio_mobile",
      "private": false,
      "language": "Dart",
      "updated_at": "2026-02-20T18:00:00Z"
    }
  ]
}
```

**Caching:** Results are cached for **5 minutes** in memory.

---

### `GET /api/metrics/:owner/:repo`

Returns PR metrics for a repository.

**Path Parameters**

| Param | Description |
|-------|-------------|
| `owner` | GitHub organization or user |
| `repo` | Repository name |

**Query Parameters**

| Param | Type | Default | Description |
|-------|------|---------|-------------|
| `state` | `string` | `all` | `open`, `closed`, `all` |
| `since` | `ISO8601` | — | Only PRs opened after this date |
| `until` | `ISO8601` | — | Only PRs opened before this date |

**Response** `200 OK`
```json
{
  "owner": "Sellio-Squad",
  "repo": "sellio_mobile",
  "count": 127,
  "metrics": [
    {
      "prNumber": 42,
      "title": "feat: add checkout flow",
      "state": "merged",
      "isMerged": true,
      "creator": {
        "login": "dev-01",
        "name": "Ahmed",
        "avatarUrl": "https://avatars.githubusercontent.com/..."
      },
      "openedAt": "2026-02-15T10:00:00Z",
      "mergedAt": "2026-02-16T14:30:00Z",
      "closedAt": null,
      "timeToMergeMinutes": 1710,
      "timeToFirstReviewMinutes": 240,
      "isoWeek": "2026-W07",
      "diffStats": {
        "additions": 523,
        "deletions": 102,
        "changedFiles": 14
      },
      "approvals": [
        { "login": "reviewer-01", "submittedAt": "2026-02-16T12:00:00Z" }
      ],
      "isApproved": true,
      "hasRequiredApprovals": false,
      "reviewCommentCount": 7,
      "generalCommentCount": 2
    }
  ]
}
```

**Error Responses**

| Code | Description |
|------|-------------|
| `400` | Invalid query parameters |
| `404` | Repository not found |
| `429` | Rate limit exceeded |
| `502` | GitHub API error |

---

## 🛡️ GitHub App Authentication

The backend uses **GitHub App authentication** (not personal access tokens):

```
┌─────────────┐    JWT (10min)     ┌─────────────┐
│   Backend   │ ─────────────────▶ │  GitHub API │
│             │                    │             │
│  App ID     │  ◀── access_token  │             │
│  Private Key│     (1hr TTL)      │             │
└─────────────┘                    └─────────────┘
         │
         │ Uses access_token for all API calls
         ▼
    Octokit requests
    (auto-refreshes when token expires)
```

**Advantages over PAT:**
- ✅ Higher rate limits (5,000 req/hr per installation)
- ✅ Org-level access without a personal account
- ✅ Fine-grained permissions
- ✅ Auto-rotating tokens (no expiry management)

---

## 🎨 Design System

The frontend uses a custom Design System (barrel-exported from `lib/design_system/design_system.dart`):

### Token Reference

#### Spacing (`AppSpacing`)
```dart
AppSpacing.xs   = 4.0
AppSpacing.sm   = 8.0
AppSpacing.md   = 12.0
AppSpacing.lg   = 16.0
AppSpacing.xl   = 24.0
AppSpacing.xxl  = 32.0
AppSpacing.xxxl = 48.0
```

#### Typography (`AppTypography`)
```dart
AppTypography.displayLg  // 32px, w700
AppTypography.displaySm  // 24px, w700
AppTypography.title      // 20px, w600
AppTypography.subtitle   // 16px, w600
AppTypography.body       // 14px, w400
AppTypography.caption    // 12px, w400
AppTypography.overline   // 11px, w500, letter-spaced
```

#### Colors (`SellioColors`)
```dart
SellioColors.primary       // Brand blue
SellioColors.secondary     // Brand purple
SellioColors.chartPalette  // 8-color chart palette
```

### Component Palette

| Component | Usage |
|-----------|-------|
| `HuxBadge` | Status labels (merged, open, pending…) |
| `HuxButton` | Primary / ghost / destructive actions |
| `HuxAvatar` | User avatars with initials fallback |
| `HuxSidebar` | Navigation rail/drawer |
| `HuxChart` | Line, bar, pie chart wrappers |

---

## 📊 CI/CD Pipeline

```yaml
# .github/workflows/sellio-metrics-bot.yml
on:
  schedule: ["0 */6 * * *"]  # Every 6 hours
  workflow_dispatch:           # Manual trigger

jobs:
  update-metrics:
    - Checkout repo
    - Call backend API
    - Commit updated metrics.json
    - Trigger frontend rebuild
```

---

## 🔐 Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `APP_ID` | ✅ | GitHub App ID (numeric) |
| `APP_PRIVATE_KEY` | ✅ | RSA private key (PEM, `\n`-escaped) |
| `INSTALLATION_ID` | ✅ | GitHub App installation ID |
| `GITHUB_ORG` | ❌ | Organization name (default: `Sellio-Squad`) |
| `PORT` | ❌ | Server port (default: `3001`) |
| `LOG_LEVEL` | ❌ | `trace`, `debug`, `info`, `warn`, `error` (default: `info`) |
| `REQUIRED_APPROVALS` | ❌ | Approvals needed for "approved" status (default: `2`) |
| `RATE_LIMIT_MAX` | ❌ | Max requests per window (default: `100`) |
| `RATE_LIMIT_WINDOW_MS` | ❌ | Rate limit window in ms (default: `60000`) |

---

## 🧩 Key Design Decisions

### Why Fastify over Express?
- **4x faster** throughput on the same hardware
- **Built-in JSON Schema validation** — no `joi`/`zod` needed for routes
- **Pino logger built-in** — structured logging out of the box
- **Plugin ecosystem** — CORS, rate-limit, awilix as first-class plugins

### Why Awilix for DI?
- **No decorators** — works with plain TypeScript classes
- **PROXY mode** — resolves by constructor parameter name at runtime
- **Scoped lifetime** — request-scoped services dispose automatically
- **Testable** — swap any dependency for a mock by name

### Why Provider over Bloc/Riverpod?
- Sufficient complexity for this use case
- Lower boilerplate for a dashboard with 3 data sources
- Native Flutter integration, no build_runner for most features

### Why GitHub App over PAT?
- Higher rate limits (5,000/hr vs 60/hr unauthenticated, 1,000/hr PAT)
- Org-level access without tying to a personal account
- Auto-rotating tokens — no manual secret rotation

---

## 🐛 Troubleshooting

### `error:1E08010C:DECODER routines::unsupported`

**Cause:** The private key in your `.env` doesn't have proper PEM newlines.

**Fix:** Ensure `APP_PRIVATE_KEY` has actual `\n` between lines:
```bash
# PowerShell — converts your .pem to a single-line .env value
$pem = Get-Content "backend\github-app.pem" -Raw
$escaped = $pem.Trim() -replace "`r`n", "\n" -replace "`n", "\n"
Write-Host "APP_PRIVATE_KEY=`"$escaped`""
```
Paste the output into your `.env` file.

### Flutter: `flutter gen-l10n` not generating files

Ensure your `pubspec.yaml` has:
```yaml
flutter:
  generate: true
```
And run from the `frontend/` directory, not the root.

### Backend: `Missing required env var`

The server does a **fail-fast check** on startup. Ensure all required vars are set in `backend/.env`.

---

## 📄 License

MIT — see [LICENSE](LICENSE) for details.

---

<div align="center">

Built with ❤️ by the **Sellio Squad**

*Measure what matters. Ship with confidence.*

</div>
