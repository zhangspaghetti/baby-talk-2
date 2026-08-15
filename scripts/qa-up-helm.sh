#!/usr/bin/env bash
# One-shot QA environment bootstrap.
#   - Deploys babytalk-qa-infra and babytalk-qa-app to the 'babytalk-qa' namespace
#   - Port-forwards: gateway → 127.0.0.1:19091, admin-web → 127.0.0.1:3001
#   - Builds Flutter debug APK; installs to a connected Android emulator if found
#
# Usage: ./scripts/qa-up-helm.sh
# Frozen candidate: QA_CANDIDATE_ID=m2-<commit> ./scripts/qa-up-helm.sh
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
# 8091 is commonly reserved by Windows Hyper-V/Docker port exclusions.
# Callers may override either port when their host requires a different value.
GATEWAY_LOCAL_PORT="${QA_GATEWAY_LOCAL_PORT:-19091}"
ADMIN_WEB_LOCAL_PORT="${QA_ADMIN_WEB_LOCAL_PORT:-3001}"
APP_RUNTIME_ARGS=(
  --set-string "config.BABY_TALK_ADMIN_WEB_ORIGIN=http://127.0.0.1:${ADMIN_WEB_LOCAL_PORT}"
)
# Every QA run must name one immutable candidate. The tag remains accepted for
# compatibility, but it must name exactly the same candidate.
QA_CANDIDATE_ID="${QA_CANDIDATE_ID:-}"
QA_IMAGE_TAG="${QA_IMAGE_TAG:-$QA_CANDIDATE_ID}"
QA_REQUIRED_MIGRATION_VERSION="${QA_REQUIRED_MIGRATION_VERSION:-33}"
export QA_CANDIDATE_ID QA_REQUIRED_MIGRATION_VERSION

INFRA_VALUES="${REPO_ROOT}/deploy/helm/babytalk-infra/values-kind-qa.yaml"
APP_VALUES="${REPO_ROOT}/deploy/helm/babytalk-app/values-kind-qa.yaml"
APP_SECRETS="${REPO_ROOT}/deploy/helm/babytalk-app/values-kind-qa-secrets.yaml"
CANDIDATE_IMAGES=(
  "app-api=appApi"
  "admin-api=adminApi"
  "admin-web=adminWeb"
  "gateway=gateway"
  "db-migration=dbMigration"
)
APP_IMAGE_TAG_ARGS=()
if [[ -z "$QA_CANDIDATE_ID" ]]; then
  echo "ERROR: QA_CANDIDATE_ID is required for a frozen QA candidate."
  exit 1
fi
if [[ "$QA_IMAGE_TAG" != "$QA_CANDIDATE_ID" ]]; then
  echo "ERROR: QA_IMAGE_TAG must equal QA_CANDIDATE_ID."
  exit 1
fi
for image_mapping in "${CANDIDATE_IMAGES[@]}"; do
  value_key="${image_mapping#*=}"
  APP_IMAGE_TAG_ARGS+=(--set-string "${value_key}.image.tag=$QA_IMAGE_TAG")
done
APP_RUNTIME_ARGS+=(
  --set-string "candidate.id=$QA_CANDIDATE_ID"
  --set-string "candidate.requiredMigrationVersion=$QA_REQUIRED_MIGRATION_VERSION"
)

cd "$REPO_ROOT"

# ── Preflight ──────────────────────────────────────────────────────────────────
echo "==> [preflight] checking dependencies..."
for cmd in helm kubectl flutter docker python3; do
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

# Resolve the effective images from Helm's merged values. This supports both
# QA_IMAGE_TAG overrides and tags written directly in values-kind-qa.yaml.
echo "==> [images] resolving effective application images..."
if ! rendered_app_manifest="$(
  helm template "$APP_RELEASE" deploy/helm/babytalk-app \
    -n "$QA_NS" \
    -f "$APP_VALUES" \
    -f "$APP_SECRETS" \
    "${APP_RUNTIME_ARGS[@]}" \
    "${APP_IMAGE_TAG_ARGS[@]}"
)"; then
  echo "ERROR: failed to render the QA application chart."
  exit 1
fi

if ! rendered_image_refs="$(
  awk '$1 == "image:" {
    gsub(/"/, "", $2)
    if ($2 ~ /^babytalk\//) {
      print $2
    }
  }' <<< "$rendered_app_manifest"
)"; then
  echo "ERROR: failed to extract application images from rendered Helm manifests."
  exit 1
fi
unset rendered_app_manifest

CANDIDATE_IMAGE_REFS=()
for image_mapping in "${CANDIDATE_IMAGES[@]}"; do
  component="${image_mapping%%=*}"
  component_image_ref=""
  component_match_count=0

  while IFS= read -r image_ref; do
    [[ "$image_ref" == "babytalk/${component}:"* ]] || continue
    if [[ "$image_ref" != "$component_image_ref" ]]; then
      component_image_ref="$image_ref"
      component_match_count=$((component_match_count + 1))
    fi
  done <<< "$rendered_image_refs"

  if [[ "$component_match_count" -ne 1 ]]; then
    echo "ERROR: expected one rendered image for babytalk/$component, found $component_match_count."
    exit 1
  fi
  CANDIDATE_IMAGE_REFS+=("$component_image_ref")
  echo "    resolved: $component_image_ref"
