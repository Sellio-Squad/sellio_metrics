---
description: How to deploy the Flutter frontend to Cloudflare Pages via CLI
---

This workflow guides you through building and deploying the frontend manually using the CLI.

### Prerequisites
- Flutter SDK installed and in your PATH.
- Node.js installed.
- Logged into Cloudflare via `npx wrangler login`.

### Deployment Steps

1. **Navigate to the frontend directory**
   ```bash
   cd frontend
   ```

2. **Clean previous builds (Optional but recommended)**
   ```bash
   flutter clean
   ```

3. **Get dependencies**
   ```bash
   flutter pub get
   ```

4. **Build the web application**
   // turbo
   Replace `https://sellio-metrics.abdoessam743.workers.dev` with your actual production backend URL if different.
   ```bash
   flutter build web --release --dart-define=API_BASE_URL=https://sellio-metrics.abdoessam743.workers.dev
   ```

5. **Deploy to Cloudflare Pages**
   // turbo
   ```bash
   npx wrangler pages deploy build/web --project-name=sellio-dashboard
   ```

> [!TIP]
> If you haven't authenticated wrangler yet, run `npx wrangler login` before step 5.
