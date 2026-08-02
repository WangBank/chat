#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$ROOT_DIR/backend"
WEBSITE_DIR="$ROOT_DIR/website"
FLUTTER_DIR="$ROOT_DIR/flutter_client"

BACKEND_URL="${BACKEND_URL:-http://localhost:7001}"
BACKEND_URL="${BACKEND_URL%/}"
BACKEND_PORT="${BACKEND_PORT:-}"
if [[ -z "$BACKEND_PORT" ]]; then
  BACKEND_PORT="$(printf '%s' "$BACKEND_URL" | sed -E 's#^https?://[^/:]+:([0-9]+).*#\1#')"
  [[ "$BACKEND_PORT" == "$BACKEND_URL" ]] && BACKEND_PORT="7001"
fi
FRONTEND_HOST="${FRONTEND_HOST:-0.0.0.0}"
FRONTEND_PORT="${FRONTEND_PORT:-5173}"
POSTGRES_CONTAINER="${POSTGRES_CONTAINER:-foreverlove-chat-postgres}"
POSTGRES_IMAGE="${POSTGRES_IMAGE:-postgres:latest}"
POSTGRES_PORT="${POSTGRES_PORT:-54329}"
POSTGRES_DB="${POSTGRES_DB:-foreverlove_chat_dev}"
POSTGRES_USER="${POSTGRES_USER:-postgres}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-postgres}"
SKIP_INSTALL="${SKIP_INSTALL:-0}"
SKIP_POSTGRES="${SKIP_POSTGRES:-0}"
STOP_EXISTING_SERVICES="${STOP_EXISTING_SERVICES:-1}"
ANDROID_DEVICE="${ANDROID_DEVICE:-}"
ANDROID_EMULATOR="${ANDROID_EMULATOR:-}"
AUTO_START_ANDROID_EMULATOR="${AUTO_START_ANDROID_EMULATOR:-1}"
ANDROID_EMULATOR_TIMEOUT="${ANDROID_EMULATOR_TIMEOUT:-120}"
IOS_DEVICE="${IOS_DEVICE:-}"
FLUTTER_DEVICE_CONNECTION="${FLUTTER_DEVICE_CONNECTION:-both}"
FLUTTER_DEVICE_TIMEOUT="${FLUTTER_DEVICE_TIMEOUT:-10}"
ANDROID_API_URL="${ANDROID_API_URL:-http://10.0.2.2:$BACKEND_PORT/api}"
ANDROID_SIGNALR_URL="${ANDROID_SIGNALR_URL:-http://10.0.2.2:$BACKEND_PORT/videocallhub}"
IOS_API_URL="${IOS_API_URL:-$BACKEND_URL/api}"
IOS_SIGNALR_URL="${IOS_SIGNALR_URL:-$BACKEND_URL/videocallhub}"

BACKEND_PID=""
FRONTEND_PID=""
ANDROID_PID=""
IOS_PID=""
START_WEBSITE=0
START_ANDROID=0
START_IOS=0

log() {
  printf '[start] %s\n' "$*"
}

die() {
  printf '[start] ERROR: %s\n' "$*" >&2
  exit 1
}

need_command() {
  command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

usage() {
  cat <<'EOF'
Usage:
  ./start.sh [web|android|ios|mobile|all]

Modes:
  web       Start backend API and React website. This is the default.
  android   Start backend API and run the Flutter Android app.
  ios       Start backend API and run the Flutter iOS app.
  mobile    Start backend API plus Android and iOS Flutter apps.
  all       Start backend API, React website, Android app, and iOS app.

Modes can be combined, for example:
  ./start.sh web android

Useful environment variables:
  BACKEND_URL=http://localhost:7001
  FRONTEND_PORT=5173
  ANDROID_DEVICE=emulator-5554
  ANDROID_EMULATOR=Pixel_9_Pro_XL_API_35
  AUTO_START_ANDROID_EMULATOR=1
  ANDROID_EMULATOR_TIMEOUT=120
  IOS_DEVICE="iPhone 16 Pro"
  FLUTTER_DEVICE_CONNECTION=attached
  FLUTTER_DEVICE_TIMEOUT=10
  ANDROID_API_URL=http://10.0.2.2:7001/api
  IOS_API_URL=http://localhost:7001/api
  SKIP_INSTALL=1
  SKIP_POSTGRES=1
  STOP_EXISTING_SERVICES=0

Press Ctrl-C to stop services started by this script.
EOF
}

configure_targets() {
  if [[ "$#" -eq 0 ]]; then
    START_WEBSITE=1
    return 0
  fi

  for target in "$@"; do
    case "$target" in
      web|website|front|frontend)
        START_WEBSITE=1
        ;;
      android)
        START_ANDROID=1
        ;;
      ios)
        START_IOS=1
        ;;
      mobile)
        START_ANDROID=1
        START_IOS=1
        ;;
      all)
        START_WEBSITE=1
        START_ANDROID=1
        START_IOS=1
        ;;
      -h|--help|help)
        usage
        exit 0
        ;;
      *)
        usage >&2
        die "Unknown target: $target"
        ;;
    esac
  done
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

  log "Found existing $name service(s) on port $port; stopping before restart."
  while IFS= read -r pid; do
    [[ -z "$pid" ]] && continue
    command_line="$(ps -p "$pid" -o command= 2>/dev/null || true)"
    [[ -n "$command_line" ]] && log "Existing process $pid: $command_line"
    stop_pid "$name" "$pid"
  done <<< "$pids"

  wait_for_port_free "$port" "$name"
}

