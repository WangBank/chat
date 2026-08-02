#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$ROOT_DIR/backend"

API_IMAGE="${API_IMAGE:-foreverlove-chat-api:latest}"
API_CONTAINER="${API_CONTAINER:-foreverlove-chat-api}"
API_PORT="${API_PORT:-7001}"
API_CONTAINER_PORT="7001"
API_ENVIRONMENT="${API_ENVIRONMENT:-Development}"
DOCKER_NETWORK="${DOCKER_NETWORK:-foreverlove-chat-net}"
STOP_EXISTING_SERVICES="${STOP_EXISTING_SERVICES:-1}"
SKIP_BUILD="${SKIP_BUILD:-0}"
SKIP_POSTGRES="${SKIP_POSTGRES:-0}"

POSTGRES_CONTAINER="${POSTGRES_CONTAINER:-foreverlove-chat-postgres}"
POSTGRES_IMAGE="${POSTGRES_IMAGE:-postgres:latest}"
POSTGRES_HOST="${POSTGRES_HOST:-$POSTGRES_CONTAINER}"
POSTGRES_PORT="${POSTGRES_PORT:-54329}"
POSTGRES_CONTAINER_PORT="${POSTGRES_CONTAINER_PORT:-5432}"
POSTGRES_DB="${POSTGRES_DB:-foreverlove_chat_dev}"
POSTGRES_USER="${POSTGRES_USER:-postgres}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-postgres}"

API_LOGS_DIR="${API_LOGS_DIR:-$ROOT_DIR/.docker/api/logs}"
API_AVATAR_DIR="${API_AVATAR_DIR:-$ROOT_DIR/.docker/api/avatar}"
CONNECTION_STRING="${CONNECTION_STRING:-Host=$POSTGRES_HOST;Port=$POSTGRES_CONTAINER_PORT;Database=$POSTGRES_DB;Username=$POSTGRES_USER;Password=$POSTGRES_PASSWORD}"

log() {
  printf '[deploy-api] %s\n' "$*"
}

die() {
  printf '[deploy-api] ERROR: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage:
  ./deploy-api-docker.sh

Build and run the ASP.NET Core API in Docker.

Useful environment variables:
  API_IMAGE=foreverlove-chat-api:latest
  API_CONTAINER=foreverlove-chat-api
  API_PORT=7001
  API_ENVIRONMENT=Development
  DOCKER_NETWORK=foreverlove-chat-net
  POSTGRES_CONTAINER=foreverlove-chat-postgres
  POSTGRES_DB=foreverlove_chat_dev
  POSTGRES_USER=postgres
  POSTGRES_PASSWORD=postgres
  SKIP_BUILD=1
  SKIP_POSTGRES=1
  STOP_EXISTING_SERVICES=0

Examples:
  ./deploy-api-docker.sh
  API_PORT=7002 ./deploy-api-docker.sh
  API_ENVIRONMENT=Production POSTGRES_HOST=host.docker.internal POSTGRES_CONTAINER_PORT=54329 SKIP_POSTGRES=1 ./deploy-api-docker.sh
EOF
}

