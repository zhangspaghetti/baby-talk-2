#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

exec bash "$repo_root/backend/mvnw" \
  --settings "$repo_root/backend/.mvn/settings.xml" \
  "$@"