done
unset rendered_image_refs

# ── Pre-load images that the local registry mirror may not serve ───────────────
# The kind cluster node uses containerd; if registry-mirror is unhealthy,
# remote and local-only images may fail to pull. Pre-seed from Docker when needed.
echo "==> [images] pre-seeding bitnami/redis into kind node containerd..."
KIND_NODE="desktop-control-plane"
if docker inspect "$KIND_NODE" >/dev/null 2>&1; then
  if ! kind_image_refs_before_seed="$(
    docker exec "$KIND_NODE" ctr -n k8s.io images ls -q
  )"; then
    echo "ERROR: failed to enumerate images in kind before pre-seeding."
    exit 1
  fi

  redis_image_ref="registry-1.docker.io/bitnami/redis:latest"
  redis_is_cached=false
  while IFS= read -r existing_image_ref; do
    if [[ "$existing_image_ref" == "$redis_image_ref" ]]; then
      redis_is_cached=true
      break
    fi
  done <<< "$kind_image_refs_before_seed"

  if [[ "$redis_is_cached" != "true" ]]; then
    if ! docker save bitnami/redis:latest \
         | docker exec -i "$KIND_NODE" ctr -n k8s.io images import - \
           >/dev/null 2>&1; then
      echo "ERROR: failed to import bitnami/redis:latest into kind."
      exit 1
    fi
    if ! docker exec "$KIND_NODE" ctr -n k8s.io images tag \
         docker.io/bitnami/redis:latest \
         "$redis_image_ref" >/dev/null 2>&1; then
      echo "ERROR: failed to tag Redis image in kind: $redis_image_ref"
      exit 1
    fi
    kind_image_refs_before_seed+=$'\n'"$redis_image_ref"
    echo "    seeded: $redis_image_ref"
  else
    echo "    already cached: $redis_image_ref"
  fi

  echo "==> [images] ensuring candidate images exist in kind..."
  for image_ref in "${CANDIDATE_IMAGE_REFS[@]}"; do
    kind_image_ref="docker.io/${image_ref}"
    image_is_cached=false
    while IFS= read -r existing_image_ref; do
      if [[ "$existing_image_ref" == "$kind_image_ref" ]]; then
        image_is_cached=true
        break
      fi
    done <<< "$kind_image_refs_before_seed"

    if [[ "$image_is_cached" == "true" ]]; then
      echo "    already cached: $image_ref"
      continue
    fi

    if ! docker image inspect "$image_ref" >/dev/null 2>&1; then
      echo "ERROR: candidate image unavailable in Docker and kind: $image_ref"
      echo "  Build the exact rendered tag, then retry."
      exit 1
    fi

    if ! docker save "$image_ref" \
         | docker exec -i "$KIND_NODE" ctr -n k8s.io images import - \
           >/dev/null 2>&1; then
      echo "ERROR: failed to import candidate image into kind: $image_ref"
      exit 1
    fi
    kind_image_refs_before_seed+=$'\n'"$kind_image_ref"
    echo "    seeded: $image_ref"
  done
  unset kind_image_refs_before_seed
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
if [[ -n "$QA_IMAGE_TAG" ]]; then
  echo "    candidate image tag: $QA_IMAGE_TAG"
fi

helm upgrade --install "$APP_RELEASE" deploy/helm/babytalk-app \
  -n "$QA_NS" \
  -f "$APP_VALUES" \
  -f "$APP_SECRETS" \
  "${APP_RUNTIME_ARGS[@]}" \
  "${APP_IMAGE_TAG_ARGS[@]}" \
  --wait \
  --timeout 180s

echo "    app: ok"

# ── Rollout verification ───────────────────────────────────────────────────────
echo "==> [rollout] verifying all deployments..."
for dep in gateway admin-api admin-web app-api; do
  kubectl -n "$QA_NS" rollout status "deployment/${APP_RELEASE}-${dep}" --timeout=60s
done

echo "    rollout: ok"

# Remove only superseded BabyTalk refs after the replacement pods are healthy.
# Keep the active immutable tag; containerd garbage-collects unreferenced content.
if docker inspect "$KIND_NODE" >/dev/null 2>&1; then
  echo "==> [images] removing superseded candidate images from kind..."
  if ! kind_image_refs="$(
    docker exec "$KIND_NODE" ctr -n k8s.io images ls -q
  )"; then
    echo "ERROR: failed to enumerate images in kind before cleanup."
    exit 1
  fi

  for candidate_image_ref in "${CANDIDATE_IMAGE_REFS[@]}"; do
    component="${candidate_image_ref#babytalk/}"
    component="${component%%:*}"
    current_image_ref="docker.io/${candidate_image_ref}"
    while IFS= read -r image_ref; do
      [[ -z "$image_ref" ]] && continue
      [[ "$image_ref" == "$current_image_ref" ]] && continue

      case "$image_ref" in
        "docker.io/babytalk/${component}:"*|"docker.io/babytalk/${component}@"*)
          docker exec "$KIND_NODE" ctr -n k8s.io images rm "$image_ref" \
            >/dev/null
          echo "    removed: $image_ref"
          ;;
      esac
    done <<< "$kind_image_refs"
  done
  unset kind_image_refs
