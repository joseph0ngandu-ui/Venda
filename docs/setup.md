# Setup

## Repository Layout

- `Backend/`: Express + TypeScript API with PostgreSQL
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
- `PORT`: optional HTTP listen port, defaults to `3000`

Startup now validates `JWT_SECRET` before the server boots. The API exits immediately if the secret is missing, empty, or still set to a checked-in placeholder/example value.
Rejected placeholders currently include `change_me_for_local_dev`, `replace_with_a_long_random_secret`, `venda_secret_key`, and `venda_production_secret_key_change_me`.

Generate a replacement secret with a command such as:

```bash
openssl rand -base64 48 | tr -d '\n'; echo
```

Use a different `JWT_SECRET` per environment. Because the backend uses the same secret for JWT signing and verification, rotating it invalidates every active session immediately.

### Backend Preflight

Before pointing the app or any external client at a backend environment:

```bash
cd Backend
npm run build
npm test
npm run smoke:live
```

The backend test suite is still useful for fast controller-level regressions, and `npm run smoke:live` now adds a real Postgres startup plus health/auth verification path.

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
npm start
```

### Run With Docker

```bash
cd Backend
docker compose up --build
```

Docker Compose reads `Backend/.env` for variable substitution. `JWT_SECRET` is mandatory there too, and `docker compose up` now fails fast if it is missing.
The checked-in `Backend/docker-compose.yml` and `.env.example` are local/dev defaults with checked-in local Postgres credentials. Replace both the secret and database settings before reusing this pattern on a shared or long-lived host.

`npm run smoke:live:local` reuses that same local Docker database service, builds the backend, boots the compiled server on port `3101`, and validates health plus the merchant auth flow end to end.

The compose file starts:

- `venda-api` on port `3000`
- `venda-db` on port `5432`

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
5. Built-in fallback: `https://homeserver.taildbc5d3.ts.net/api/v1`

If you do nothing, the app talks to that hosted fallback rather than your local backend.
Use a full absolute base URL that already includes `/api/v1`.

Examples:

- `https://example.com/api/v1`
- `https://your-tunnel.example/api/v1`

Current caveats from source:

- The project uses a generated Info.plist, and no override key is checked into the shared project settings.
- `NetworkService` resolves the base URL during app startup, so any override must be in place before launch.
- No App Transport Security exception is checked in for plain `http://` local URLs, so local HTTP endpoints may require additional Xcode project configuration.
- In practice, local device testing is safest with HTTPS or a tunnel unless you intentionally add an ATS exception in Xcode.

### Command Line Build

```bash
xcodebuild -scheme Venda -project Venda.xcodeproj -destination 'generic/platform=iOS Simulator' build
```

## Verification Status

Verified against the working tree on April 2, 2026:

- `cd Backend && npm run build` succeeds
- `xcodebuild -scheme Venda -project Venda.xcodeproj -destination 'generic/platform=iOS Simulator' build` was not run from this environment because `xcodebuild` is unavailable here

See `known-issues.md` for current runtime and integration gaps.
