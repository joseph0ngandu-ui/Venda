# Venda

Venda is a mixed codebase with:

- An iOS SwiftUI app in `Venda/`
- A Node.js + TypeScript backend in `Backend/`

## Repo Setup

### Backend

```bash
cd Backend
cp .env.example .env
npm install
docker compose up --build
```

If you prefer running Postgres yourself, see `Backend/README.md`.

### iOS App

1. Open `Venda.xcodeproj` in Xcode.
2. Select the `Venda` scheme.
3. Run on an iOS Simulator.

## Verification

- Backend TypeScript build: `cd Backend && npm run build`
- iOS build: `xcodebuild -scheme Venda -project Venda.xcodeproj -destination 'generic/platform=iOS Simulator' build`

## Notes

- The backend initializes its PostgreSQL schema on startup.
- The iOS app currently points at a hosted API URL in the networking layer.
