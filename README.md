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
| 🔥 **Team Spotlights** | Hot streaks, fastest reviewers, top commenters |
| ⏱️ **Review Velocity** | Time-to-first-review, time-to-merge, reviewer load analytics |
| 🐢 **Bottleneck Detection** | Slow PRs ranked by wait time with severity coloring |
| 🧩 **PR Type Distribution** | Feature / Fix / Refactor / Chore breakdown via title conventions |
| 📊 **Code Volume** | Additions vs deletions per week with stacked bar charts |
| 🔄 **Real-Time Webhooks** | GitHub webhooks invalidate cache — new PRs appear immediately |
| 🌍 **Bilingual (EN/AR)** | Full localization with RTL support |
| 🎨 **Dark/Light Theme** | Custom design system with smooth theme transitions |
| 📱 **Responsive** | Sidebar on desktop, bottom nav on mobile, adaptive layouts |
| ⚡ **Edge-Deployed** | Backend on Cloudflare Workers (0ms cold start), frontend on Pages |

---

## 🏗️ Architecture

```
                    ┌──────────────────────────────┐
                    │       Cloudflare Edge         │
                    │                              │
   Browser ────────▶│  Pages (Flutter Web)         │
                    │        │                     │
                    │        │ /api/* ──────────▶  │
                    │        │                     │
                    │  Workers (TypeScript API)    │
                    │        │          │          │
                    │        ▼          ▼          │
                    │   Workers KV   GitHub API    │
                    │   (Cache)      (Octokit)     │
                    └──────────────────────────────┘
                              │
                    GitHub Webhooks ─── cache invalidation
```

**Frontend** → Clean Architecture + Provider state management  
**Backend** → Layered Architecture + Awilix DI + Workers-native router  
**Infra** → Cloudflare Workers + KV + Pages + GitHub Actions CI/CD

---

## 🛠️ Tech Stack

### Backend
| Technology | Purpose |
|-----------|---------|
| **TypeScript** | Type-safe API development |
| **Cloudflare Workers** | Serverless edge compute (0ms cold start, 100k+ req/day free) |
| **Workers KV** | Edge-distributed caching with TTL (100k reads/day free) |
| **Awilix** | Dependency injection (PROXY mode, scoped lifetimes) |
| **Octokit** | GitHub REST API client with App authentication |
| **GitHub App Auth** | JWT → Installation token (5,000 req/hr, auto-refresh) |

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

### Backend (wrangler.toml vars)

| Variable | Default | Description |
|----------|---------|-------------|
| `GITHUB_ORG` | `Sellio-Squad` | Organization name |
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