stop_existing_services() {
  stop_port_listeners "$BACKEND_PORT" "backend API"

  if [[ "$START_WEBSITE" == "1" ]]; then
    stop_port_listeners "$FRONTEND_PORT" "website dev server"
  fi
}

cleanup() {
  local status=$?

  stop_pid "iOS Flutter app" "$IOS_PID"
  stop_pid "Android Flutter app" "$ANDROID_PID"
  stop_pid "website dev server" "$FRONTEND_PID"
  stop_pid "backend API" "$BACKEND_PID"

  wait "$IOS_PID" "$ANDROID_PID" "$FRONTEND_PID" "$BACKEND_PID" 2>/dev/null || true
  exit "$status"
}

wait_for_url() {
  local name="$1"
  local url="$2"
  local max_attempts="${3:-60}"

  for attempt in $(seq 1 "$max_attempts"); do
    if curl -fsS "$url" >/dev/null 2>&1; then
      log "$name is ready: $url"
      return 0
    fi

    if [[ -n "${BACKEND_PID:-}" ]] && ! kill -0 "$BACKEND_PID" >/dev/null 2>&1; then
      die "Backend exited before becoming ready"
    fi

    if [[ -n "${FRONTEND_PID:-}" ]] && ! kill -0 "$FRONTEND_PID" >/dev/null 2>&1; then
      die "Website exited before becoming ready"
    fi

    sleep 1
  done

  die "$name did not become ready in ${max_attempts}s: $url"
}

ensure_postgres() {
  [[ "$SKIP_POSTGRES" == "1" ]] && {
    log "Skipping PostgreSQL container setup because SKIP_POSTGRES=1"
    return 0
  }

  need_command docker

  if docker inspect "$POSTGRES_CONTAINER" >/dev/null 2>&1; then
    if [[ "$(docker inspect -f '{{.State.Running}}' "$POSTGRES_CONTAINER")" != "true" ]]; then
      log "Starting existing PostgreSQL container: $POSTGRES_CONTAINER"
      docker start "$POSTGRES_CONTAINER" >/dev/null
    else
      log "PostgreSQL container is already running: $POSTGRES_CONTAINER"
    fi
  else
    log "Creating PostgreSQL container: $POSTGRES_CONTAINER"
    docker run \
      --name "$POSTGRES_CONTAINER" \
      -e "POSTGRES_PASSWORD=$POSTGRES_PASSWORD" \
      -e "POSTGRES_DB=$POSTGRES_DB" \
      -p "$POSTGRES_PORT:5432" \
      -d "$POSTGRES_IMAGE" >/dev/null
  fi

  log "Waiting for PostgreSQL to accept connections"
  for _ in $(seq 1 60); do
    if docker exec "$POSTGRES_CONTAINER" pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB" >/dev/null 2>&1; then
      log "PostgreSQL is ready on localhost:$POSTGRES_PORT"
      return 0
    fi
    sleep 1
  done

  die "PostgreSQL did not become ready"
}

install_dependencies() {
  [[ "$SKIP_INSTALL" == "1" ]] && {
    log "Skipping dependency restore because SKIP_INSTALL=1"
    return 0
  }

  log "Restoring backend dependencies"
  (cd "$BACKEND_DIR" && dotnet restore)

  if [[ "$START_WEBSITE" == "1" && ! -d "$WEBSITE_DIR/node_modules" ]]; then
    log "Installing website dependencies"
    (cd "$WEBSITE_DIR" && npm install)
  elif [[ "$START_WEBSITE" == "1" ]]; then
    log "Website dependencies already installed"
  fi

  if [[ "$START_ANDROID" == "1" || "$START_IOS" == "1" ]]; then
    log "Restoring Flutter dependencies"
    (cd "$FLUTTER_DIR" && flutter pub get)
  fi
}