need_command() {
  command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

container_exists() {
  docker container inspect "$1" >/dev/null 2>&1
}

container_running() {
  [[ "$(docker container inspect -f '{{.State.Running}}' "$1" 2>/dev/null || true)" == "true" ]]
}

network_exists() {
  docker network inspect "$1" >/dev/null 2>&1
}

container_in_network() {
  local container="$1"
  local network="$2"

  docker network inspect -f '{{range .Containers}}{{.Name}}{{"\n"}}{{end}}' "$network" 2>/dev/null |
    grep -Fx "$container" >/dev/null 2>&1
}

pids_on_port() {
  local port="$1"
  lsof -nP -tiTCP:"$port" -sTCP:LISTEN 2>/dev/null | sort -u || true
}

stop_pid() {
  local name="$1"
  local pid="$2"

  if [[ -n "$pid" ]] && kill -0 "$pid" >/dev/null 2>&1; then
    log "Stopping $name (pid $pid)"
    kill "$pid" >/dev/null 2>&1 || true

    for _ in $(seq 1 10); do
      kill -0 "$pid" >/dev/null 2>&1 || return 0
      sleep 1
    done

    log "Force stopping $name (pid $pid)"
    kill -KILL "$pid" >/dev/null 2>&1 || true
  fi
}

stop_port_listeners() {
  local port="$1"
  local name="$2"
  local pids
  local pid
  local command_line

  pids="$(pids_on_port "$port")"
  [[ -z "$pids" ]] && return 0

  if [[ "$STOP_EXISTING_SERVICES" != "1" ]]; then
    die "Port $port is already in use by $name. Set STOP_EXISTING_SERVICES=1 to stop it automatically."
  fi

  log "Found existing $name service(s) on port $port; stopping before deploy."
  while IFS= read -r pid; do
    [[ -z "$pid" ]] && continue
    command_line="$(ps -p "$pid" -o command= 2>/dev/null || true)"
    [[ -n "$command_line" ]] && log "Existing process $pid: $command_line"
    stop_pid "$name" "$pid"
  done <<< "$pids"
}

wait_for_port_free() {
  local port="$1"
  local name="$2"
  local pids

  for _ in $(seq 1 10); do
    pids="$(pids_on_port "$port")"
    [[ -z "$pids" ]] && return 0
    sleep 1
  done

  die "$name port $port is still in use after stopping existing processes."
}

ensure_network() {
  if network_exists "$DOCKER_NETWORK"; then
    log "Docker network already exists: $DOCKER_NETWORK"
  else
    log "Creating Docker network: $DOCKER_NETWORK"
    docker network create "$DOCKER_NETWORK" >/dev/null
  fi
}

ensure_postgres() {
  [[ "$SKIP_POSTGRES" == "1" ]] && {
    log "Skipping PostgreSQL container setup because SKIP_POSTGRES=1"
    return 0
  }

  if container_exists "$POSTGRES_CONTAINER"; then
    if container_running "$POSTGRES_CONTAINER"; then
      log "PostgreSQL container is already running: $POSTGRES_CONTAINER"
    else
      log "Starting existing PostgreSQL container: $POSTGRES_CONTAINER"
      docker start "$POSTGRES_CONTAINER" >/dev/null
    fi
  else
    log "Creating PostgreSQL container: $POSTGRES_CONTAINER"
    docker run \
      --name "$POSTGRES_CONTAINER" \
      --network "$DOCKER_NETWORK" \
      -e "POSTGRES_PASSWORD=$POSTGRES_PASSWORD" \
      -e "POSTGRES_DB=$POSTGRES_DB" \
      -p "$POSTGRES_PORT:$POSTGRES_CONTAINER_PORT" \
      -d "$POSTGRES_IMAGE" >/dev/null
  fi

  if ! container_in_network "$POSTGRES_CONTAINER" "$DOCKER_NETWORK"; then
    log "Connecting PostgreSQL container to network: $DOCKER_NETWORK"
    docker network connect "$DOCKER_NETWORK" "$POSTGRES_CONTAINER" >/dev/null
  fi

  log "Waiting for PostgreSQL to accept connections"
  for _ in $(seq 1 60); do
    if docker exec "$POSTGRES_CONTAINER" pg_isready -U "$POSTGRES_USER" >/dev/null 2>&1; then
      ensure_database
      log "PostgreSQL is ready: $POSTGRES_CONTAINER:$POSTGRES_CONTAINER_PORT/$POSTGRES_DB"
      return 0
    fi
    sleep 1
  done

  die "PostgreSQL did not become ready"
}

ensure_database() {
  if docker exec "$POSTGRES_CONTAINER" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c 'SELECT 1;' >/dev/null 2>&1; then
    return 0
  fi

  log "Creating PostgreSQL database: $POSTGRES_DB"
  docker exec "$POSTGRES_CONTAINER" createdb -U "$POSTGRES_USER" "$POSTGRES_DB"
}

build_image() {
  [[ "$SKIP_BUILD" == "1" ]] && {
    log "Skipping API image build because SKIP_BUILD=1"
    return 0
  }

  log "Building API image: $API_IMAGE"
  docker build -f "$BACKEND_DIR/Dockerfile" -t "$API_IMAGE" "$BACKEND_DIR"
}

remove_existing_api_container() {
  if container_exists "$API_CONTAINER"; then
    log "Removing existing API container: $API_CONTAINER"
    docker rm -f "$API_CONTAINER" >/dev/null 2>&1 || true
    if container_exists "$API_CONTAINER"; then
      die "Failed to remove existing API container: $API_CONTAINER"
    fi
  fi
}

run_api_container() {
  mkdir -p "$API_LOGS_DIR" "$API_AVATAR_DIR"

  remove_existing_api_container
  stop_port_listeners "$API_PORT" "API"
  wait_for_port_free "$API_PORT" "API"

  log "Starting API container: $API_CONTAINER"
  docker run \
    --name "$API_CONTAINER" \
    --network "$DOCKER_NETWORK" \
    -p "$API_PORT:$API_CONTAINER_PORT" \
    -e "ASPNETCORE_ENVIRONMENT=$API_ENVIRONMENT" \
    -e "ASPNETCORE_URLS=http://0.0.0.0:$API_CONTAINER_PORT" \
    -e "ConnectionStrings__DefaultConnection=$CONNECTION_STRING" \
    -v "$API_LOGS_DIR:/app/logs" \
    -v "$API_AVATAR_DIR:/app/avatar" \
    -d "$API_IMAGE" >/dev/null
}

wait_for_api() {
  local api_url="http://localhost:$API_PORT"
  local status

  log "Waiting for API container to become reachable: $api_url"
  for _ in $(seq 1 90); do
    if ! container_running "$API_CONTAINER"; then
      docker logs --tail 80 "$API_CONTAINER" >&2 || true
      die "API container exited before becoming reachable"
    fi

    status="$(curl -sS -o /dev/null -w '%{http_code}' "$api_url/swagger/v1/swagger.json" 2>/dev/null || true)"
    if [[ "$status" == "200" ]]; then
      log "API is ready: $api_url/swagger"
      return 0
    fi

    status="$(curl -sS -o /dev/null -w '%{http_code}' "$api_url" 2>/dev/null || true)"
    if [[ "$status" =~ ^[1-5][0-9][0-9]$ ]]; then
      log "API is reachable: $api_url"
      return 0
    fi

    sleep 1
  done

  docker logs --tail 80 "$API_CONTAINER" >&2 || true
  die "API did not become reachable in 90s"
}

main() {
  if [[ "${1:-}" == "-h" || "${1:-}" == "--help" || "${1:-}" == "help" ]]; then
    usage
    exit 0
  fi

  need_command docker
  need_command curl
  need_command lsof

  ensure_network
  ensure_postgres
  build_image
  run_api_container
  wait_for_api

  log "Deployment complete"
  log "API: http://localhost:$API_PORT"
  log "Swagger: http://localhost:$API_PORT/swagger"
  log "Container logs: docker logs -f $API_CONTAINER"
}

main "$@"
