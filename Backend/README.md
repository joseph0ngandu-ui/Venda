# Backend Setup

This backend is a small Express + TypeScript API backed by PostgreSQL.

## Requirements

- Node.js 20+
- npm
- PostgreSQL 15+ or Docker

## Quick Start With Docker

1. Copy the environment template:

```bash
cp .env.example .env
```

2. Replace `JWT_SECRET` in `.env` with a long random secret.
   Example generator:

```bash
openssl rand -base64 48 | tr -d '\n'; echo
```

3. Start the stack:

```bash
docker compose up --build
```

The API will be available at `http://localhost:3000`. The checked-in Compose stack explicitly sets `DB_AUTO_MIGRATE=true`, so this local/dev path still creates or updates the schema automatically on startup. Docker Compose reads `.env` for variable substitution and now fails fast if `JWT_SECRET` is unset.
`docker-compose.yml` and `.env.example` are still local/dev templates with checked-in local Postgres credentials. Replace those values before using the stack outside an isolated machine.

## Local Development

1. Copy the environment template:

```bash
cp .env.example .env
```

2. Replace `JWT_SECRET` in `.env` with a long random secret value.
3. Start PostgreSQL and create a database named `venda`.
4. Update `DATABASE_URL` in `.env` if your local username, password, host, or port differ.
5. Install dependencies and run the API:

```bash
npm install
npm run dev
```

Outside production, startup auto-migration defaults to enabled, so `npm run dev` will still bootstrap a fresh local database unless you explicitly set `DB_AUTO_MIGRATE=false`.

To run the live Postgres smoke path locally against the checked-in Docker database service:

```bash
npm run smoke:live:local
```

That wrapper starts `venda-db` when port `5432` is free, or falls back to a disposable Postgres container on an alternate localhost port when needed. It builds the backend, applies `npm run db:migrate`, then boots the compiled server on port `3101` in production-style verify-only mode. It exercises health, merchant registration/login, `GET /api/v1/auth/me`, staff creation/listing, staff authorization boundaries, deactivate/reactivate enforcement, staff PIN rotation, sync round-trip verification, and reports summary verification, then deletes the temporary merchant it created.
If you already have Postgres running and a built `dist/`, you can run the reusable smoke runner directly:

```bash
npm run build
npm run db:migrate
NODE_ENV=production DB_AUTO_MIGRATE=false npm run smoke:live
```

## Useful Commands

```bash
npm run dev
npm run build
npm run db:migrate
npm run db:verify
npm test
npm run smoke:live
npm run smoke:live:local
npm start
```

Runtime config notes:

- `DATABASE_URL` is required.
- `JWT_SECRET` is required and must not be empty.
- `JWT_SECRET_PREVIOUS` is optional and accepts a comma-separated list of still-valid previous verification keys during a signing-key rollout.
- Placeholder/example secrets such as `change_me_for_local_dev`, `replace_with_a_long_random_secret`, and legacy fallback values are rejected during startup.
- `PORT` is optional and defaults to `3000`.
- `PORT`, when set, must be an integer between `1` and `65535`.
- `JWT_SECRET` signs new tokens. Verification accepts the current secret plus any `JWT_SECRET_PREVIOUS` entries. Tokens currently expire after 30 days, so planned secret rollovers can preserve older sessions temporarily if the previous verification key remains configured until expiry.
- `DB_AUTO_MIGRATE` is optional. It defaults to `true` outside production and `false` in production. Use `true` for local/dev convenience and `false` when schema changes should be applied out of band with `npm run db:migrate`.
- `CORS_ALLOWED_ORIGINS` is optional and accepts a comma-separated list of exact `http://` or `https://` origins. Wildcards, paths, query strings, fragments, and the literal `null` origin are rejected during startup validation.
- `CORS_ALLOW_DEV_ORIGINS` is optional. It defaults to `true` outside production and `false` in production. When enabled, localhost loopback browser origins are allowed automatically for local development.
- `CORS_ALLOW_NO_ORIGIN` is optional and defaults to `true` so native apps and server-to-server clients that do not send an `Origin` header continue to work.

## Deployment Preflight

Before promoting a build or pointing the iOS app at a new backend:

