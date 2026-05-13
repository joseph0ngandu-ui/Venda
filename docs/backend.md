# Backend

## Entry Point

File: `Backend/src/index.ts`

Startup sequence:

1. Load env vars through `src/config/env.ts`
2. Validate runtime config with `validateRuntimeConfig()`
3. Create the Express app
4. Apply same-origin plus allowlist-aware CORS rejection middleware
5. Enable `cors`
6. Enable JSON request parsing with a `10mb` limit
7. Mount API routes at `/api/v1`
8. Expose liveness and readiness endpoints at `/health`, `/live`, `/ready`, `/health/live`, and `/health/ready`
9. Either run `initDb()` or `verifyDbSchema()` depending on `DB_AUTO_MIGRATE`
10. Start listening on `PORT` or `3000`
11. Flip readiness off again during graceful shutdown and drain the HTTP server plus Postgres pool on `SIGTERM` / `SIGINT`

The server exits on startup failure if env validation or database migration/verification throws.

## Scripts

File: `Backend/package.json`

- `npm run dev`: run the server via `nodemon`
- `npm run build`: compile TypeScript into `dist/`
- `npm test`: run the backend regression test suite with Node's built-in test runner
- `npm run db:migrate`: compile the backend and apply the checked-in SQL migrations in `Backend/migrations/`
- `npm run db:verify`: compile the backend and confirm migration history plus required tables, sync cursor columns, and triggers already exist
- `npm run smoke:live`: apply migrations, boot the compiled backend in verification mode, and exercise health/auth/staff flows against a real Postgres instance
- `npm run smoke:live:local`: start the checked-in Docker Postgres service, build the backend, apply migrations, and run the live smoke path
- `npm start`: run the compiled server

The backend now includes a small regression test suite focused on auth, staff, and sync controller behavior.
Current checked-in coverage exercises:

- malformed registration payload rejection
- merchant JWT fallback to token claims when the live staff row no longer exists
- staff JWT rejection when the live staff row is missing
- staff update validation before database work starts
- unauthenticated sync push rejection before a database transaction is opened
- `updated_after` validation before sync pull queries run
- pull filtering on the server-side sync cursor instead of leaking propagation timing through API response fields
- synced staff role and timestamp normalization during push handling
- compiled startup against a live Postgres instance
- live `GET /health`
- live merchant registration, merchant login, and JWT-protected `GET /auth/me`
- live staff creation, staff listing, staff join/login, role change, deactivation/reactivation, and PIN rotation
- live sync push plus sync pull round-trip verification
- live reports summary verification for revenue, payment breakdown, top products, and recent sales

The unit tests still mock the pool layer for controller-level regressions, while the live smoke script covers migration, startup verification, and a broader production-like auth/team-management path.

## Environment Variables

Files:

- `Backend/.env.example`
- `Backend/src/config/env.ts`

Observed runtime variables:

- `DATABASE_URL`: required PostgreSQL connection string used by `pg`
- `JWT_SECRET`: required signing secret for auth tokens
- `JWT_SECRET_PREVIOUS`: optional comma-separated list of previous verification-only secrets during a signing-key rollout
- `DB_AUTO_MIGRATE`: optional schema mode flag; defaults to `true` outside production and `false` in production
- `PORT`: optional HTTP listen port, defaults to `3000`
- `NODE_ENV`: influences startup migration defaults and loopback-browser CORS defaults

`JWT_SECRET` validation details:

- Missing or empty secrets are rejected
- Placeholder/example secrets are rejected before the server starts
- JWT signing uses `JWT_SECRET`
- JWT verification accepts the current signing secret plus any `JWT_SECRET_PREVIOUS` entries
- Rotations can preserve still-valid older sessions temporarily if previous verification secrets remain configured until expiry

Rejected placeholder/example values currently include:

- `change_me_for_local_dev`
- `replace_with_a_long_random_secret`
- `venda_secret_key`
- `venda_production_secret_key_change_me`

Docker defaults are defined in `Backend/docker-compose.yml`, and Compose now requires `JWT_SECRET` to be set at substitution time.

## Live Smoke Path

Files:

- `Backend/scripts/live-smoke.js`
- `Backend/scripts/live-smoke-local.sh`
- `.github/workflows/backend-ci.yml`

