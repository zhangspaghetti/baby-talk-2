#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BACKEND_DIR="$ROOT_DIR/backend"

cleanup() {
  docker compose down --remove-orphans >/dev/null 2>&1 || true
}
trap cleanup EXIT

wait_for_health() {
  local name="$1"
  local url="$2"

  for _ in {1..30}; do
    if curl -fsS "$url" >/dev/null; then
      echo "[$name] healthy"
      return 0
    fi
    sleep 2
  done

  echo "[$name] health endpoint did not become ready: $url" >&2
  docker compose ps >&2 || true
  docker compose logs db-migration app-api admin-api >&2 || true
  return 1
}

echo '=== Backend Reactor Test ==='
"$BACKEND_DIR/mvnw" -f "$BACKEND_DIR/pom.xml" -B test

echo '=== Migration-first Compose Smoke ==='
docker compose up -d postgres minio db-migration app-api admin-api
wait_for_health app-api http://localhost:8080/actuator/health
wait_for_health admin-api http://localhost:8081/actuator/health

echo '=== Backend Test PASSED ==='
