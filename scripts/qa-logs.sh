#!/usr/bin/env bash
# Quick log viewer for QA environment (babytalk-qa namespace).
# Usage: ./scripts/qa-logs.sh [gateway|admin-api|app-api|minio|errors|follow|all]
set -euo pipefail
NS=babytalk-qa
TAIL_LINES=50

show_usage() {
  echo "Usage: $0 [pod-alias|errors|follow]"
  echo "Aliases: gateway, admin-api, admin-web, app-api, postgres, redis, minio"
  echo "  errors  - grep ERROR/WARN across all pods"
  echo "  follow  - follow all pods in real-time"
}

find_pod() {
  kubectl -n "$NS" get pods --no-headers 2>/dev/null | grep "$1" | awk "{print \$1}" | head -1
}

case "${1:-all}" in
  -h|--help) show_usage; exit 0 ;;
  errors)
    echo "=== QA Errors (last 200 lines/pod) ==="
    for p in gateway admin-api admin-web app-api postgres redis minio; do
      pod=$(find_pod "$p")
      [ -z "$pod" ] && continue
      out=$(kubectl -n "$NS" logs "$pod" --tail=200 2>/dev/null | grep -i -E "ERROR|WARN|Exception|fail" || true)
      [ -n "$out" ] && printf "\n--- %s (%s) ---\n%s\n" "$p" "$pod" "$out"
    done ;;
  follow)
    echo "Following all pods (Ctrl-C to stop)..."
    pods=$(kubectl -n "$NS" get pods --no-headers -o custom-columns=":metadata.name" 2>/dev/null)
    for pod in $pods; do kubectl -n "$NS" logs -f --tail=10 "$pod" --prefix & done
    wait ;;
  all)
    echo "=== QA Logs (last $TAIL_LINES lines/pod) ==="
    for p in gateway admin-api admin-web app-api postgres redis minio; do
      pod=$(find_pod "$p")
      [ -z "$pod" ] && continue
      printf "\n--- %s (%s) ---\n" "$p" "$pod"
      kubectl -n "$NS" logs "$pod" --tail="$TAIL_LINES" 2>/dev/null || echo "(no logs)"
    done ;;
  *)
    pod=$(find_pod "$1")
    [ -z "$pod" ] && { echo "ERROR: pod for $1 not found"; exit 1; }
    echo "=== $1 ($pod) — last $TAIL_LINES lines ==="
    kubectl -n "$NS" logs "$pod" --tail="$TAIL_LINES" 2>/dev/null ;;
esac
