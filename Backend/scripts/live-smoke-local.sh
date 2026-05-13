#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is required for npm run smoke:live:local" >&2
  exit 1
fi

: "${JWT_SECRET:=venda-smoke-local-secret-2026-04-04}"
export JWT_SECRET

fallback_container=""
fallback_port=""
db_ready_timeout_seconds=120

cleanup() {
  if [ -n "$fallback_container" ]; then
    docker rm -f "$fallback_container" >/dev/null 2>&1 || true
  fi
}

trap cleanup EXIT

cleanup_stale_fallback_containers() {
  local stale_containers
  stale_containers="$(docker ps -aq --filter "name=venda-smoke-db-")"

  if [ -z "$stale_containers" ]; then
    return
  fi

  echo "[smoke-local] Removing stale disposable Postgres containers"
  # shellcheck disable=SC2086
  docker rm -f $stale_containers >/dev/null 2>&1 || true
}

port_is_available() {
  local port="$1"

  if command -v ss >/dev/null 2>&1; then
    if ss -ltn "sport = :${port}" 2>/dev/null | grep -q 'LISTEN'; then
      return 1
    fi
    return
  fi

  if command -v lsof >/dev/null 2>&1; then
    if lsof -iTCP:"${port}" -sTCP:LISTEN >/dev/null 2>&1; then
      return 1
    fi
    return
  fi

  return 0
}

wait_for_compose_db() {
  local compose_container_id
  compose_container_id="$(docker compose ps -q venda-db)"

  if [ -z "$compose_container_id" ]; then
    echo "[smoke-local] Could not resolve the venda-db compose container id" >&2
    exit 1
  fi

  wait_for_container_health "$compose_container_id" "venda-db"
}

wait_for_container_health() {
  local container_name="$1"
  local label="$2"
  local attempt=0
  local health_status=""

  while true; do
    health_status="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$container_name" 2>/dev/null || true)"

    if [ "$health_status" = "healthy" ]; then
      return
    fi

    attempt=$((attempt + 1))
    if [ "$attempt" -ge "$db_ready_timeout_seconds" ]; then
      echo "[smoke-local] Timed out waiting for ${label} to become ready" >&2
      docker logs "$container_name" >&2 || true
      exit 1
    fi

    sleep 1
  done
}

start_fallback_db() {
  local port

  for port in $(seq 55432 55460); do
    if ! port_is_available "$port"; then
      continue
    fi

    fallback_container="venda-smoke-db-${RANDOM}-${RANDOM}"

    echo "[smoke-local] Port 5432 is busy; starting disposable Postgres on port ${port}" >&2
    if docker run -d --rm \
      --name "$fallback_container" \
      -e POSTGRES_USER=venda_user \
      -e POSTGRES_PASSWORD=venda_pass_2026 \
      -e POSTGRES_DB=venda \
      --health-cmd "pg_isready -U venda_user -d venda" \
      --health-interval 2s \
      --health-timeout 5s \
      --health-retries 60 \
      --health-start-period 5s \
      -p "127.0.0.1:${port}:5432" \
      postgres:15-alpine >/dev/null; then
      fallback_port="$port"
      return 0
    fi

    echo "[smoke-local] Port ${port} was not actually bindable; retrying on the next fallback port" >&2
    docker rm -f "$fallback_container" >/dev/null 2>&1 || true
    fallback_container=""
  done

  return 1
}

compose_db_started=false
cleanup_stale_fallback_containers

if port_is_available 5432; then
  echo "[smoke-local] Starting venda-db via docker compose"
  if docker compose up -d venda-db; then
    compose_db_started=true
  else
    echo "[smoke-local] docker compose could not bind localhost:5432; falling back to a disposable Postgres container" >&2
    docker compose rm -sf venda-db >/dev/null 2>&1 || true
  fi
fi

if [ "$compose_db_started" = true ]; then
  echo "[smoke-local] Waiting for Postgres health"
  wait_for_compose_db

  : "${DATABASE_URL:=postgres://venda_user:venda_pass_2026@localhost:5432/venda}"
else
  if ! start_fallback_db || [ -z "${fallback_port:-}" ]; then
    echo "[smoke-local] Could not find an available fallback port for Postgres" >&2
    exit 1
  fi

  echo "[smoke-local] Waiting for fallback Postgres health"
  wait_for_container_health "$fallback_container" "fallback Postgres container"

  : "${DATABASE_URL:=postgres://venda_user:venda_pass_2026@127.0.0.1:${fallback_port}/venda}"
fi

export DATABASE_URL

echo "[smoke-local] Building backend"
npm run build

echo "[smoke-local] Applying backend schema migration"
NODE_ENV=production DB_AUTO_MIGRATE=false npm run db:migrate

echo "[smoke-local] Running live backend smoke"
NODE_ENV=production DB_AUTO_MIGRATE=false npm run smoke:live
