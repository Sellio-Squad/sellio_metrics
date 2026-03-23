## Sellio Metrics — Local Dev Commands

All commands are meant to be run from the project root:

```bash
cd /path/to/sellio_metrics
```

### Frontend (Flutter)

```bash
# Run Flutter web (Chrome) against local Worker (default port 8787)
cd frontend
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8787

# Run Flutter web against local Fastify (port 3001)
cd frontend
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:3001

# Build Flutter web for release (real backend)
cd frontend
flutter build web --dart-define=API_BASE_URL=http://localhost:3001

# Build Flutter web for release with fake data only
cd frontend
flutter build web --dart-define=USE_FAKE_DATA=true

cd frontend
flutter build web --dart-define=API_BASE_URL=https://sellio-metrics.abdoessam743.workers.dev


dart run build_runner build --delete-conflicting-outputs  


dart fix --apply

# List available Flutter devices
cd frontend
flutter devices
```

```bash
# Run Flutter web with fake data (no backend required)
flutter run -d chrome --dart-define=USE_FAKE_DATA=true
cd frontend
```

### Backend (Node / Fastify)

```bash
# Install backend dependencies
cd backend
npm install

# Run backend in Cloudflare Worker mode (LOCAL)
# Most accurate to production. Default port: 8787.
cd backend
npm run dev:worker

# Run backend in Legacy Fastify mode (LOCAL)
# Port: 3001.
cd backend
npm run dev

# Type-check / lint backend
cd backend
npm run lint

# Build backend (TypeScript -> dist)
cd backend
npm run build

# Start built backend
cd backend
npm start

cd backend
npm run deploy

# Get what inside cache
npx wrangler kv key list --binding CACHE

# Get what inside cache using prefix
npx wrangler kv key list --binding CACHE --prefix "sellio:google"
```

### Frontend + Backend together (real API)

```bash
# Terminal 1 — backend dev server
cd backend
npm install
npm run dev

# Terminal 2 — frontend against local backend
cd frontend
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:3001
```

