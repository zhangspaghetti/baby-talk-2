#!/usr/bin/env bash
# scripts/run-mobile-e2e.sh
#
# Runs the Flutter E2E smoke test against a real backend (via Docker Compose).
#
# Usage:
#   ./scripts/run-mobile-e2e.sh
#
# Requirements:
#   - Docker + docker compose
#   - Flutter SDK on PATH
#   - A physical device or emulator running (check with: flutter devices)
#
# The script:
#   1. Starts postgres + minio + backend via docker compose (dev mode)
#   2. Waits up to 60s for the backend health endpoint
#   3. Runs the Flutter E2E smoke test
#   4. Always stops/removes the containers on exit (trap)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
BACKEND_URL="http://localhost:8080"
HEALTH_URL="${BACKEND_URL}/actuator/health"
MAX_WAIT=60

cd "$REPO_ROOT"

cleanup() {
  echo ""
  echo "--- Stopping Docker containers ---"
  docker compose stop backend
}
trap cleanup EXIT

echo "=== BabyTalk Mobile E2E Smoke Test ==="
echo "Backend: $BACKEND_URL"
echo ""

# Start infrastructure (postgres + minio + backend)
echo "--- Starting Docker Compose (backend + deps) ---"
docker compose up -d postgres minio backend

# Wait for backend health
echo "--- Waiting for backend health ($HEALTH_URL) ---"
elapsed=0
until curl -sf "$HEALTH_URL" > /dev/null 2>&1; do
  if [ $elapsed -ge $MAX_WAIT ]; then
    echo "ERROR: Backend did not become healthy within ${MAX_WAIT}s." >&2
    docker compose logs backend | tail -40
    exit 1
  fi
  echo "  ... waiting (${elapsed}s / ${MAX_WAIT}s)"
  sleep 3
  elapsed=$((elapsed + 3))
done
echo "  Backend is healthy ✓"
echo ""

# Run Flutter E2E tests
# Pass -d <device-id> as an argument if you want to target a specific device.
# Example:  ./run-mobile-e2e.sh -d emulator-5554
DEVICE_FLAG="${1:-}"
echo "--- Running Flutter E2E smoke test ---"
cd "$REPO_ROOT/mobile"
flutter test integration_test/e2e_smoke_test.dart \
  ${DEVICE_FLAG:+$DEVICE_FLAG} \
  --dart-define=BABY_TALK_API_BASE_URL="$BACKEND_URL" \
  --dart-define=BABY_TALK_E2E=true \
  --reporter=expanded

echo ""
echo "=== E2E smoke test completed ==="
