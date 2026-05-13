# Venda

Venda is a mixed codebase with:

- An iOS SwiftUI app in `Venda/`
- A Node.js + TypeScript backend in `Backend/`
- An installable React web app in `Web/`
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

### Web App

```bash
cd Web
npm install
npm run dev
```

The web app proxies `/api` to `http://127.0.0.1:3000` during local development and is packaged as a PWA for production.

### Production Web Deploy

The root `docker-compose.production.yml` builds `venda-web`, `venda-api`, `venda-db`, and `venda-cloudflared`. It expects a server-side `.env.production` created from `.env.production.example`, and uses the existing Docker volume `venda-backend_venda-postgres-data` so production data is preserved.

```bash
./scripts/deploy-homeserver.sh
```

### iOS App

1. Open `Venda.xcodeproj` in Xcode.
2. Select the `Venda` scheme.
3. Run on an iOS Simulator.
4. If you need a non-default backend, configure `VENDA_API_BASE_URL` before launch. See `docs/setup.md`.

## Backend Preflight

Before pointing clients at a new backend environment:

- `cd Backend && npm run build`
- `cd Backend && npm test`
- `cd Backend && npm run db:migrate`
- `cd Backend && npm run db:verify`
- `cd Backend && NODE_ENV=production DB_AUTO_MIGRATE=false npm run smoke:live` against the target Postgres wiring, or `cd Backend && npm run smoke:live:local` for the checked-in local Docker database
- Set a unique `JWT_SECRET` per environment. During a planned rollover, keep the current signing key in `JWT_SECRET` and place any still-valid previous key(s) in `JWT_SECRET_PREVIOUS` until old sessions age out.

## Verification

Verified against the working tree on April 4, 2026:

- Backend TypeScript build: `cd Backend && npm run build` succeeds
- Web build: `cd Web && npm run build` succeeds
- Web unit and PWA smoke tests: `cd Web && npm test && npm run e2e` succeed
- Backend live smoke: `cd Backend && npm run smoke:live` succeeds when pointed at a real Postgres instance
- Backend local Docker smoke: `cd Backend && npm run smoke:live:local` succeeds
- iOS CI lane: `.github/workflows/ios-verify.yml` now builds the app target and runs `VendaTests` on a simulator
- iOS command-line build: not run from this environment because `xcodebuild` is unavailable here

## Notes

- The backend now supports a safer production path: run `npm run db:migrate` out of band, keep `DB_AUTO_MIGRATE=false`, and let startup verify schema instead of mutating it.
- The migration runner is now file-backed and versioned under `Backend/migrations/`, with filename/checksum metadata recorded in `schema_migrations`.
- The backend validates `JWT_SECRET` during startup, rejects placeholder/example values, and supports verification-only key rollover through optional `JWT_SECRET_PREVIOUS`.
- `Backend/.env.example` and `Backend/docker-compose.yml` are local/dev templates with checked-in local Postgres settings, not production manifests.
- The iOS app falls back to `https://venda.kynto.me/api/v1`, but the base URL is overridable in code via environment, Info.plist, or `UserDefaults`, and the shared project now checks in a `VENDA_API_BASE_URL` Info.plist path plus local-network ATS support.
- Registration, merchant login, and staff join now call the live backend auth endpoints. The first-product step remains local-first, but interrupted registration can now recover and resume instead of depending on an in-memory-only session.
- The main project documentation lives in `docs/README.md`.