Behavior:

- Runs the dedicated migration entrypoint first
- Starts the compiled backend on `SMOKE_PORT` or `3101` with `DB_AUTO_MIGRATE=false`
- Waits for `GET /health` to report `{ status: "ok" }`
- Waits for `GET /ready` to report `{ status: "ready", checks: { database: "ok" } }`
- Registers a uniquely named merchant against the live Postgres database
- Logs that merchant in through the public auth endpoint
- Calls `GET /api/v1/auth/me` with the returned bearer token
- Creates a staff member, verifies list permissions, joins as staff, promotes the staff account, enforces deactivate/reactivate behavior, and rotates the staff PIN
- Pushes a product/sale/sale-line-item batch through `/sync/push` and verifies the same records come back through `/sync/pull`
- Confirms `/reports/summary` reflects the synced sale in totals, payment breakdown, top products, and recent sales
- Deletes the temporary merchant row at the end so repeated runs do not accumulate smoke-test tenants

CI now runs the same script against a Postgres 15 service container after an explicit `npm run db:migrate`, and it also builds the production Docker image, so migration wiring, startup verification, bcrypt/JWT auth, container packaging, and core team-management flows are exercised on every backend workflow run.

## Deployment Notes

- `Backend/.env.example` and `Backend/docker-compose.yml` are local/dev templates with checked-in local Postgres settings. Treat them as starting points, not production manifests.
- Keep `DB_AUTO_MIGRATE=false` in production so API startup verifies schema instead of running DDL on every boot.
- Run `npm run db:migrate` as a separate deployment step before rolling new application pods/instances.
- The checked-in migration runner now reads versioned SQL files from `Backend/migrations/`, records filename/checksum metadata in `schema_migrations`, and applies migrations under a PostgreSQL advisory lock.
- The migration history is still minimal and does not yet include rollback orchestration, so schema rollouts still need extra operator discipline.
- Requests from browser origins outside the configured allowlist are rejected with `403 Origin not allowed by CORS policy`.
- There is no refresh-token or `kid`-based signing-key selection flow. All replicas still need a coordinated `JWT_SECRET` / `JWT_SECRET_PREVIOUS` set during rollouts.

## Routing

File: `Backend/src/routes/api.ts`

Routes:

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

`/auth/me`, `/staff/*`, `/products/*`, `/sales/*`, `/money/*`, `/reports/summary`, `/sync/push`, and `/sync/pull` require JWT auth.

## Auth Flow

### Register

File: `Backend/src/controllers/auth.ts`

Request body:

- `owner_name` (optional, defaults to `Owner`)
- `business_name`
- `business_type`
- `phone`
- `pin`

Behavior:

- Rejects missing fields with `400`
- Rejects duplicate `phone` with `409`
- Hashes the merchant PIN using `bcryptjs`
- Creates a merchant row
- Creates a default admin staff row using `owner_name` or `Owner`
- Sets the owner staff `last_login_at` and `pin_updated_at`
- Signs a JWT containing merchant and active staff identity
- Returns merchant data, staff data, permissions, and the token with `201`

### Login

File: `Backend/src/controllers/auth.ts`

Request body:

- `phone`
- `pin`

Behavior:

- Looks up the merchant by phone
- Compares the provided PIN with the stored hash
- Returns `401` for invalid credentials
- Loads the primary active staff record for that merchant
- Updates `last_login_at` for the resolved staff record
- Signs a JWT containing merchant plus active staff claims
- Returns merchant profile, staff profile, permissions, and the token

### Staff Join / Staff Login

File: `Backend/src/controllers/auth.ts`

Endpoints:

- `POST /api/v1/auth/join`
- `POST /api/v1/auth/staff/login`

Request body:

- `company_code`
- `pin`

Behavior:

- Resolves the merchant from the shareable company code
- Searches active staff accounts for a matching PIN hash
- Rejects unknown company codes with `404`
- Rejects invalid credentials with `401`
- Updates `last_login_at` for the matched staff account
- Returns the same auth payload shape as merchant login

### JWT Middleware

File: `Backend/src/middleware/auth.ts`

Behavior:

