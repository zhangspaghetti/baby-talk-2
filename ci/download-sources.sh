#!/usr/bin/env bash
set -euo pipefail

# Exact public mirrors used by local CI. No credentials or production endpoints.
export NPM_CONFIG_REGISTRY='https://mirrors.cloud.tencent.com/npm/'
export npm_config_registry="$NPM_CONFIG_REGISTRY"
export COREPACK_NPM_REGISTRY="$NPM_CONFIG_REGISTRY"
export PLAYWRIGHT_DOWNLOAD_HOST='https://npmmirror.com/mirrors/playwright'
export PUB_HOSTED_URL='https://pub.flutter-io.cn'
export FLUTTER_STORAGE_BASE_URL='https://storage.flutter-io.cn'
