## Sellio Metrics — Local Dev Commands

All commands are meant to be run from the project root:

```bash
cd /path/to/sellio_metrics
```

### Frontend (Flutter)

```bash
# Run Flutter web (Chrome) with real backend (default API_BASE_URL = http://localhost:3001)
cd frontend
flutter run -d chrome

# Build Flutter web for release (real backend)
cd frontend
flutter build web --dart-define=API_BASE_URL=http://localhost:3001

# Build Flutter web for release with fake data only
cd frontend
flutter build web --dart-define=USE_FAKE_DATA=true

# List available Flutter devices
cd frontend
flutter devices
```

```bash
# Run Flutter web with fake data (no backend required)
cd frontend
flutter run -d chrome --dart-define=USE_FAKE_DATA=true
```

### Backend (Node / Fastify)

```bash
# Install backend dependencies
cd backend
npm install

# Run backend in development mode (with tsx + watch)
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

