# Backend

## Entry Point

File: `Backend/src/index.ts`

Startup sequence:

1. Load env vars with `dotenv`
2. Create the Express app
3. Enable `cors`
4. Enable JSON request parsing with a `10mb` limit
5. Mount API routes at `/api/v1`
6. Expose `GET /health`
7. Run database initialization
8. Start listening on `PORT` or `3000`

The server now exits on startup failure if database initialization throws.

## Scripts

File: `Backend/package.json`

- `npm run dev`: run the server via `nodemon`
- `npm run build`: compile TypeScript into `dist/`
- `npm start`: run the compiled server

There is no real test suite yet. The `test` script is still a placeholder.

## Environment Variables

Observed runtime variables:

- `PORT`: HTTP listen port
- `DATABASE_URL`: PostgreSQL connection string used by `pg`
- `JWT_SECRET`: signing and verification secret for auth tokens
- `NODE_ENV`: used in Docker, but not read directly in the app code

Docker defaults are defined in `Backend/docker-compose.yml`.

## Routing

File: `Backend/src/routes/api.ts`

Routes:

- `POST /api/v1/auth/register`
- `POST /api/v1/auth/login`
- `POST /api/v1/auth/join`
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

`/auth/me`, `/staff/*`, `/reports/summary`, `/sync/push`, and `/sync/pull` require JWT auth.

## Auth Flow

### Register

File: `Backend/src/controllers/auth.ts`

Request body:

- `business_name`
- `business_type`
- `phone`
- `pin`

Behavior:

- Rejects missing fields with `400`
- Rejects duplicate `phone` with `409`
- Hashes the merchant PIN using `bcryptjs`
- Creates a merchant row
- Creates a default admin staff row using the owner name
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
- Verifies the token using `JWT_SECRET`
- Resolves the live staff record from the database on every request when a token includes `staffId`
- Rejects deactivated staff even if they still hold an unexpired JWT
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
- Rolls back the full transaction if any insert/update fails

### Pull

Endpoint: `GET /api/v1/sync/pull?updated_after=<ISO8601>`

Behavior:

- Requires `updated_after`
- Returns rows updated after that timestamp
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

The API waits for the database health check before startup.
