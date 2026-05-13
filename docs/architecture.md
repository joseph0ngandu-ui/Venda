# Architecture

## High-Level Shape

Venda is split into three main parts:

- An iOS SwiftUI client for onboarding, point-of-sale, stock, money, and settings flows
- A React/Vite PWA in `Web/` for browser and installable web-app use
- A Node.js backend that stores merchant data in PostgreSQL and exposes auth, REST, report, and sync endpoints

## Data Ownership

- The iOS app uses Core Data for local persistence and offline-first behavior
- The backend is the central server-side store for merchants, staff, products, sales, payments, and credit records
- The web app uses REST endpoints for live product, sale, money, report, and staff workflows
- Sync is designed as push/pull batch transport between the local Core Data store and PostgreSQL

## Backend Runtime Model

- `Backend/src/index.ts` loads environment variables, configures Express, mounts `/api/v1`, exposes liveness/readiness endpoints, then either applies schema bootstrap or verifies an already-migrated database before listening
- `Backend/src/config/migrations.ts` discovers checked-in SQL migrations, applies them transactionally under a PostgreSQL advisory lock, and verifies filename/checksum metadata in `schema_migrations`
- `Backend/src/config/db.ts` creates a shared `pg` pool and exposes migration-aware schema verification, readiness, and shutdown helpers for startup and operator scripts
- `Backend/src/scripts/db-migrate.ts` and `Backend/src/scripts/db-verify.ts` provide out-of-band database lifecycle commands for production-style deploys
- `Backend/src/routes/api.ts` exposes auth, product, sales, money, staff, reporting, and sync routes
- `Backend/src/controllers/auth.ts` handles merchant registration, login, and profile lookup
- `Backend/src/controllers/sync.ts` handles batch sync push and incremental sync pull
- `Backend/src/controllers/reports.ts` aggregates revenue, payment breakdown, product, and trend data from sales tables

## Web Runtime Model

- `Web/src/App.tsx` owns onboarding, authenticated shell navigation, POS cart state, and full-page workspace surfaces
- `Web/src/api.ts` talks to `/api/v1` by default, so production traffic is same-origin through Nginx while local Vite dev proxies `/api`
- `Web/public/manifest.webmanifest` and `Web/public/sw.js` make the app installable and cache the shell for offline launch
- `Web/nginx.conf` serves static assets, falls back to `index.html`, and proxies `/api/` to the backend container

## iOS Runtime Model

- `Venda/VendaApp.swift` is the app entry point
- The app creates shared environment objects for app state and view models
- `Venda/App/AppShellView.swift` switches between onboarding recovery and the main tab UI based on authenticated session plus pending onboarding state
- `Venda/Views/Onboarding/OnboardingFlow.swift` owns registration, join-business, and login navigation
- `Venda/Views/VendaTabBar.swift` switches between the main app surfaces: sell, stock, money, and more

## Current Design State

- The backend is functional enough to build and start when its database configuration is valid
- The backend now supports production-style migration-then-verify startup, graceful shutdown, readiness checks, and live smoke coverage across auth, staff lifecycle, sync, and reports
- The iOS app has most screen structure in place, and auth/team/reporting flows are increasingly backed by the API, but not every experience is end-to-end verified yet
- Sync is partially implemented on the client side, with the protocol more robust than before but still not fully exhausted by device-level testing
