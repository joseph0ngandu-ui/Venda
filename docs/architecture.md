# Architecture

## High-Level Shape

Venda is split into two main parts:

- An iOS SwiftUI client for onboarding, point-of-sale, stock, money, and settings flows
- A Node.js backend that stores merchant data in PostgreSQL and exposes auth and sync endpoints

## Data Ownership

- The iOS app uses Core Data for local persistence and offline-first behavior
- The backend is the central server-side store for merchants, staff, products, sales, payments, and credit records
- Sync is designed as push/pull batch transport between the local Core Data store and PostgreSQL

## Backend Runtime Model

- `Backend/src/index.ts` loads environment variables, configures Express, mounts `/api/v1`, initializes the database schema, then starts listening
- `Backend/src/config/db.ts` creates a shared `pg` pool and executes schema creation SQL at startup
- `Backend/src/routes/api.ts` exposes auth and sync routes
- `Backend/src/controllers/auth.ts` handles merchant registration, login, and profile lookup
- `Backend/src/controllers/sync.ts` handles batch sync push and incremental sync pull

## iOS Runtime Model

- `Venda/VendaApp.swift` is the app entry point
- The app creates shared environment objects for app state and view models
- `Venda/App/AppShellView.swift` switches between onboarding and the main tab UI based on `AppState.isAuthenticated`
- `Venda/Views/Onboarding/OnboardingFlow.swift` owns registration, join-business, and login navigation
- `Venda/Views/VendaTabBar.swift` switches between the main app surfaces: sell, stock, money, and more

## Current Design State

- The backend is functional enough to build and start when its database configuration is valid
- The iOS app has most screen structure in place, but several flows are still mocked rather than backed by the API
- Sync is only partially implemented on the client side