fi

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
GATEWAY_HEALTHY=false
for _ in {1..10}; do
  if curl -fsS "http://127.0.0.1:${GATEWAY_LOCAL_PORT}/actuator/health" >/dev/null 2>&1; then
    GATEWAY_HEALTHY=true
    break
  fi
  sleep 2
done

if [[ "$GATEWAY_HEALTHY" != "true" ]]; then
  echo "ERROR: gateway port-forward or health check failed on 127.0.0.1:${GATEWAY_LOCAL_PORT}."
  echo "  Gateway port-forward log: /tmp/qa-pf-gateway.log"
  tail -n 20 /tmp/qa-pf-gateway.log 2>/dev/null || true
  exit 1
fi

echo "    gateway: healthy"

echo "==> [candidate] verifying gateway compatibility..."
if ! candidate_compatibility="$(curl -fsS "http://127.0.0.1:${GATEWAY_LOCAL_PORT}/qa/candidate-compatibility")"; then
  echo "ERROR: gateway candidate compatibility endpoint is unavailable."
  exit 1
fi
if ! python3 -c '
import json
import os
import sys
payload = json.load(sys.stdin)
expected_id = os.environ["QA_CANDIDATE_ID"]
expected_migration = os.environ["QA_REQUIRED_MIGRATION_VERSION"]
if payload != {
    "candidateId": expected_id,
    "requiredMigrationVersion": expected_migration,
    "status": "compatible",
}:
    raise SystemExit(1)
' <<< "$candidate_compatibility"; then
  echo "ERROR: deployed gateway candidate identity or required migration mismatches frozen candidate."
  exit 1
fi
echo "    candidate: $QA_CANDIDATE_ID (migration $QA_REQUIRED_MIGRATION_VERSION)"

# ── APK build ─────────────────────────────────────────────────────────────────
echo "==> [apk] building Flutter debug APK (gateway=${GATEWAY_LOCAL_PORT})..."
cd "$REPO_ROOT/mobile"
APK_BUILD_VERSION="$(awk -F ': ' '$1 == "version" { print $2; exit }' pubspec.yaml)"
if [[ -z "$APK_BUILD_VERSION" ]]; then
  echo "ERROR: mobile/pubspec.yaml does not declare an APK version."
  exit 1
fi
flutter build apk --debug \
  --dart-define=BABY_TALK_API_BASE_URL="http://127.0.0.1:${GATEWAY_LOCAL_PORT}" \
  --dart-define=BABY_TALK_CANDIDATE_ID="$QA_CANDIDATE_ID" \
  --dart-define=BABY_TALK_BUILD_VERSION="$APK_BUILD_VERSION" \
  --dart-define=BABY_TALK_CUSTOM_SCENE_ENABLED=true

APK_PATH="${REPO_ROOT}/mobile/build/app/outputs/flutter-apk/app-debug.apk"
echo "    APK built: $APK_PATH"

# ── APK install (if emulator/device available) ─────────────────────────────────
if command -v adb >/dev/null 2>&1; then
  DEVICE_COUNT=$(adb devices 2>/dev/null | tail -n +2 | grep -c "device$" || true)
  if [ "${DEVICE_COUNT:-0}" -gt 0 ]; then
    echo "==> [adb] installing APK on connected device/emulator..."
    adb install -r "$APK_PATH"
    echo "    install: ok"

    echo "==> [adb] setting up port reverse (emulator -> host)..."
    adb reverse "tcp:${GATEWAY_LOCAL_PORT}" "tcp:${GATEWAY_LOCAL_PORT}" || {
      echo "    WARNING: adb reverse gateway failed (OK on physical devices; emulator needs this)"
    }
    adb reverse "tcp:${ADMIN_WEB_LOCAL_PORT}" "tcp:${ADMIN_WEB_LOCAL_PORT}" || {
      echo "    WARNING: adb reverse admin-web failed (OK on physical devices; emulator needs this)"
    }
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
echo "candidate_id=${QA_CANDIDATE_ID}"
echo "gateway_url=http://127.0.0.1:${GATEWAY_LOCAL_PORT}/"
echo "admin_web_url=http://127.0.0.1:${ADMIN_WEB_LOCAL_PORT}"
echo "apk_path=${APK_PATH}"
echo "port_forward_pids=${GATEWAY_PF_PID} ${ADMIN_WEB_PF_PID}"
echo ""
echo "To stop port-forwards: kill ${GATEWAY_PF_PID} ${ADMIN_WEB_PF_PID}"
echo "To tear down QA:       helm uninstall ${APP_RELEASE} ${INFRA_RELEASE} -n ${QA_NS}"
