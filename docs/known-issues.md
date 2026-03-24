# Known Issues

Verified against the repository on March 24, 2026.

## iOS Build Failure

Files:

- `Venda/Views/Onboarding/JoinBusinessScreen.swift`

Issue:

- `xcodebuild -scheme Venda -project Venda.xcodeproj -destination 'generic/platform=iOS Simulator' build` currently fails
- The observed compiler error is `type 'TextInputAutocapitalization' has no member 'allCharacters'`
- The failure is triggered from `JoinBusinessScreen.swift`

## Hard-Coded Backend URLs In iOS

Files:

- `Venda/Services/NetworkService.swift`
- `Venda/Services/SyncEngine.swift`

Issue:

- Both services point to a fixed Tailscale Funnel URL
- Local backend development is not configurable from project settings or environment-specific config

## Incomplete Backend Wiring In Onboarding

File:

- `Venda/Views/Onboarding/OnboardingFlow.swift`

Issue:

- Registration and login flows still complete using mocked users
- The backend auth API exists, but the onboarding UI is not yet integrated with it

## Partial Client Sync Implementation

File:

- `Venda/Services/SyncEngine.swift`

Issue:

- Only part of the outbound payload is mapped
- Authorization is not attached
- Full round-trip sync behavior is not implemented yet

## Mixed State Sources In The iOS App

Files:

- `Venda/App/AppState.swift`
- `Venda/ViewModels/StockViewModel.swift`
- `Venda/ViewModels/SaleViewModel.swift`
- `Venda/ViewModels/MoneyViewModel.swift`
- `Venda/Models/CoreDataManager.swift`

Issue:

- The app currently splits behavior across environment state, in-memory view model arrays, and Core Data entities
- This makes end-to-end persistence and sync behavior incomplete in the current implementation

## No Automated Tests

Files:

- `Backend/package.json`
- `VendaTests/`
- `VendaUITests/`

Issue:

- The backend `test` script is a placeholder
- Test targets exist on the iOS side, but the repository does not currently show an active automated test workflow

## Role Naming Drift

Files:

- `Backend/src/controllers/auth.ts`
- `Venda/App/AppState.swift`

Issue:

- The backend creates a default staff role of `owner`
- The iOS app defines roles as `admin`, `manager`, and `cashier`

This mismatch will need normalization before backend-driven role logic is added.
