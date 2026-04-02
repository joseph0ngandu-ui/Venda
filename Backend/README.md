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

The API will be available at `http://localhost:3000` and will create its schema automatically on startup. Docker Compose reads `.env` for variable substitution and now fails fast if `JWT_SECRET` is unset.
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

To run the live Postgres smoke path locally against the checked-in Docker database service:

```bash
npm run smoke:live:local
```

That wrapper starts `venda-db`, builds the backend, boots the compiled server on port `3101`, exercises `GET /health`, `POST /api/v1/auth/register`, `POST /api/v1/auth/login`, and `GET /api/v1/auth/me`, then deletes the temporary merchant it created.
If you already have Postgres running and a built `dist/`, you can run the reusable smoke runner directly:

```bash
npm run build
npm run smoke:live
```

## Useful Commands

```bash
npm run dev
npm run build
npm test
npm run smoke:live
npm run smoke:live:local
npm start
```

Runtime config notes:

- `DATABASE_URL` is required.
- `JWT_SECRET` is required and must not be empty.
- Placeholder/example secrets such as `change_me_for_local_dev`, `replace_with_a_long_random_secret`, and legacy fallback values are rejected during startup.
- `PORT` is optional and defaults to `3000`.
- `PORT`, when set, must be an integer between `1` and `65535`.
- `JWT_SECRET` is the single secret used for both signing and verification. Tokens currently expire after 30 days, and rotating the secret forces every client to sign in again.
- `CORS_ALLOWED_ORIGINS` is optional and accepts a comma-separated list of exact `http://` or `https://` origins. Wildcards, paths, query strings, fragments, and the literal `null` origin are rejected during startup validation.
- `CORS_ALLOW_DEV_ORIGINS` is optional. It defaults to `true` outside production and `false` in production. When enabled, localhost loopback browser origins are allowed automatically for local development.
- `CORS_ALLOW_NO_ORIGIN` is optional and defaults to `true` so native apps and server-to-server clients that do not send an `Origin` header continue to work.

## Deployment Preflight

Before promoting a build or pointing the iOS app at a new backend:

- Run `npm run build`.
- Run `npm test`.
- Run `npm run smoke:live` against the target Postgres wiring, or `npm run smoke:live:local` for the checked-in local Docker database.
- Confirm `.env` contains the correct `DATABASE_URL` and a unique `JWT_SECRET` for that environment.
- Confirm `CORS_ALLOWED_ORIGINS` matches the exact browser origins that should be able to call the API in that environment.
- Confirm the target database user can execute the startup schema/bootstrap SQL in `src/config/db.ts`.

Test coverage snapshot:

- `Backend/test/auth.test.ts` covers malformed register payloads plus merchant-versus-staff JWT handling when the live staff row is missing.
- `Backend/test/staff.test.ts` covers invalid `is_active` validation and non-object update payload handling before database work begins.
- `Backend/test/sync.test.ts` covers unauthenticated sync rejection, `updated_after` validation, server-cursor-based pull filtering, and synced staff role/timestamp normalization.
- `Backend/scripts/live-smoke.js` boots the compiled server against a real Postgres instance and validates health, merchant registration, merchant login, and `GET /auth/me`.
- `.github/workflows/backend-ci.yml` runs that same live smoke path in CI with a Postgres 15 service container.

## Operational Notes

- The server runs schema bootstrap SQL on every boot. Treat startup as a schema-changing operation and stage/backup accordingly.
- Requests from browser origins not on the configured allowlist are rejected with `403 Origin not allowed by CORS policy`.
- With `NODE_ENV=production`, browser access is denied by default unless `CORS_ALLOWED_ORIGINS` is set or `CORS_ALLOW_DEV_ORIGINS=true` is explicitly enabled.
- The checked-in `docker-compose.yml` is still a local/dev template and seeds a localhost browser allowlist for common frontend ports. Override `CORS_ALLOWED_ORIGINS` before reusing that file in any shared or internet-exposed environment.
- There is no refresh-token or key-rollover flow. A mismatched `JWT_SECRET` between replicas or an intentional secret rotation will invalidate existing sessions immediately.

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
- `GET /api/v1/reports/summary`
- `POST /api/v1/sync/push`
- `GET /api/v1/sync/pull`