start_backend() {
  wait_for_port_free "$BACKEND_PORT" "backend API"

  log "Starting backend API: $BACKEND_URL"
  (
    cd "$BACKEND_DIR"
    ASPNETCORE_ENVIRONMENT=Development \
    dotnet run --no-launch-profile --urls "$BACKEND_URL"
  ) &
  BACKEND_PID=$!
}

start_website() {
  wait_for_port_free "$FRONTEND_PORT" "website dev server"

  log "Starting website: http://localhost:$FRONTEND_PORT"
  (
    cd "$WEBSITE_DIR"
    VITE_API_BASE_URL="$BACKEND_URL" \
    VITE_SIGNALR_HUB_URL="$BACKEND_URL/videocallhub" \
    npm run dev -- --host "$FRONTEND_HOST" --port "$FRONTEND_PORT"
  ) &
  FRONTEND_PID=$!
}

find_flutter_device() {
  local platform="$1"
  local explicit_device="$2"
  local target_pattern

  if [[ -n "$explicit_device" ]]; then
    printf '%s' "$explicit_device"
    return 0
  fi

  case "$platform" in
    android)
      target_pattern="android"
      ;;
    ios)
      target_pattern="ios"
      ;;
    *)
      die "Unknown Flutter platform: $platform"
      ;;
  esac

  local device_id
  device_id="$(
    cd "$FLUTTER_DIR"
    flutter devices --machine \
      --device-timeout="$FLUTTER_DEVICE_TIMEOUT" \
      --device-connection="$FLUTTER_DEVICE_CONNECTION" 2>/dev/null |
      awk -v target_pattern="$target_pattern" '
        /"id":/ {
          id = $0
          sub(/^.*"id": "/, "", id)
          sub(/".*$/, "", id)
          supported = 0
        }
        /"isSupported":/ {
          supported = ($0 ~ /true/)
        }
        /"targetPlatform":/ {
          target_platform = $0
          sub(/^.*"targetPlatform": "/, "", target_platform)
          sub(/".*$/, "", target_platform)
          if (supported && target_platform ~ target_pattern && id != "") {
            print id
            exit
          }
        }
      '
  )"

  printf '%s' "$device_id"
}

resolve_flutter_device() {
  local platform="$1"
  local explicit_device="$2"
  local device_env_var
  local device_id

  case "$platform" in
    android)
      device_env_var="ANDROID_DEVICE"
      ;;
    ios)
      device_env_var="IOS_DEVICE"
      ;;
    *)
      die "Unknown Flutter platform: $platform"
      ;;
  esac

  device_id="$(find_flutter_device "$platform" "$explicit_device")"
  [[ -n "$device_id" ]] || die "No supported $platform device found. Run 'flutter devices' or set $device_env_var."
  printf '%s' "$device_id"
}

resolve_android_emulator() {
  local emulator_id

  if [[ -n "$ANDROID_EMULATOR" ]]; then
    printf '%s' "$ANDROID_EMULATOR"
    return 0
  fi

  emulator_id="$(
    cd "$FLUTTER_DIR"
    flutter emulators 2>/dev/null |
      awk '$0 ~ /^[^[:space:]]/ && $0 ~ /[[:space:]]android[[:space:]]*$/ { print $1; exit }'
  )"

  printf '%s' "$emulator_id"
}

