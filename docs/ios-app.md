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
- Routes to `OnboardingFlow` when `appState.isAuthenticated == false`
- Routes to `VendaTabBar` when `appState.isAuthenticated == true`

## App State

File: `Venda/App/AppState.swift`

State tracked globally:

- `isAuthenticated`
- `currentUser`
- `hasCompletedOnboarding`

Defined staff roles:

- `admin`
- `manager`
- `cashier`

Current state persistence is not implemented. Comments indicate this should eventually move to Keychain or `UserDefaults`.

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
- Join-business flow logs in a mocked cashier user
- Login flow logs in a mocked staff user
- Completing onboarding logs in a mocked owner user

The current onboarding flow is UI-complete enough to navigate, but it is not wired to the backend auth API yet.

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

- Owns the in-memory product list
- Supports add, update, and delete operations

### `MoneyViewModel`

File: `Venda/ViewModels/MoneyViewModel.swift`

- Stores MoMo summary totals and transaction summaries
- Stores credit entry summaries
- `refreshData()` is currently a placeholder

### `DashboardViewModel`

File: `Venda/ViewModels/DashboardViewModel.swift`

- Aggregates revenue, sales count, recent sales, and payment breakdown

## Local Persistence

File: `Venda/Models/CoreDataManager.swift`

Behavior:

- Creates the `VendaModel` persistent container
- Enables automatic migration
- Enables persistent history tracking
- Exposes the main view context and a background context

The app is positioned as offline-first, with Core Data intended to hold the local source of truth.

## Networking

File: `Venda/Services/NetworkService.swift`

Behavior:

- Exposes `register(...)` and `login(...)`
- Calls a hard-coded Tailscale Funnel backend URL
- Parses token responses from the backend

The base URL is not environment-driven yet.

## Sync

File: `Venda/Services/SyncEngine.swift`

Behavior:

- Monitors network reachability via `NWPathMonitor`
- Triggers sync automatically when connectivity becomes available
- Reads unsynced Core Data records
- Builds a partial batch payload
- Sends sync push requests to a hard-coded backend URL

Current limitations:

- Only product payload mapping is implemented
- Auth header injection is still commented out
- Local entities are marked synced only on HTTP 200

## Domain Models

Representative app-side model:

- `Venda/Models/ProductModel.swift`: in-memory product definition for UI flows

The project also includes a Core Data model at `Venda/Models/VendaModel.xcdatamodeld`.
