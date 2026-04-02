# Venda

Venda is a mixed codebase with:

- An iOS SwiftUI app in `Venda/`
- A Node.js + TypeScript backend in `Backend/`
- Project docs in `docs/`

## Repo Setup

### Backend

```bash
cd Backend
npm install
cp .env.example .env
# replace JWT_SECRET in .env with a long random secret
docker compose up --build
```

If you prefer running Postgres yourself, see `Backend/README.md`.
The checked-in Compose stack is a local/dev baseline. Replace the example JWT secret and local Postgres credentials before using this pattern on a shared or internet-exposed host.

### iOS App

1. Open `Venda.xcodeproj` in Xcode.
2. Select the `Venda` scheme.
3. Run on an iOS Simulator.
4. If you need a non-default backend, configure `VENDA_API_BASE_URL` before launch. See `docs/setup.md`.

## Backend Preflight

Before pointing clients at a new backend environment:

- `cd Backend && npm run build`
- `cd Backend && npm test`
- `cd Backend && npm run smoke:live` against the target Postgres wiring, or `cd Backend && npm run smoke:live:local` for the checked-in local Docker database
- Set a unique `JWT_SECRET` per environment. Rotating it invalidates all active sessions immediately.

## Verification

Verified against the working tree on April 2, 2026:

- Backend TypeScript build: `cd Backend && npm run build` succeeds
- iOS command-line build: not run from this environment because `xcodebuild` is unavailable here

## Notes

- The backend initializes and mutates its PostgreSQL schema on startup, so deploys need a database role that can run the bootstrap SQL in `Backend/src/config/db.ts`.
- The backend validates `JWT_SECRET` during startup and rejects placeholder/example values.
- `Backend/.env.example` and `Backend/docker-compose.yml` are local/dev templates with checked-in local Postgres settings, not production manifests.
- The iOS app falls back to a hosted API URL, but the base URL is overridable in code via environment, Info.plist, or `UserDefaults`.
- Registration, merchant login, and staff join now call the live backend auth endpoints. The first-product step remains local-first and completes session persistence after registration.
- The main project documentation lives in `docs/README.md`.