- Run `npm run build`.
- Run `npm test`.
- Run `npm run db:migrate`.
- Run `npm run db:verify`.
- Run `NODE_ENV=production DB_AUTO_MIGRATE=false npm run smoke:live` against the target Postgres wiring, or `npm run smoke:live:local` for the checked-in local Docker database.
- Confirm `.env` contains the correct `DATABASE_URL` and a unique `JWT_SECRET` for that environment.
- If you are rotating keys, keep the current signing key in `JWT_SECRET` and place any temporary verification-only fallback key(s) in `JWT_SECRET_PREVIOUS`.
- Confirm `CORS_ALLOWED_ORIGINS` matches the exact browser origins that should be able to call the API in that environment.
- Confirm production startup is using `DB_AUTO_MIGRATE=false` once the schema is in place.

Test coverage snapshot:

- `Backend/test/auth.test.ts` covers malformed register payloads plus merchant-versus-staff JWT handling when the live staff row is missing.
- `Backend/test/staff.test.ts` covers invalid `is_active` validation and non-object update payload handling before database work begins.
- `Backend/test/sync.test.ts` covers unauthenticated sync rejection, `updated_after` validation, server-cursor-based pull filtering, and synced staff role/timestamp normalization.
- `Backend/scripts/live-smoke.js` applies migrations with the dedicated entrypoint, boots the compiled server with `DB_AUTO_MIGRATE=false`, and validates health, merchant registration/login, staff creation, staff directory auth boundaries, staff promotion, deactivation/reactivation, PIN rotation, sync round-trip behavior, reports summary, and `GET /auth/me`.
- `.github/workflows/backend-ci.yml` runs that same live smoke path in CI with a Postgres 15 service container and also builds the production Docker image.

## Operational Notes

- Production startup no longer needs to run DDL if `DB_AUTO_MIGRATE=false` and `npm run db:migrate` has already been applied. In that mode the API verifies required tables, sync cursors, and triggers before serving traffic.
- The schema change process now runs versioned SQL files from `Backend/migrations/`, records filename/checksum metadata in `schema_migrations`, and applies migrations under a PostgreSQL advisory lock.
- The migration history is still small and does not yet provide rollback orchestration.
- The server now exposes liveness and readiness endpoints at `/health`, `/live`, `/ready`, `/health/live`, and `/health/ready`. Readiness performs a database connectivity check and flips to `503` during startup and shutdown.
- Requests from browser origins not on the configured allowlist are rejected with `403 Origin not allowed by CORS policy`.
- With `NODE_ENV=production`, browser access is denied by default unless `CORS_ALLOWED_ORIGINS` is set or `CORS_ALLOW_DEV_ORIGINS=true` is explicitly enabled.
- The checked-in `docker-compose.yml` is still a local/dev template. It seeds a localhost browser allowlist for common frontend ports and explicitly enables `DB_AUTO_MIGRATE=true`. Override both before reusing that file in any shared or internet-exposed environment.
- There is no refresh-token or `kid`-based key selection flow. Planned rotations can temporarily verify old tokens through `JWT_SECRET_PREVIOUS`, but all replicas still need a coordinated secret set.

## API Surface

- `POST /api/v1/auth/register`
- `POST /api/v1/auth/login`
- `POST /api/v1/auth/join`
- `POST /api/v1/auth/staff/login`
- `GET /api/v1/auth/me`
- `GET /api/v1/staff`
- `POST /api/v1/staff`
- `PATCH /api/v1/staff/:staffId`
- `POST /api/v1/staff/:staffId/pin`
- `POST /api/v1/staff/:staffId/deactivate`
- `POST /api/v1/staff/:staffId/reactivate`
- `GET /api/v1/products`
- `POST /api/v1/products`
- `PATCH /api/v1/products/:productId`
- `DELETE /api/v1/products/:productId`
- `GET /api/v1/sales`
- `POST /api/v1/sales`
- `GET /api/v1/money`
- `POST /api/v1/money/momo`
- `PATCH /api/v1/money/momo/:momoId`
- `POST /api/v1/money/momo/:momoId/match`
- `POST /api/v1/money/credits`
- `POST /api/v1/money/credits/:creditId/repay`
- `GET /api/v1/reports/summary`
- `POST /api/v1/sync/push`
- `GET /api/v1/sync/pull`
