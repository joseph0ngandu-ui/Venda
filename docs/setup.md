# Setup

## Repository Layout

- `Backend/`: Express + TypeScript API with PostgreSQL
- `Venda/`: SwiftUI iOS app
- `Venda.xcodeproj/`: Xcode project

## Backend

### Requirements

- Node.js 20+
- npm
- PostgreSQL 15+ or Docker

### Install

```bash
cd Backend
npm install
```

### Run Locally

The backend expects these environment variables:

- `PORT`
- `DATABASE_URL`
- `JWT_SECRET`

Typical local run flow:

```bash
cd Backend
npm run dev
```

Typical production build flow:

```bash
cd Backend
npm run build
npm start
```

### Run With Docker

```bash
cd Backend
docker compose up --build
```

The compose file starts:

- `venda-api` on port `3000`
- `venda-db` on port `5432`

## iOS App

### Requirements

- Xcode
- iOS Simulator or physical iPhone target supported by the project

### Open And Run

1. Open `Venda.xcodeproj`.
2. Select the `Venda` scheme.
3. Build and run the app on a simulator.

### Command Line Build

```bash
xcodebuild -scheme Venda -project Venda.xcodeproj -destination 'generic/platform=iOS Simulator' build
```

## Verification Status

Verified in this repository on March 24, 2026:

- `cd Backend && npm run build` succeeds
- `xcodebuild -scheme Venda -project Venda.xcodeproj -destination 'generic/platform=iOS Simulator' build` succeeds

See `known-issues.md` for current runtime and integration gaps.
