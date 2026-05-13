# Known Issues

Verified against the working tree on April 4, 2026.

## Default iOS API Target Still Falls Back To Hosted Backend

Files:

- `Venda/Services/NetworkService.swift`
- `Venda.xcodeproj/project.pbxproj`

Issue:

- The app still ships with a built-in hosted fallback URL: `https://venda.kynto.me/api/v1`
- The Xcode project now checks in a generated Info.plist key path for `VENDA_API_BASE_URL`, but the default build setting is still blank
- The project now enables `NSAllowsLocalNetworking`, so local `http://` development is less fragile than before
- Release ownership of the backend URL still depends on explicit build configuration rather than a checked-in per-environment config strategy

## Onboarding Recovery Stores Temporary Credentials For Resume

Files:

- `Venda/App/AppState.swift`
- `Venda/App/OnboardingRecoveryStore.swift`
- `Venda/Views/Onboarding/OnboardingFlow.swift`

Issue:

- Registration now persists the authenticated session immediately and can resume the first-product step after interruption
- To support crash/relaunch recovery, the app stores a temporary registration recovery payload containing phone + PIN in keychain-protected storage for up to 7 days
- Offline relaunch still cannot finish automatic recovery until the backend is reachable again

## Limited Automated Coverage

Files:

- `Backend/package.json`
- `Backend/scripts/live-smoke.js`
- `VendaTests/`
- `VendaUITests/`

Issue:

- The backend now has a unit-level regression suite for auth, staff, sync, and runtime config
- The backend also now has a live Postgres smoke path for migration, startup verification, merchant auth, staff lifecycle, sync round-trips, and reports summary against a real Postgres instance
- The repository now includes backend CI that also builds the production Docker image, plus an iOS workflow that builds the app target and runs unit tests on a simulator
- Automation still does not cover failure-mode retries, UI tests, or broader end-to-end iOS flows against a live backend

## Historical Late Offline Uploads May Still Need A Broader Resync

Files:

- `Venda/Services/SyncEngine.swift`
- `Venda/Services/PersistenceService.swift`
- `Backend/src/controllers/sync.ts`

Issue:

- The iOS app now persists a real local `updatedAt` timestamp and sends that value in outbound sync payloads
- The backend now tracks a separate `server_updated_at` cursor and `GET /sync/pull` filters on that server-side propagation timestamp
- Rows that were inserted late before this backend change are not fully recoverable through incremental sync alone, so some existing devices may still need a broader resync to catch already-missed historical records

## JWT Rotation Still Lacks Full Key-Management Ergonomics

Files:

- `Backend/src/config/env.ts`
- `Backend/src/controllers/auth.ts`

Issue:

- The backend now supports `JWT_SECRET_PREVIOUS` for verification-only rollovers, so planned rotations do not have to force immediate reauthentication
- Signing still happens only with the current `JWT_SECRET`, and there is no `kid`-based key selection, refresh-token flow, or automatic key retirement
- Operators still need coordinated rollout discipline so every replica shares the same current-plus-previous secret set during transitions

## Backend Migrations Are Still Early-Stage

Files:

- `Backend/migrations/0001_initial_schema.sql`
- `Backend/src/config/migrations.ts`
- `Backend/src/scripts/db-migrate.ts`

Issue:

- Production now defaults to schema verification on startup and expects operators to run `npm run db:migrate` out of band first
- The repo now has file-backed versioned migrations with checksum metadata and an advisory lock, but the history is still only a minimal bootstrap baseline with no rollback story
- Operators still need rollout discipline, backups, and a database user with the required DDL permissions when running the migration job

## Backend CORS Still Needs Explicit Production Allowlist Ownership

Files:

- `Backend/src/index.ts`
- `Backend/src/config/env.ts`

Issue:

- Browser-origin access is now environment-driven and denied by default in production unless `CORS_ALLOWED_ORIGINS` is configured
- Native and server-to-server traffic without an `Origin` header is still allowed by default through `CORS_ALLOW_NO_ORIGIN=true`
- Operators still need to set and maintain the correct production browser allowlist for each environment
