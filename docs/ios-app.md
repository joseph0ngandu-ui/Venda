# iOS App

## Entry Point

File: `Venda/VendaApp.swift`

Startup behavior:

- Creates a shared `AppState`
- Creates shared view models for dashboard, sales, stock, and money
- Injects the Core Data managed object context
- Starts `SyncEngine.shared.startMonitoring()` during app initialization

## Root Shell

File: `Venda/App/AppShellView.swift`

Behavior:

- Shows `SplashScreen` on launch
- Shows a bootstrapping progress state while `AppState` restores or refreshes a session
- Routes to `OnboardingFlow` when `appState.isAuthenticated == false`
- Routes to `VendaTabBar` when `appState.isAuthenticated == true`

## App State

File: `Venda/App/AppState.swift`

State tracked globally:

- `isAuthenticated`
- `currentUser`
- `isBootstrapping`
- `authErrorMessage`

Defined staff roles:

- `owner`
- `admin`
- `manager`
- `cashier`

Auth behavior:

- `registerBusiness(...)` calls the backend register endpoint
- `loginMerchant(...)` calls the backend merchant login endpoint
- `joinBusiness(...)` calls the backend staff join endpoint
- `applyAuthenticatedSession(...)` persists the session, updates identity, ensures local Core Data merchant/staff records, and triggers sync
- `refreshSession()` and bootstrap both call `GET /auth/me` to refresh identity when a saved token exists

Session persistence now exists. `SessionStore` stores `AuthenticatedSession` in Keychain and migrates any legacy `UserDefaults` copy on first load.

## Onboarding And Auth UI

File: `Venda/Views/Onboarding/OnboardingFlow.swift`

Routes:

- `register`
- `joinBusiness`
- `pinSetup`
- `firstProduct`
- `login`

Current behavior:

- Registration flow collects business details, then PIN, then first product
- PIN completion calls `AppState.registerBusiness(...)`, which creates the backend account immediately
- Merchant login calls `AppState.loginMerchant(...)`
- Join-business calls `AppState.joinBusiness(...)`
- Successful registration stores the returned backend session in `pendingSession`
- The session is only applied to app state when the first-product step completes or is skipped
- The first-product step creates a local product through `StockViewModel` and then triggers sync

The auth screens are now wired to the backend API, but the first-product step is still local-first rather than part of the backend registration transaction.

## Main App Areas

File: `Venda/Views/VendaTabBar.swift`

Tabs:

- `home`: renders `SellScreen`
- `stock`: renders `StockScreen`
- `money`: renders `MoneyScreen`
- `more`: renders `MoreScreen`

### Sell

File: `Venda/Views/SellScreen.swift`

Responsibilities:

- Search available products from `StockViewModel`
- Add products to a cart
- Open price entry and payment selection sheets
- Complete a sale and generate a reference in `SaleViewModel`

### Stock

File: `Venda/Views/StockScreen.swift`

Responsibilities:

- Search product inventory
- Add products locally through `AddProductSheet`
- Present product rows based on `StockViewModel.products`

### Money

File: `Venda/Views/MoneyScreen.swift`

Responsibilities:

- Display MoMo reconciliation summaries
- Display credit book summaries
- Render from `MoneyViewModel`

### More

File: `Venda/Views/MoreScreen.swift`

Responsibilities:

- Settings and navigation hub
- Reports
- Staff and roles placeholder
- Account, notification, support, and legal placeholders
- Security and audit entry point through `PriceOverrideLogScreen`

## View Models

### `SaleViewModel`

File: `Venda/ViewModels/SaleViewModel.swift`

- Stores cart items
- Tracks selected payment method
- Generates sale references
- Uses `PricingService` to validate prices

### `StockViewModel`

File: `Venda/ViewModels/StockViewModel.swift`

- Reads products from `PersistenceService`
- Supports add, update, and delete operations through Core Data-backed persistence
- Reloads on Core Data save notifications

### `MoneyViewModel`

File: `Venda/ViewModels/MoneyViewModel.swift`

- Stores MoMo summary totals and transaction summaries
- Stores credit entry summaries
- Hydrates state from `PersistenceService.fetchMoneyState()`
- Reloads on Core Data save notifications

### `DashboardViewModel`

File: `Venda/ViewModels/DashboardViewModel.swift`

- Aggregates revenue, sales count, recent sales, and payment breakdown from persisted sales data

## Local Persistence

Files:

- `Venda/Models/CoreDataManager.swift`
- `Venda/Services/PersistenceService.swift`

Behavior:

- Creates the `VendaModel` persistent container
- Enables automatic migration
- Enables persistent history tracking
- Exposes the main view context and a background context
- Ensures the current merchant and staff exist in Core Data from the authenticated session
- Persists products, sales, MoMo transactions, and credit entries locally
- Applies sync pull payloads back into Core Data
- Uses `updatedAt` to track true local mutation time while `syncedAt` remains client sync bookkeeping

The app is positioned as offline-first, with Core Data intended to hold the local source of truth.

## Networking

File: `Venda/Services/NetworkService.swift`

Behavior:

- Exposes `register(...)`, `loginMerchant(...)`, `joinBusiness(...)`, `getMe(...)`, `fetchStaff(...)`, `createStaff(...)`, `updateStaff(...)`, and `fetchReportsSummary(...)`
- Parses token responses from the backend
- Resolves the API base URL in this order:
  - `VENDA_API_BASE_URL` process environment variable
  - `VENDA_API_BASE_URL` Info.plist key
  - `API_BASE_URL` Info.plist key
  - `venda.api.base.url` in `UserDefaults`
  - Built-in fallback hosted URL

Override guidance from source:

- Provide a full absolute base URL that already includes `/api/v1`
- The override must be present before app launch because `NetworkService.shared` resolves it during startup
- Invalid URL configuration triggers `fatalError`
- No App Transport Security exception is checked in for plain local `http://` endpoints

## Sync

File: `Venda/Services/SyncEngine.swift`

Behavior:

- Monitors network reachability via `NWPathMonitor`
- Triggers sync automatically when connectivity becomes available
- Pulls remote changes first, then pushes local unsynced changes
- Reads unsynced Core Data records
- Builds batch payloads for products, sales, sale line items, MoMo transactions, and credit entries
- Sends persisted local `updatedAt` values so outbound `updated_at` reflects the true local edit time for post-migration rows
- Sends sync requests through the same resolved API base URL as `NetworkService`
- Attaches `Authorization: Bearer <token>` to push and pull requests

Current limitations:

- Local entities are marked synced only on HTTP 200
- Protocol-level late offline uploads can still be missed by other devices because the backend filters pulls by the client-supplied `updated_at` timestamp
- Sync is triggered by connectivity changes and auth/session events, but there is no separate retry queue or background scheduler documented in the repo

## Domain Models

Representative app-side model:

- `Venda/Models/ProductModel.swift`: in-memory product definition for UI flows

The project also includes a Core Data model at `Venda/Models/VendaModel.xcdatamodeld`.
