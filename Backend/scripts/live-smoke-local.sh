#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is required for npm run smoke:live:local" >&2
  exit 1
fi

echo "[smoke-local] Starting venda-db via docker compose"
docker compose up -d venda-db

echo "[smoke-local] Waiting for Postgres health"
attempt=0
until docker compose exec -T venda-db pg_isready -U venda_user -d venda >/dev/null 2>&1; do
  attempt=$((attempt + 1))
  if [ "$attempt" -ge 60 ]; then
    echo "[smoke-local] Timed out waiting for venda-db to become ready" >&2
    exit 1
  fi
  sleep 1
done

: "${DATABASE_URL:=postgres://venda_user:venda_pass_2026@localhost:5432/venda}"
export DATABASE_URL

echo "[smoke-local] Building backend"
npm run build

echo "[smoke-local] Running live backend smoke"
npm run smoke:live
