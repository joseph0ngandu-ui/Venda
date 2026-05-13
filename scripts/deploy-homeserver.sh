#!/usr/bin/env bash
set -euo pipefail

SERVER="${SERVER:-homeserver}"
REMOTE_DIR="${REMOTE_DIR:-/home/sal/Venda}"
ENV_FILE="${REMOTE_DIR}/.env.production"
BACKUP_DIR="${BACKUP_DIR:-/home/sal/venda-backups}"
COMPOSE_FILE="${REMOTE_DIR}/docker-compose.production.yml"

ssh "$SERVER" "mkdir -p '$BACKUP_DIR'"

DB_BACKUP_CONTAINER=""
if ssh "$SERVER" "docker ps --format '{{.Names}}' | grep -qx venda-backend-venda-db-1"; then
  DB_BACKUP_CONTAINER="venda-backend-venda-db-1"
elif ssh "$SERVER" "docker ps --format '{{.Names}}' | grep -qx venda-venda-db-1"; then
  DB_BACKUP_CONTAINER="venda-venda-db-1"
fi

if [[ -n "$DB_BACKUP_CONTAINER" ]]; then
  stamp="$(date -u +%Y%m%dT%H%M%SZ)"
  ssh "$SERVER" "docker exec '$DB_BACKUP_CONTAINER' pg_dump -U venda_user -d venda > '$BACKUP_DIR/venda-${stamp}.sql'"
  echo "Backed up production database from $DB_BACKUP_CONTAINER to $BACKUP_DIR/venda-${stamp}.sql"
else
  echo "No running Venda production DB container was found; refusing to deploy without a backup."
  exit 1
fi

rsync -az --delete \
  --exclude '.git' \
  --exclude 'Backend/node_modules' \
  --exclude 'Backend/dist' \
  --exclude 'Web/node_modules' \
  --exclude 'Web/dist' \
  --exclude '.env' \
  --exclude '.env.production' \
  ./ "$SERVER:$REMOTE_DIR/"

ssh "$SERVER" "test -f '$ENV_FILE' || (echo '$ENV_FILE is missing. Create it from .env.production.example with real secrets.' && exit 1)"
ssh "$SERVER" "cd '$REMOTE_DIR' && docker compose --env-file '$ENV_FILE' -f '$COMPOSE_FILE' up -d --build venda-db venda-api venda-web"
ssh "$SERVER" "if docker ps --format '{{.Names}}' | grep -qx venda-backend-venda-db-1; then docker stop venda-backend-venda-db-1; fi"
ssh "$SERVER" "cd '$REMOTE_DIR' && docker compose --env-file '$ENV_FILE' -f '$COMPOSE_FILE' ps"
