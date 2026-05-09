#!/usr/bin/env bash
# One-shot QA environment bootstrap.
#   - Deploys babytalk-qa-infra and babytalk-qa-app to the 'babytalk-qa' namespace
#   - Port-forwards: gateway → 127.0.0.1:8091, admin-web → 127.0.0.1:3001
#   - Builds Flutter debug APK; installs to a connected Android emulator if found
#
# Usage: ./scripts/qa-up-helm.sh
#
# Prerequisites:
#   helm ≥ 3.14, kubectl ≥ 1.28, flutter ≥ 3.11.4
#   A running kind cluster (or any local Kubernetes cluster with hostpath StorageClass)
#   QA secrets file: deploy/helm/babytalk-app/values-kind-qa-secrets.yaml
#     (copy from values-kind-qa-secrets.example.yaml and fill in values)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

QA_NS=babytalk-qa
INFRA_RELEASE=babytalk-qa-infra
APP_RELEASE=babytalk-qa-app
GATEWAY_SVC="${APP_RELEASE}-gateway"
ADMIN_WEB_SVC="${APP_RELEASE}-admin-web"
GATEWAY_LOCAL_PORT=8091
ADMIN_WEB_LOCAL_PORT=3001

INFRA_VALUES="${REPO_ROOT}/deploy/helm/babytalk-infra/values-kind-qa.yaml"
APP_VALUES="${REPO_ROOT}/deploy/helm/babytalk-app/values-kind-qa.yaml"
APP_SECRETS="${REPO_ROOT}/deploy/helm/babytalk-app/values-kind-qa-secrets.yaml"

cd "$REPO_ROOT"

# ── Preflight ──────────────────────────────────────────────────────────────────
echo "==> [preflight] checking dependencies..."
for cmd in helm kubectl flutter; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "ERROR: '$cmd' not found. Install it and retry."
    exit 1
  fi
done

if [ ! -f "$APP_SECRETS" ]; then
  echo "ERROR: QA secrets file not found: $APP_SECRETS"
  echo "  Run: cp deploy/helm/babytalk-app/values-kind-qa-secrets.example.yaml \\"
  echo "           deploy/helm/babytalk-app/values-kind-qa-secrets.yaml"
  echo "  Then edit it with your QA-specific secrets."
  exit 1
fi

echo "    deps: ok"

# ── Pre-load images that the local registry mirror may not serve ───────────────
# The kind cluster node uses containerd; if registry-mirror is unhealthy,
# bitnami/redis will fail to pull. Pre-seed it from the Docker daemon cache.
echo "==> [images] pre-seeding bitnami/redis into kind node containerd..."
KIND_NODE="desktop-control-plane"
if docker inspect "$KIND_NODE" >/dev/null 2>&1; then
  if ! docker exec "$KIND_NODE" ctr -n k8s.io images check \
       "registry-1.docker.io/bitnami/redis:latest" >/dev/null 2>&1; then
    docker save bitnami/redis:latest \
      | docker exec -i "$KIND_NODE" ctr -n k8s.io images import - >/dev/null 2>&1 && \
    docker exec "$KIND_NODE" ctr -n k8s.io images tag \
      docker.io/bitnami/redis:latest \
      registry-1.docker.io/bitnami/redis:latest >/dev/null 2>&1 || true
    echo "    seeded: registry-1.docker.io/bitnami/redis:latest"
  else
    echo "    already cached: registry-1.docker.io/bitnami/redis:latest"
  fi
else
  echo "    WARNING: kind node '$KIND_NODE' not found — skipping image pre-seed"
fi

# ── Infra ──────────────────────────────────────────────────────────────────────
echo "==> [infra] deploying $INFRA_RELEASE to namespace $QA_NS..."
helm upgrade --install "$INFRA_RELEASE" deploy/helm/babytalk-infra \
  -n "$QA_NS" \
  --create-namespace \
  -f "$INFRA_VALUES" \
  --wait \
  --timeout 120s

echo "    infra: ok"

# ── App ────────────────────────────────────────────────────────────────────────
echo "==> [app] deploying $APP_RELEASE to namespace $QA_NS..."
helm upgrade --install "$APP_RELEASE" deploy/helm/babytalk-app \
  -n "$QA_NS" \
  -f "$APP_VALUES" \
  -f "$APP_SECRETS" \
  --wait \
  --timeout 180s

