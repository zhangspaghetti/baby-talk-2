#!/usr/bin/env bash
# Build and install the QA debug APK on an Android emulator only.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_SCRIPT="$SCRIPT_DIR/qa-install-apk.sh"

GATEWAY_PORT=19091
AVD_NAME=""
EMULATOR_SERIAL=""
SKIP_BUILD=0
BOOT_TIMEOUT_SECONDS=240

print_usage() {
  cat <<'USAGE'
Usage:
  bash ./scripts/qa-install-emulator-apk.sh [options]

Options:
  --avd <name>             Start this AVD when no emulator is online
  --device <emulator-id>   Use a specific online emulator (must be emulator-*)
  --gateway-port <port>    QA gateway port (default: 19091)
  --skip-build             Reuse mobile/build/app/outputs/flutter-apk/app-debug.apk
  --boot-timeout <seconds> Emulator boot timeout (default: 240)
  -h, --help               Show this help message

The script never selects or installs to a physical Android device.
USAGE
}

die() {
  echo "emulator_install_status=failed"
  echo "reason=$1"
  echo "next_action=$2"
  exit 1
}

is_positive_integer() {
  [[ "$1" =~ ^[1-9][0-9]*$ ]]
}

while [ $# -gt 0 ]; do
  case "$1" in
    --avd)
      [ $# -ge 2 ] || die "missing_avd_name" "Provide: --avd <name>"
      AVD_NAME="$2"
      shift 2
      ;;
    --device)
      [ $# -ge 2 ] || die "missing_emulator_serial" "Provide: --device emulator-<port>"
      EMULATOR_SERIAL="$2"
      shift 2
      ;;
    --gateway-port)
      [ $# -ge 2 ] || die "missing_gateway_port" "Provide: --gateway-port <port>"
      GATEWAY_PORT="$2"
      shift 2
      ;;
    --skip-build)
      SKIP_BUILD=1
      shift
      ;;
    --boot-timeout)
      [ $# -ge 2 ] || die "missing_boot_timeout" "Provide: --boot-timeout <seconds>"
      BOOT_TIMEOUT_SECONDS="$2"
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

is_positive_integer "$GATEWAY_PORT" ||
  die "invalid_gateway_port" "Use a positive integer port"
[ "$GATEWAY_PORT" -le 65535 ] ||
  die "invalid_gateway_port" "Use a port between 1 and 65535"
is_positive_integer "$BOOT_TIMEOUT_SECONDS" ||
  die "invalid_boot_timeout" "Use a positive integer timeout"
[ -x "$INSTALL_SCRIPT" ] ||
  die "missing_install_script" "Expected executable: $INSTALL_SCRIPT"
command -v adb >/dev/null 2>&1 ||
  die "missing_adb" "Install Android platform-tools and add adb to PATH"

online_emulators() {
  adb devices | awk 'NR > 1 && $1 ~ /^emulator-/ && $2 == "device" {print $1}'
}

validate_emulator_serial() {
  [[ "$1" == emulator-* ]] ||
    die "physical_device_rejected" "Use an emulator-* adb serial"
  adb -s "$1" get-state 2>/dev/null | grep -qx "device" ||
    die "emulator_not_online" "Start $1 or omit --device to auto-select"
}

resolve_emulator_binary() {
  if command -v emulator >/dev/null 2>&1; then
    command -v emulator
    return 0
  fi
  local sdk_root="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
  for candidate in "$sdk_root/emulator/emulator" "$sdk_root/emulator/emulator.exe"; do
    if [ -n "$sdk_root" ] && [ -x "$candidate" ]; then
      echo "$candidate"
      return 0
    fi
  done
  return 1
}

choose_avd() {
  local emulator_binary="$1"
  if [ -n "$AVD_NAME" ]; then
    echo "$AVD_NAME"
    return 0
  fi
  local avds=()
  mapfile -t avds < <("$emulator_binary" -list-avds | sed '/^[[:space:]]*$/d')
  [ "${#avds[@]}" -ne 0 ] ||
    die "no_avd_available" "Create an AVD, then rerun with --avd <name>"
  [ "${#avds[@]}" -eq 1 ] ||
    die "multiple_avds" "Choose one with --avd <name>"
  echo "${avds[0]}"
}

wait_for_boot() {
  local serial="$1"
  local deadline=$((SECONDS + BOOT_TIMEOUT_SECONDS))
  while [ "$SECONDS" -lt "$deadline" ]; do
    if [ "$(adb -s "$serial" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ]; then
      adb -s "$serial" shell input keyevent 82 >/dev/null 2>&1 || true
      return 0
    fi
    sleep 2
  done
  die "emulator_boot_timeout" "Inspect the emulator, then rerun with --device $serial"
}

adb start-server >/dev/null

if [ -n "$EMULATOR_SERIAL" ]; then
  validate_emulator_serial "$EMULATOR_SERIAL"
else
  mapfile -t EMULATORS < <(online_emulators)
  if [ "${#EMULATORS[@]}" -eq 1 ]; then
    EMULATOR_SERIAL="${EMULATORS[0]}"
  elif [ "${#EMULATORS[@]}" -gt 1 ]; then
    die "multiple_online_emulators" "Choose one with --device emulator-<port>"
  else
    EMULATOR_BINARY="$(resolve_emulator_binary)" ||
      die "missing_emulator" "Add Android SDK emulator to PATH or set ANDROID_SDK_ROOT"
    SELECTED_AVD="$(choose_avd "$EMULATOR_BINARY")"
    echo "==> [emulator] starting AVD '$SELECTED_AVD'..."
    nohup "$EMULATOR_BINARY" -avd "$SELECTED_AVD" \
      >"${TMPDIR:-/tmp}/babytalk-emulator.log" 2>&1 &

    deadline=$((SECONDS + BOOT_TIMEOUT_SECONDS))
    while [ "$SECONDS" -lt "$deadline" ]; do
      mapfile -t EMULATORS < <(online_emulators)
      if [ "${#EMULATORS[@]}" -eq 1 ]; then
        EMULATOR_SERIAL="${EMULATORS[0]}"
        break
      fi
      sleep 2
    done
    [ -n "$EMULATOR_SERIAL" ] ||
      die "emulator_not_detected" "Inspect ${TMPDIR:-/tmp}/babytalk-emulator.log"
  fi
fi

validate_emulator_serial "$EMULATOR_SERIAL"
echo "==> [emulator] waiting for Android boot on $EMULATOR_SERIAL..."
wait_for_boot "$EMULATOR_SERIAL"

install_args=(--device "$EMULATOR_SERIAL" --gateway-port "$GATEWAY_PORT")
if [ "$SKIP_BUILD" -eq 1 ]; then
  install_args+=(--skip-build)
fi
"$INSTALL_SCRIPT" "${install_args[@]}"

reverse_rule="$(adb -s "$EMULATOR_SERIAL" reverse --list | awk -v port="tcp:${GATEWAY_PORT}" '$2 == port && $3 == port {print $0}')"
[ -n "$reverse_rule" ] ||
  die "reverse_not_configured" "Run: adb -s $EMULATOR_SERIAL reverse tcp:$GATEWAY_PORT tcp:$GATEWAY_PORT"

echo "emulator_install_status=ok"
echo "target_emulator=$EMULATOR_SERIAL"
echo "gateway_reverse=tcp:${GATEWAY_PORT}->tcp:${GATEWAY_PORT}"