ensure_android_device() {
  local device_id
  local emulator_id
  local launcher_pid
  local launcher_log

  device_id="$(find_flutter_device android "")"
  if [[ -n "$device_id" ]]; then
    log "Android device is already available: $device_id"
    return 0
  fi

  if [[ "$AUTO_START_ANDROID_EMULATOR" != "1" ]]; then
    die "No supported Android device found. Set AUTO_START_ANDROID_EMULATOR=1 or start an emulator manually."
  fi

  emulator_id="$(resolve_android_emulator)"
  [[ -n "$emulator_id" ]] || die "No Android emulator found. Run 'flutter emulators --create' or set ANDROID_EMULATOR."

  launcher_log="${TMPDIR:-/tmp}/foreverlove-android-emulator-$$.log"
  log "Launching Android emulator: $emulator_id"
  (
    cd "$FLUTTER_DIR"
    flutter emulators --launch "$emulator_id"
  ) >"$launcher_log" 2>&1 &
  launcher_pid=$!

  log "Waiting for Android emulator to connect"
  for _ in $(seq 1 "$ANDROID_EMULATOR_TIMEOUT"); do
    device_id="$(find_flutter_device android "")"
    if [[ -n "$device_id" ]]; then
      log "Android emulator is ready: $device_id"
      return 0
    fi

    if ! kill -0 "$launcher_pid" >/dev/null 2>&1 && [[ ! -s "$launcher_log" ]]; then
      die "Android emulator launcher exited before producing a device: $emulator_id"
    fi

    sleep 1
  done

  [[ -s "$launcher_log" ]] && tail -40 "$launcher_log" >&2 || true
  die "Android emulator did not become available in ${ANDROID_EMULATOR_TIMEOUT}s: $emulator_id"
}

start_android() {
  local device_id
  ensure_android_device
  device_id="$(resolve_flutter_device android "$ANDROID_DEVICE")"

  log "Starting Flutter Android app on device selector: $device_id"
  log "Android API URL: $ANDROID_API_URL"
  (
    cd "$FLUTTER_DIR"
    flutter run \
      -d "$device_id" \
      --device-timeout="$FLUTTER_DEVICE_TIMEOUT" \
      --device-connection="$FLUTTER_DEVICE_CONNECTION" \
      --dart-define="API_BASE_URL=$ANDROID_API_URL" \
      --dart-define="SIGNALR_HUB_URL=$ANDROID_SIGNALR_URL"
  ) &
  ANDROID_PID=$!
}

start_ios() {
  local device_id
  device_id="$(resolve_flutter_device ios "$IOS_DEVICE")"

  log "Starting Flutter iOS app on device selector: $device_id"
  log "iOS API URL: $IOS_API_URL"
  (
    cd "$FLUTTER_DIR"
    flutter run \
      -d "$device_id" \
      --device-timeout="$FLUTTER_DEVICE_TIMEOUT" \
      --device-connection="$FLUTTER_DEVICE_CONNECTION" \
      --dart-define="API_BASE_URL=$IOS_API_URL" \
      --dart-define="SIGNALR_HUB_URL=$IOS_SIGNALR_URL"
  ) &
  IOS_PID=$!
}

monitor_processes() {
  while true; do
    if [[ -n "$BACKEND_PID" ]] && ! kill -0 "$BACKEND_PID" >/dev/null 2>&1; then
      wait "$BACKEND_PID"
      exit $?
    fi

    if [[ -n "$FRONTEND_PID" ]] && ! kill -0 "$FRONTEND_PID" >/dev/null 2>&1; then
      wait "$FRONTEND_PID"
      exit $?
    fi

    if [[ -n "$ANDROID_PID" ]] && ! kill -0 "$ANDROID_PID" >/dev/null 2>&1; then
      wait "$ANDROID_PID"
      exit $?
    fi

    if [[ -n "$IOS_PID" ]] && ! kill -0 "$IOS_PID" >/dev/null 2>&1; then
      wait "$IOS_PID"
      exit $?
    fi

    sleep 2
  done
}

main() {
  configure_targets "$@"

  need_command dotnet
  need_command curl
  need_command lsof
  [[ "$START_WEBSITE" == "1" ]] && need_command npm
  [[ "$START_ANDROID" == "1" || "$START_IOS" == "1" ]] && need_command flutter

  stop_existing_services
  ensure_postgres
  install_dependencies
  start_backend
  wait_for_url "Backend API" "$BACKEND_URL/swagger/v1/swagger.json" 90

  if [[ "$START_WEBSITE" == "1" ]]; then
    start_website
    wait_for_url "Website" "http://localhost:$FRONTEND_PORT" 60
  fi

  [[ "$START_ANDROID" == "1" ]] && start_android
  [[ "$START_IOS" == "1" ]] && start_ios

  log "All services are running"
  log "Backend: $BACKEND_URL"
  log "Swagger: $BACKEND_URL/swagger"
  [[ "$START_WEBSITE" == "1" ]] && log "Website: http://localhost:$FRONTEND_PORT"
  [[ "$START_ANDROID" == "1" ]] && log "Android app started"
  [[ "$START_IOS" == "1" ]] && log "iOS app started"
  log "Press Ctrl-C to stop services started by this script."

  monitor_processes
}

trap cleanup EXIT INT TERM
main "$@"
