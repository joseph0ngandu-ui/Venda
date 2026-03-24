# Backend Setup

This backend is a small Express + TypeScript API backed by PostgreSQL.

## Requirements

- Node.js 20+
- npm
- PostgreSQL 15+ or Docker

## Quick Start With Docker

```bash
docker compose up --build
```

The API will be available at `http://localhost:3000` and will create its schema automatically on startup.

## Local Development

1. Copy the environment template:

```bash
cp .env.example .env
```

2. Start PostgreSQL and create a database named `venda`.
3. Update `DATABASE_URL` in `.env` if your local username, password, host, or port differ.
4. Install dependencies and run the API:

```bash
npm install
npm run dev
```

## Useful Commands

```bash
npm run dev
npm run build
npm start
```

## API Surface

- `POST /api/v1/auth/register`
- `POST /api/v1/auth/login`
- `GET /api/v1/auth/me`
- `POST /api/v1/sync/push`
- `GET /api/v1/sync/pull`