echo "    app: ok"

# ── Rollout verification ───────────────────────────────────────────────────────
echo "==> [rollout] verifying all deployments..."
for dep in gateway admin-api admin-web app-api; do
  kubectl -n "$QA_NS" rollout status "deployment/${APP_RELEASE}-${dep}" --timeout=60s
done

echo "    rollout: ok"

# ── Port-forward ───────────────────────────────────────────────────────────────
echo "==> [port-forward] starting background port-forwards..."

# Kill any stale port-forwards on these local ports
pkill -f "kubectl.*port-forward.*${GATEWAY_LOCAL_PORT}" 2>/dev/null || true
pkill -f "kubectl.*port-forward.*${ADMIN_WEB_LOCAL_PORT}" 2>/dev/null || true
sleep 1

kubectl -n "$QA_NS" port-forward \
  "svc/${GATEWAY_SVC}" "${GATEWAY_LOCAL_PORT}:8090" \
  > /tmp/qa-pf-gateway.log 2>&1 &
GATEWAY_PF_PID=$!

kubectl -n "$QA_NS" port-forward \
  "svc/${ADMIN_WEB_SVC}" "${ADMIN_WEB_LOCAL_PORT}:80" \
  > /tmp/qa-pf-admin-web.log 2>&1 &
ADMIN_WEB_PF_PID=$!

echo "    gateway  → 127.0.0.1:${GATEWAY_LOCAL_PORT}  (PID ${GATEWAY_PF_PID})"
echo "    admin-web → 127.0.0.1:${ADMIN_WEB_LOCAL_PORT} (PID ${ADMIN_WEB_PF_PID})"
echo "    logs: /tmp/qa-pf-gateway.log, /tmp/qa-pf-admin-web.log"

# Wait for port-forward to be ready
sleep 3

# ── Gateway smoke ──────────────────────────────────────────────────────────────
echo "==> [smoke] gateway health check..."
if curl -sf "http://127.0.0.1:${GATEWAY_LOCAL_PORT}/actuator/health" >/dev/null 2>&1; then
  echo "    gateway: healthy"
else
  echo "    WARNING: gateway health check not yet responding (give it a few more seconds)"
fi

# ── APK build ─────────────────────────────────────────────────────────────────
echo "==> [apk] building Flutter debug APK (gateway=${GATEWAY_LOCAL_PORT})..."
cd "$REPO_ROOT/mobile"
flutter build apk --debug   --dart-define=BABY_TALK_API_BASE_URL="http://127.0.0.1:${GATEWAY_LOCAL_PORT}"

APK_PATH="${REPO_ROOT}/mobile/build/app/outputs/flutter-apk/app-debug.apk"
echo "    APK built: $APK_PATH"

# ── APK install (if emulator/device available) ─────────────────────────────────
if command -v adb >/dev/null 2>&1; then
  DEVICE_COUNT=$(adb devices 2>/dev/null | tail -n +2 | grep -c "device$" || true)
  if [ "${DEVICE_COUNT:-0}" -gt 0 ]; then
    echo "==> [adb] installing APK on connected device/emulator..."
    adb install -r "$APK_PATH"
    echo "    install: ok"
  else
    echo "==> [adb] no connected emulator/device found — APK ready for manual install"
    echo "    To start emulator: emulator -avd <your_avd_name>"
    echo "    To install:        adb install -r $APK_PATH"
  fi
else
  echo "==> [adb] adb not in PATH — APK ready at $APK_PATH"
  echo "    Install Android SDK platform-tools to use adb"
fi

# ── Summary ────────────────────────────────────────────────────────────────────
echo ""
echo "qa_status=ok"
echo "namespace=${QA_NS}"
echo "gateway_url=http://127.0.0.1:${GATEWAY_LOCAL_PORT}/"
echo "admin_web_url=http://127.0.0.1:${ADMIN_WEB_LOCAL_PORT}"
echo "apk_path=${APK_PATH}"
echo "port_forward_pids=${GATEWAY_PF_PID} ${ADMIN_WEB_PF_PID}"
echo ""
echo "To stop port-forwards: kill ${GATEWAY_PF_PID} ${ADMIN_WEB_PF_PID}"
echo "To tear down QA:       helm uninstall ${APP_RELEASE} ${INFRA_RELEASE} -n ${QA_NS}"
