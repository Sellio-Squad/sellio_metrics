<div align="center">

# ⚡ Sellio Metrics — Backend

**Fastify · TypeScript · GitHub App · Clean Architecture**

[![TypeScript](https://img.shields.io/badge/TypeScript-5.7-3178C6?logo=typescript&logoColor=white)](https://www.typescriptlang.org)
[![Fastify](https://img.shields.io/badge/Fastify-5.x-000000?logo=fastify&logoColor=white)](https://fastify.dev)
[![Node.js](https://img.shields.io/badge/Node.js-22+-339933?logo=node.js&logoColor=white)](https://nodejs.org)
[![GitHub App](https://img.shields.io/badge/GitHub_App-Auth-181717?logo=github&logoColor=white)](https://docs.github.com/en/apps)

*A high-performance REST API that fetches live GitHub PR metrics using GitHub App authentication.*

</div>

---

## 📦 Tech Stack

| Tool | Role |
|------|------|
| **Fastify 5** | HTTP server (4× faster than Express) |
| **TypeScript 5.7** | Type-safe throughout |
| **@octokit/rest** | GitHub REST API client |
| **@octokit/auth-app** | GitHub App JWT → access token auth |
| **@google-apps/meet**| Google Meet REST API client |
| **google-auth-library**| Google OAuth2 user consent flow |
| **Awilix** | Dependency injection (PROXY mode) |
| **Pino** | Structured JSON logging |
| **@fastify/rate-limit** | Request rate limiting |
| **@fastify/cors** | Cross-origin request handling |
| **tsx** | TypeScript execution (dev mode) |

---

## 🗂️ Project Structure

```
backend/
├── private-key.pem         ← 🔑 Your GitHub App key (NEVER commit this)
├── .env                    ← Environment variables (copy from .env.example)
├── .env.example            ← Template with documentation
├── package.json
├── tsconfig.json
│
└── src/
    ├── config/
    │   └── env.ts          ← Validated env config (fail-fast on startup)
    │
    ├── core/               ← Framework-agnostic business core
    │   ├── container.ts    ← Awilix DI container
    │   ├── errors.ts       ← AppError hierarchy
    │   ├── logger.ts       ← Pino logger instance
    │   ├── types.ts        ← Shared domain types (PrMetric, RepoInfo…)
    │   └── utils/
    │       └── date.ts     ← Pure date helpers
    │
    ├── infra/
    │   └── github/
    │       ├── github.client.ts  ← Octokit + auto token refresh
    │       └── github.types.ts   ← Raw GitHub API types
    │
    ├── modules/            ← Feature slices (Route → Service → Mapper)
    │   ├── health/
    │   │   └── health.route.ts
    │   ├── repos/
    │   │   ├── repos.service.ts  ← Business logic + 5-min cache
    │   │   ├── repos.route.ts    ← JSON Schema validation
    │   │   └── repos.types.ts
    │   └── metrics/
    │       ├── metrics.service.ts ← Orchestrates paginated API calls
    │       ├── metrics.mapper.ts  ← Pure fn: raw GitHub → PrMetric
    │       ├── metrics.route.ts
    │       └── metrics.types.ts
    │
    ├── plugins/
    │   ├── error-handler.ts ← Central error → JSON response
    │   └── rate-limit.ts    ← Rate limiting plugin
    │
    ├── app.ts              ← Fastify factory (testable)
    └── server.ts           ← Entry point: config → DI → app → listen
```

---

## ⚙️ Setup

### Step 1 — Create a GitHub App

1. Go to **GitHub → Settings → Developer settings → GitHub Apps → New GitHub App**
2. Set permissions:
   - `Pull requests` → **Read**
   - `Contents` → **Read**
   - `Members` → **Read**
3. Disable webhooks (not needed)
4. Click **Generate a private key** → download the `.pem` file
5. Install the app on your organization → note the **Installation ID**
6. Note your **App ID** from the app settings page

### Step 2 — Place Your Private Key

```
backend/
└── private-key.pem   ← Paste/rename your downloaded .pem file here
```

> ✅ The server reads it directly — **no escaping, no formatting needed**.  
> 🚫 This file is in `.gitignore` — it will never be committed.

### Step 3 — Configure Environment

```bash
cp .env.example .env
```

Edit `backend/.env`:

```env
APP_ID=123456
INSTALLATION_ID=12345678
GITHUB_ORG=Sellio-Squad
PORT=3001

# Google OAuth2 Credentials for Google Meet Integration
GOOGLE_CLIENT_ID=your_oauth2_client_id.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=your_oauth2_client_secret
GOOGLE_REDIRECT_URI=http://localhost:3001/api/meetings/oauth2callback
```

> You do **not** need to set `APP_PRIVATE_KEY` — the server reads `private-key.pem` automatically.

### Step 4 — Install & Run

```bash
# Install dependencies
npm install

# Start in development mode (auto-reload on save)
npm run dev
```

You should see:
```
INFO: 🔑 Private key format check  keyLineCount=28  keyHasNewlines=true
INFO: DI container built
INFO: Server listening at http://0.0.0.0:3001
INFO: 🚀 Sellio Metrics Backend running on http://localhost:3001
```

---

## 🔌 API Reference

All endpoints return `Content-Type: application/json`.

### `GET /api/health`
```bash
curl http://localhost:3001/api/health
```
```json
{ "status": "ok", "version": "1.0.0", "uptime": 12.4, "org": "Sellio-Squad" }
```

---

### `GET /api/repos`
```bash
curl http://localhost:3001/api/repos
```
```json
{
  "org": "Sellio-Squad",
  "count": 3,
  "repos": [
    {
      "name": "sellio_mobile",
      "full_name": "Sellio-Squad/sellio_mobile",
      "description": "Flutter mobile app",
      "html_url": "https://github.com/Sellio-Squad/sellio_mobile",
      "private": false,
      "language": "Dart",
      "updated_at": "2026-02-20T18:00:00Z"
    }
  ]
}
```
> **Cached** for 5 minutes per organization.

---

### `GET /api/meetings/auth-url`
Retrieves the Google OAuth2 consent screen URL for authenticating Google Meet access.

### `POST /api/meetings/auth-logout`
Clears the active Google Meet OAuth2 session context.

### `POST /api/meetings`
Creates a new Google Meet space. Requires prior authentication via `/auth-url` and `/oauth2callback`.

### `POST /api/meetings/:id/end`
Ends the active Google Meet session and kicks out all participants.

---

### `GET /api/metrics/:owner/:repo`

| Parameter | In | Type | Description |
|-----------|-----|------|-------------|
| `owner` | path | string | GitHub org or user |
| `repo` | path | string | Repository name |
| `state` | query | `open\|closed\|all` | PR state filter (default: `all`) |
| `since` | query | ISO 8601 | Filter PRs opened after this date |
| `until` | query | ISO 8601 | Filter PRs opened before this date |

```bash
curl "http://localhost:3001/api/metrics/Sellio-Squad/sellio_mobile?state=all"
```
```json
{
  "owner": "Sellio-Squad",
  "repo": "sellio_mobile",
  "count": 127,
  "metrics": [
    {
      "prNumber": 88,
      "title": "feat: onboarding flow",
      "state": "merged",
      "isMerged": true,
      "creator": { "login": "dev01", "avatarUrl": "https://..." },
      "openedAt": "2026-02-10T09:00:00Z",
      "mergedAt": "2026-02-11T15:45:00Z",
      "timeToMergeMinutes": 1725,
      "timeToFirstReviewMinutes": 180,
      "isoWeek": "2026-W07",
      "diffStats": { "additions": 412, "deletions": 88, "changedFiles": 11 },
      "approvals": [{ "login": "reviewer01", "submittedAt": "2026-02-11T12:00:00Z" }],
      "isApproved": true,
      "hasRequiredApprovals": false,
      "reviewCommentCount": 5,
      "generalCommentCount": 1
    }
  ]
}
```

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────┐
│              Fastify Backend                 │
│                                             │
│  Request                                    │
│     │                                       │
│     ▼                                       │
│  Route (JSON Schema validation)             │
│     │                                       │
│     ▼                                       │
│  Service (business logic + caching)         │
│     │                    │                  │
│     ▼                    ▼                  │
│  GitHub Client      Mapper (pure fn)        │
│  (Octokit +         raw → PrMetric          │
│   App Auth)                                 │
│     │                                       │
│     ▼                                       │
│  GitHub REST API                            │
└─────────────────────────────────────────────┘
```

### Layer Responsibilities

| Layer | Does | Does NOT do |
|-------|------|-------------|
| **Route** | HTTP, validation, DI resolution | Business logic |
| **Service** | Orchestration, caching | HTTP details |
| **Mapper** | Data transformation (pure) | API calls, side effects |
| **Client** | GitHub API calls | Business rules |

### Dependency Injection (Awilix)

Services declare their dependencies by **constructor parameter name** — no decorators, no `new` in business code:

```typescript
class MetricsService {
  constructor({ githubClient, logger, env }: Cradle) {
    // Awilix resolves these by name from the container
  }
}
```

---

## 🔐 Private Key — Resolution Order

The server tries these in order:

```
1. PRIVATE_KEY_PATH=/path/to/key.pem  → custom location
2. backend/private-key.pem            → default (recommended)
3. APP_PRIVATE_KEY="..."              → env var fallback (legacy)
```

**Startup diagnostic log:**
```json
{
  "msg": "🔑 Private key format check",
  "keyFirstLine": "-----BEGIN RSA PRIVATE KEY-----",
  "keyLastLine":  "-----END RSA PRIVATE KEY-----",
  "keyLineCount": 28,
  "keyHasNewlines": true
}
```
If `keyHasNewlines` is `false` or `keyLineCount` is `1`, the key was not read correctly.

---

## 📋 Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `APP_ID` | ✅ | — | GitHub App numeric ID |
| `INSTALLATION_ID` | ✅ | — | GitHub App installation ID |
| `PRIVATE_KEY_PATH` | ❌ | `./private-key.pem` | Custom path to private key |
| `GITHUB_ORG` | ❌ | `Sellio-Squad` | Organization slug |
| `PORT` | ❌ | `3001` | HTTP server port |
| `GOOGLE_CLIENT_ID` | ✅ | — | Google OAuth2 Client ID |
| `GOOGLE_CLIENT_SECRET`| ✅ | — | Google OAuth2 Client Secret |
| `GOOGLE_REDIRECT_URI` | ✅ | — | Google OAuth2 Redirect URI (`/api/meetings/oauth2callback`) |
| `LOG_LEVEL` | ❌ | `info` | `trace` `debug` `info` `warn` `error` |
| `REQUIRED_APPROVALS` | ❌ | `2` | Approvals needed for "approved" status |
| `RATE_LIMIT_MAX` | ❌ | `100` | Max requests per window |
| `RATE_LIMIT_WINDOW_MS` | ❌ | `60000` | Rate limit window (ms) |

---

## 🛠️ NPM Scripts

```bash
npm run dev    # Start with hot-reload (tsx watch)
npm run build  # Compile TypeScript → dist/
npm start      # Run compiled dist/server.js
npm run lint   # TypeScript type-check (tsc --noEmit)
```

---

## 🐛 Troubleshooting

### ❌ Private key not found

**Error:** `❌ GitHub App private key not found`

**Fix:** Copy your `.pem` file to `backend/private-key.pem`

---

### ❌ `error:1E08010C:DECODER routines::unsupported`

**Cause:** Only occurs when using the `APP_PRIVATE_KEY` env var with malformed newlines.

**Fix:** Use the `.pem` file approach instead (see Setup → Step 2).

---

### ❌ `Missing required env var: APP_ID`

**Fix:** Ensure `backend/.env` exists and contains `APP_ID` and `INSTALLATION_ID`.

---

### ❌ 502 Bad Gateway from GitHub API

**Cause:** Wrong Installation ID, or the App isn't installed on the org.

**Fix:** Go to GitHub App settings → Installations → confirm the org is listed.  
Get the correct Installation ID from the URL: `https://github.com/organizations/ORG/settings/installations/INSTALLATION_ID`

---

## 📄 License

MIT — part of the [Sellio Metrics](../README.md) monorepo.
