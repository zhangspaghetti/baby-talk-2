#!/usr/bin/env bash
# Build and install Flutter debug APK to an Android emulator/device.
# This script is intentionally decoupled from Helm deployment.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
MOBILE_DIR="$REPO_ROOT/mobile"
APK_PATH="$MOBILE_DIR/build/app/outputs/flutter-apk/app-debug.apk"

GATEWAY_PORT=8091
SKIP_BUILD=0
AVD_NAME=""
DEVICE_SERIAL=""

print_usage() {
  cat <<'USAGE'
Usage:
  ./scripts/qa-install-apk.sh [options]

Options:
  --gateway-port <port>   Gateway port injected into BABY_TALK_API_BASE_URL (default: 8091)
  --skip-build            Skip flutter build and install existing APK only
  --avd <name>            Start this Android AVD if no --device is provided
  --device <serial>       Install to a specific adb device serial
  -h, --help              Show this help message
USAGE
}

die() {
  echo "install_status=failed"
  echo "reason=$1"
  echo "next_action=$2"
  exit 1
}

while [ $# -gt 0 ]; do
  case "$1" in
    --gateway-port)
      [ $# -ge 2 ] || die "missing_gateway_port" "Provide: --gateway-port <port>"
      GATEWAY_PORT="$2"
      shift 2
      ;;
    --skip-build)
      SKIP_BUILD=1
      shift
      ;;
    --avd)
      [ $# -ge 2 ] || die "missing_avd_name" "Provide: --avd <name>"
      AVD_NAME="$2"
      shift 2
      ;;
    --device)
      [ $# -ge 2 ] || die "missing_device_serial" "Provide: --device <serial>"
      DEVICE_SERIAL="$2"
      shift 2
      ;;
    -h|--help)
      print_usage
      exit 0
      ;;
    *)
      die "unknown_arg_$1" "Run with --help to see valid options"
      ;;
  esac
done

command -v flutter >/dev/null 2>&1 || die "missing_flutter" "Install Flutter and ensure 'flutter' is in PATH"
command -v adb >/dev/null 2>&1 || die "missing_adb" "Install Android platform-tools and ensure 'adb' is in PATH"

if [ "$SKIP_BUILD" -eq 0 ]; then
  echo "==> [apk] building debug APK (gateway=${GATEWAY_PORT})..."
  cd "$MOBILE_DIR"
  flutter build apk --debug \
    --dart-define=BABY_TALK_API_BASE_URL="http://127.0.0.1:${GATEWAY_PORT}"
else
  echo "==> [apk] skip build enabled"
fi

if [ ! -f "$APK_PATH" ]; then
  die "apk_not_found" "Build first or remove --skip-build; expected: $APK_PATH"
fi

resolve_target_device() {
  if [ -n "$DEVICE_SERIAL" ]; then
    echo "$DEVICE_SERIAL"
    return 0
  fi

  if [ -n "$AVD_NAME" ]; then
    if command -v emulator >/dev/null 2>&1; then
      echo "==> [emulator] starting AVD '$AVD_NAME'..."
      nohup emulator -avd "$AVD_NAME" >/tmp/qa-install-emulator.log 2>&1 &
    else
      echo "==> [emulator] command not found, skip auto-start"
    fi
  fi

  adb start-server >/dev/null 2>&1 || true
  local target
  target="$(adb devices | awk 'NR>1 && $2=="device" {print $1; exit}')"
  if [ -z "$target" ] && [ -n "$AVD_NAME" ]; then
    echo "==> [adb] waiting for emulator device..."
    adb wait-for-device >/dev/null 2>&1 || true
    target="$(adb devices | awk 'NR>1 && $2=="device" {print $1; exit}')"
  fi

  echo "$target"
}

TARGET_DEVICE="$(resolve_target_device)"
if [ -z "$TARGET_DEVICE" ]; then
  die "no_online_device" "Start emulator then rerun: emulator -avd <name>; adb devices"
fi

echo "==> [adb] installing APK on $TARGET_DEVICE ..."
adb -s "$TARGET_DEVICE" install -r "$APK_PATH"

echo "install_status=ok"
echo "apk_path=$APK_PATH"
echo "target_device=$TARGET_DEVICE"
echo "gateway_port=$GATEWAY_PORT"
