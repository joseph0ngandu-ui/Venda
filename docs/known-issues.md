# Known Issues

Verified against the working tree on April 2, 2026.

## Default iOS API Target Still Falls Back To Hosted Backend

Files:

- `Venda/Services/NetworkService.swift`
- `Venda.xcodeproj/project.pbxproj`

Issue:

- The app still ships with a built-in hosted fallback URL: `https://homeserver.taildbc5d3.ts.net/api/v1`
- Source code supports overrides, but no shared scheme setting or checked-in Info.plist key is configured in the project
- The project also does not include an App Transport Security exception for plain local `http://` endpoints

## Registration Session Is Deferred Until After First-Product Step

Files:

- `Venda/Views/Onboarding/OnboardingFlow.swift`

Issue:

- `POST /auth/register` is called as soon as PIN setup succeeds
- The returned session is kept only in memory as `pendingSession` until the first-product screen completes or is skipped
- If onboarding is interrupted after account creation, the backend account exists but the local authenticated session is not yet stored

## Limited Automated Coverage

Files:

- `Backend/package.json`
- `Backend/scripts/live-smoke.js`
- `VendaTests/`
- `VendaUITests/`

Issue:

- The backend now has a small unit-level regression suite for auth, staff, and sync flows
- The backend also now has a live Postgres smoke path for startup, health, merchant registration, merchant login, and `GET /auth/me`
- Backend automation still does not cover broader multi-endpoint workflows such as sync round-trips, staff management lifecycle changes, or failure-mode retries against a live database
- The repository now includes backend CI and an iOS build-verification workflow, but the iOS lane is still build-only and does not run simulator tests

## Historical Late Offline Uploads May Still Need A Broader Resync

Files:

- `Venda/Services/SyncEngine.swift`
- `Venda/Services/PersistenceService.swift`
- `Backend/src/controllers/sync.ts`

Issue:

- The iOS app now persists a real local `updatedAt` timestamp and sends that value in outbound sync payloads
- The backend now tracks a separate `server_updated_at` cursor and `GET /sync/pull` filters on that server-side propagation timestamp
- Rows that were inserted late before this backend change are not fully recoverable through incremental sync alone, so some existing devices may still need a broader resync to catch already-missed historical records

## Legacy `owner` Role Still Exists In iOS Types

Files:

- `Venda/App/AppState.swift`
- `Backend/src/middleware/auth.ts`

Issue:

- The iOS `StaffRole` enum still includes `owner`
- Backend auth normalizes `owner` to `admin` and new registrations now create admin staff directly
- Any legacy locally stored role values should continue to be handled carefully if older sessions are still in circulation

## JWT Secret Rotation Forces Reauthentication

Files:

- `Backend/src/config/env.ts`
- `Backend/src/controllers/auth.ts`

Issue:

- The backend uses a single `JWT_SECRET` for both token signing and verification
- There is no refresh-token or key-rollover mechanism in the current codebase
- Any secret change, or any mismatch between deployed replicas, invalidates active sessions immediately

## Backend Startup Still Performs Schema Mutation

Files:

- `Backend/src/index.ts`
- `Backend/src/config/db.ts`

Issue:

- Every successful boot runs `initDb()` before the API begins serving traffic
- `initDb()` executes schema bootstrap SQL with `CREATE TABLE`, `ALTER TABLE`, trigger recreation, and data backfill statements
- Operators still need rollout discipline, backups, and a database user with the required DDL permissions

## Backend CORS Policy Is Still Wide Open

Files:

- `Backend/src/index.ts`

Issue:

- The backend currently enables `cors()` with default permissive behavior for all origins
- There is no checked-in origin allowlist or environment-driven CORS configuration yet
- Production deployments need proxy or network-layer restrictions until the application adds explicit origin controls