- Reads the `Authorization` header
- Expects `Bearer <token>`
- Verifies the token using the validated runtime secret set from `JWT_SECRET` plus any `JWT_SECRET_PREVIOUS` entries
- Resolves the live staff record from the database on every request when a token includes `staffId`
- Allows merchant-authenticated tokens to fall back to embedded staff claims when the live staff row is missing
- Rejects deactivated staff even if they still hold an unexpired JWT
- Rejects staff-authenticated tokens if the live staff row is missing or inactive
- Attaches merchant and staff identity to the request
- Returns `401` if no auth header is present
- Returns `403` if verification fails

### Team Authorization

File: `Backend/src/middleware/auth.ts`

Helpers:

- `requireTeamManagementAccess`: allows `admin` and `manager`
- `requireAdminAccess`: allows `admin` only

These are used by the new staff management routes so role changes take effect immediately.

## Staff Management

File: `Backend/src/controllers/staff.ts`

Implemented behavior:

- `GET /api/v1/staff`
  - Lists the merchant team ordered by active status and role
  - Returns `company_code`, caller permissions, summary counts, and staff records
- `POST /api/v1/staff`
  - Admin-only
  - Creates a new active staff record with hashed PIN
  - Captures `created_by_staff_id`
- `PATCH /api/v1/staff/:staffId`
  - Admin-only
  - Supports name updates, role changes, and `is_active` changes
  - Prevents removing or demoting the last active admin
- `POST /api/v1/staff/:staffId/pin`
  - Admins can rotate any staff PIN
  - Non-admin staff can rotate only their own PIN and must supply `current_pin`
- `POST /api/v1/staff/:staffId/deactivate`
  - Admin-only
  - Prevents self-deactivation and prevents removing the last active admin
- `POST /api/v1/staff/:staffId/reactivate`
  - Admin-only
  - Restores the account and clears `deactivated_at`

## Sync Flow

File: `Backend/src/controllers/sync.ts`

### Push

Endpoint: `POST /api/v1/sync/push`

Accepted top-level arrays:

- `products`
- `sales`
- `sale_line_items`
- `momo_transactions`
- `credit_entries`
- `staff`

Behavior:

- Starts a transaction
- Upserts rows for each entity type
- Uses the authenticated merchant id as the tenancy boundary
- Treats staff sync as metadata-only unless a hashed PIN is explicitly supplied
- Preserves client `updated_at` as the mutation timestamp while the database tracks propagation recency separately via `server_updated_at`
- Rolls back the full transaction if any insert/update fails

### Pull

Endpoint: `GET /api/v1/sync/pull?updated_after=<ISO8601>`

Behavior:

- Requires `updated_after`
- Returns rows whose server-side sync cursor advanced after that timestamp
- Scopes all results to the authenticated merchant
- Joins `sale_line_items` through `sales` to enforce merchant scoping
- Returns explicit staff columns and does not expose `pin_hash`

Response shape:

- `timestamp`
- `data.products`
- `data.sales`
- `data.sale_line_items`
- `data.staff`
- `data.momo_transactions`
- `data.credit_entries`

## Database Schema

File: `Backend/src/config/db.ts`

The backend creates schema objects on startup instead of using migrations.

Tables:

- `merchants`
- `staff`
- `products`
- `sales`
- `sale_line_items`
- `momo_transactions`
- `credit_entries`

Common schema patterns:

- UUID primary keys
- `server_updated_at` as an internal backend sync cursor on sync-participating tables
- `created_at` and `updated_at` timestamps
- merchant scoping through `merchant_id`
- `updated_at` triggers generated by `update_updated_at_column()`

Staff-specific metadata now includes:

- `created_by_staff_id`
- `last_login_at`
- `pin_updated_at`
- `deactivated_at`

Key constraints:

- `merchants.phone` is unique
- `sales` enforces unique `(merchant_id, reference)`
- `momo_transactions` enforces unique `(merchant_id, transaction_ref)`

## Docker Topology

File: `Backend/docker-compose.yml`

Services:

- `venda-api`: builds from the local Dockerfile and exposes port `3000`
- `venda-db`: Postgres 15 Alpine and exposes port `5432`

Operational notes:

- The API waits for the database health check before startup
- Compose injects `DATABASE_URL` for the containerized database host
- Compose requires `JWT_SECRET` to be set and no longer falls back to a default secret
- The checked-in compose database credentials are suitable for local/dev use only
