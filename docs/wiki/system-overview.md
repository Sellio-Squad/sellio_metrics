## 🌐 System Overview

Sellio Metrics is a full‑stack GitHub PR analytics platform composed of:

- **Frontend**: Flutter Web dashboard (SPA) rendered in the browser.
- **Backend**: TypeScript/Fastify API server that talks to the GitHub API as a GitHub App.
- **GitHub**: GitHub App + REST API (primary data source) and optional webhooks.
- **Caching & Rate Limiting**: Cloudflare Workers KV for cached GitHub responses and a custom rate‑limit guard to protect GitHub quotas.

High‑level request flow:

1. A user opens the Flutter dashboard and selects one or more repositories.
2. The frontend calls the backend (`GET /api/repos` then `GET /api/metrics/:owner/:repo`) via HTTP.
3. The backend authenticates as a GitHub App, fetches or reuses cached PR data, maps it into `PrMetric` domain objects, and returns JSON.
4. The frontend deserializes the JSON into domain entities (`PrEntity`, `BottleneckEntity`, `LeaderboardEntry`, etc.), runs domain services to compute KPIs and derived metrics, and updates the UI through `DashboardProvider`.

For sequence‑level diagrams and a deeper visual overview, see `ARCHITECTURE.md` in the repo root. The remaining wiki pages drill into each part of this system. 

