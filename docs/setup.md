# Setup

## Repository Layout

- `Backend/`: Express + TypeScript API with PostgreSQL
- `Web/`: React + Vite installable PWA
- `Venda/`: SwiftUI iOS app
- `Venda.xcodeproj/`: Xcode project

## Backend

### Requirements

- Node.js 20+
- npm
- PostgreSQL 15+ or Docker

### Install

```bash
cd Backend
npm install
```

### Environment Setup

Copy the example env file first:

```bash
cd Backend
cp .env.example .env
```

Observed runtime variables:

- `DATABASE_URL`: required PostgreSQL connection string
- `JWT_SECRET`: required signing secret for auth tokens
- `JWT_SECRET_PREVIOUS`: optional comma-separated list of previous verification-only secrets during a signing-key rollout
- `DB_AUTO_MIGRATE`: optional startup schema mode flag; defaults to `true` outside production and `false` in production
- `PORT`: optional HTTP listen port, defaults to `3000`

Startup now validates `JWT_SECRET` before the server boots. The API exits immediately if the secret is missing, empty, or still set to a checked-in placeholder/example value.
Rejected placeholders currently include `change_me_for_local_dev`, `replace_with_a_long_random_secret`, `venda_secret_key`, and `venda_production_secret_key_change_me`.

Generate a replacement secret with a command such as:

```bash
openssl rand -base64 48 | tr -d '\n'; echo
```

Use a different `JWT_SECRET` per environment. During a planned rotation, keep the current signing key in `JWT_SECRET` and temporarily add any still-valid older verification key(s) to `JWT_SECRET_PREVIOUS` until old sessions expire.

### Backend Preflight

Before pointing the app or any external client at a backend environment:

```bash
cd Backend
npm run build
npm test
npm run db:migrate
npm run db:verify
NODE_ENV=production DB_AUTO_MIGRATE=false npm run smoke:live
```

The backend test suite is still useful for fast controller-level regressions. `npm run db:migrate` applies the checked-in SQL migrations out of band, `npm run db:verify` confirms migration history plus required tables/cursors/triggers exist, and the production-style smoke command adds a real Postgres startup plus health/auth/team-management/sync/reports verification path.
The backend CI workflow also builds the production Docker image now, so packaging regressions are caught before deploy.

### Run Locally

The checked-in `.env.example` points at a local Postgres database on `localhost:5432`:

Typical local run flow:

```bash
cd Backend
npm run dev
```

If your local Postgres credentials or port differ, update `DATABASE_URL` in `.env` first.
To exercise the live smoke path with the checked-in Docker database service instead of running the API manually:

```bash
cd Backend
npm run smoke:live:local
```

Typical production build flow:

```bash
cd Backend
npm run build
npm run db:migrate
npm run db:verify
NODE_ENV=production DB_AUTO_MIGRATE=false npm start
```

For production, keep `DB_AUTO_MIGRATE=false` so the API verifies schema instead of running DDL on every boot.

### Run With Docker

```bash
cd Backend
docker compose up --build
```

Docker Compose reads `Backend/.env` for variable substitution. `JWT_SECRET` is mandatory there too, and `docker compose up` now fails fast if it is missing.
The checked-in `Backend/docker-compose.yml` and `.env.example` are local/dev defaults with checked-in local Postgres credentials. Replace both the secret and database settings before reusing this pattern on a shared or long-lived host.

`npm run smoke:live:local` reuses that same local Docker database service when port `5432` is free, or falls back to a disposable Postgres container on an alternate localhost port when it is not. It builds the backend, applies migrations with the dedicated entrypoint, boots the compiled server on port `3101` with startup auto-migration disabled, and validates health plus merchant/staff auth, staff lifecycle, sync round-trip, and reports summary flows end to end.
The production image now uses a multi-stage Docker build, installs production dependencies only in the runtime layer, runs as the non-root `node` user, and exposes a healthcheck against `/ready`.

The compose file starts:

- `venda-api` on port `3000`
- `venda-db` on port `5432`

## Web App

### Requirements

- Node.js 20+
- npm

### Run Locally

```bash
cd Web
npm install
npm run dev
```

The Vite dev server proxies `/api` to `http://127.0.0.1:3000` by default. Set `VITE_DEV_API_ORIGIN` if your backend runs on a different local origin, or set `VITE_API_BASE_URL` to bypass same-origin `/api/v1`.

### Verify

```bash
cd Web
npm run build
npm test
npm run e2e
```

The web build emits an installable PWA with `manifest.webmanifest` and `sw.js`.

## Homeserver Production

Production deployment uses the root `docker-compose.production.yml` and a server-only `.env.production` created from `.env.production.example`.

```bash
./scripts/deploy-homeserver.sh
```

The deploy script backs up the existing `venda-backend-venda-db-1` database with `pg_dump`, syncs the working tree to `homeserver:/home/sal/Venda`, then runs Compose. The production Compose file uses the existing external Docker volume `venda-backend_venda-postgres-data`, keeps the API and database internal, and runs `cloudflare/cloudflared` with `CLOUDFLARE_TUNNEL_TOKEN`.

## iOS App

### Requirements

- Xcode
- iOS Simulator or physical iPhone target supported by the project

### Open And Run

1. Open `Venda.xcodeproj`.
2. Select the `Venda` scheme.
3. Build and run the app on a simulator.

### Backend URL Override

The iOS app resolves its API base URL in this order:

1. `VENDA_API_BASE_URL` from the process environment
2. `VENDA_API_BASE_URL` from the app Info.plist
3. `API_BASE_URL` from the app Info.plist
4. `venda.api.base.url` from `UserDefaults`
5. Built-in fallback: `https://venda.kynto.me/api/v1`

If you do nothing, the app talks to that hosted fallback rather than your local backend.
Use a full absolute base URL that already includes `/api/v1`.

Examples:

- `https://example.com/api/v1`
- `https://your-tunnel.example/api/v1`

Current caveats from source:

- The project uses a generated Info.plist, and the shared project now checks in a `VENDA_API_BASE_URL` key path via build settings.
- `NetworkService` resolves the base URL during app startup, so any override must be in place before launch.
- The shared project now enables `NSAllowsLocalNetworking`, which helps with plain `http://` local endpoints on Apple platforms.
- In practice, local device testing is still safest with HTTPS or a tunnel when crossing devices or networks.

### Command Line Build

```bash
xcodebuild -scheme Venda -project Venda.xcodeproj -destination 'generic/platform=iOS Simulator' build
```

## Verification Status

Verified against the working tree on April 4, 2026:

- `cd Backend && npm run build` succeeds
- `cd Backend && npm test` succeeds
- `cd Backend && npm run smoke:live` succeeds when pointed at a real Postgres instance
- `cd Backend && npm run smoke:live:local` succeeds
- `.github/workflows/ios-verify.yml` now builds the app target and runs `VendaTests` on a simulator in CI
- `xcodebuild -scheme Venda -project Venda.xcodeproj -destination 'generic/platform=iOS Simulator' build` was not run from this environment because `xcodebuild` is unavailable here

See `known-issues.md` for current runtime and integration gaps.
