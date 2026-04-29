#!/usr/bin/env bash
# run-full-e2e.sh
#
# Full-stack E2E test runner:
#   1. Validates k8s backend connectivity
#   2. Sets up ADB reverse port-forwarding for emulator → host
#   3. Runs Playwright admin-web tests (with screenshot: 'on')
#   4. Runs Flutter mobile full-flow integration test
#   5. Pulls screenshots from emulator
#   6. Generates a combined Markdown report
#
# Prerequisites:
#   - kubectl port-forward already running (app-api → :8080, admin-api → :8081)
#   - Android emulator running (emulator-5554 by default)
#   - npm install done in admin-web/
#   - flutter pub get done in mobile/

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

EMULATOR="${EMULATOR:-emulator-5554}"
APP_API_URL="${APP_API_URL:-http://127.0.0.1:8080}"
ADMIN_API_URL="${ADMIN_API_URL:-http://127.0.0.1:8081}"
ADMIN_WEB_URL="${ADMIN_WEB_URL:-http://127.0.0.1:3000}"
BACKEND_URL_EMULATOR="${BACKEND_URL_EMULATOR:-http://localhost:8080}"

SCREENSHOTS_HOST="$REPO_ROOT/docs/screenshots"
SCREENSHOTS_MOBILE="$SCREENSHOTS_HOST/mobile"
SCREENSHOTS_ADMIN="$SCREENSHOTS_HOST/admin"
REPORT_FILE="$REPO_ROOT/docs/e2e-full-test-report-$(date +%Y-%m-%d).md"

echo "============================================================"
echo "  BabyTalk Full-Stack E2E Test"
echo "  Date: $(date)"
echo "============================================================"

# ── Step 1: Verify backend connectivity ─────────────────────────────────────
echo ""
echo ">>> [1/5] Verifying backend connectivity..."

for URL in "$APP_API_URL/actuator/health" "$ADMIN_API_URL/actuator/health" "$ADMIN_WEB_URL"; do
  STATUS=$(NO_PROXY='*' curl -s -o /dev/null -w "%{http_code}" "$URL" || true)
  if [ "$STATUS" = "200" ]; then
    echo "  ✓ $URL (HTTP $STATUS)"
  else
    echo "  ✗ $URL unreachable (HTTP ${STATUS:-000})"
    echo "  ERROR: Backend not ready. Ensure 'kubectl port-forward' is running."
    echo "         Run: scripts/dev-up-helm-demo.sh (or set up port-forwards manually)"
    exit 1
  fi
done

# ── Step 2: ADB reverse port-forwarding ─────────────────────────────────────
echo ""
echo ">>> [2/5] Setting up ADB reverse port-forwarding ($EMULATOR)..."

if ! adb devices | grep -q "$EMULATOR"; then
  echo "  ERROR: Emulator '$EMULATOR' not found. Start Android emulator first."
  exit 1
fi

adb -s "$EMULATOR" reverse tcp:8080 tcp:8080
adb -s "$EMULATOR" reverse tcp:8081 tcp:8081
echo "  ✓ tcp:8080 and tcp:8081 reversed on $EMULATOR"

# ── Step 3: Playwright admin-web tests ───────────────────────────────────────
echo ""
echo ">>> [3/5] Running Playwright admin-web tests..."

mkdir -p "$SCREENSHOTS_ADMIN"

cd "$REPO_ROOT/admin-web"
BABY_TALK_PLAYWRIGHT_SKIP_COMPOSE_BOOT=1 \
  npx playwright test \
  --reporter=list,html 2>&1 | tee /tmp/playwright-out.txt || PLAYWRIGHT_EXIT=$?

# The HTML report is written to admin-web/playwright-report/
# Copy attachment screenshots to docs/screenshots/admin/
if [ -d "$REPO_ROOT/admin-web/playwright-report" ]; then
  # Playwright embeds screenshots inside the HTML report; also copy any
  # standalone PNG attachments that may have been emitted.
  find "$REPO_ROOT/admin-web/test-results" -name "*.png" \
    -exec cp {} "$SCREENSHOTS_ADMIN/" \; 2>/dev/null || true
  echo "  ✓ Playwright report written to admin-web/playwright-report/index.html"
else
  echo "  ! No Playwright report directory found."
fi

cd "$REPO_ROOT"

# ── Step 4: Flutter mobile full-flow test ────────────────────────────────────
echo ""
echo ">>> [4/5] Running Flutter mobile full-flow E2E test..."

# Screenshots are written to internal storage (getApplicationDocumentsDirectory)
# Accessible via 'run-as' while the APK is still installed.
APP_INTERNAL="/data/user/0/com.babytalk.mobile/app_flutter/baby_talk_e2e"

# Clear old screenshots (requires com.babytalk.mobile to already be installed)
adb -s "$EMULATOR" shell "run-as com.babytalk.mobile rm -rf '$APP_INTERNAL'" 2>/dev/null || true
echo "  ✓ Cleared old screenshots from internal storage (if app was installed)"

# Run flutter test in BACKGROUND so Step 5 can extract screenshots during
# the 30-second extraction window the test inserts at the end of its body.
rm -f /tmp/flutter-e2e-out.txt
cd "$REPO_ROOT/mobile"
flutter test integration_test/e2e_full_flow_test.dart \
  --dart-define=BABY_TALK_E2E=true \
  --dart-define="BABY_TALK_API_BASE_URL=$BACKEND_URL_EMULATOR" \
  -d "$EMULATOR" \
  --timeout none \
  2>&1 | tee /tmp/flutter-e2e-out.txt &
FLUTTER_BG_PID=$!
echo "  flutter test started in background (PID $FLUTTER_BG_PID)"

cd "$REPO_ROOT"

# ── Step 5: Pull screenshots via run-as during the 30-second extraction window ─
echo ""
echo ">>> [5/5] Waiting for extraction window, then pulling screenshots via run-as..."

mkdir -p "$SCREENSHOTS_MOBILE"

# The test emits '[e2e_full_flow] Waiting 30s for screenshot extraction via run-as...'
# and then sleeps 30 seconds before the APK is uninstalled.  Poll for that line,
# then extract all PNGs while the app is still installed.
EXTRACTION_DONE=0
for i in $(seq 1 240); do
  sleep 1
  if grep -q 'Waiting 30s for screenshot extraction' /tmp/flutter-e2e-out.txt 2>/dev/null; then
    echo "  Extraction window detected after ${i}s. Pulling PNGs via run-as..."
    FILES=$(adb -s "$EMULATOR" shell "run-as com.babytalk.mobile ls '$APP_INTERNAL/'" \
            2>/dev/null | tr -d '\r')
    for f in $FILES; do
      [ -z "$f" ] && continue
      adb -s "$EMULATOR" exec-out \
        "run-as com.babytalk.mobile cat '$APP_INTERNAL/$f'" \
        > "$SCREENSHOTS_MOBILE/$f" \
        && echo "  ✓ $f"
    done
    EXTRACTION_DONE=1
    break
  fi
done

if [ "$EXTRACTION_DONE" = "0" ]; then
  echo "  WARN: Extraction window not detected within 240s. Flutter test may have failed."
fi

# Wait for the background flutter test process to finish
wait $FLUTTER_BG_PID
FLUTTER_EXIT=$?

MOBILE_SHOT_COUNT=$(find "$SCREENSHOTS_MOBILE" -name "*.png" | wc -l | tr -d ' ')
echo "  ✓ Pulled $MOBILE_SHOT_COUNT mobile screenshots → $SCREENSHOTS_MOBILE"

# ── Generate Markdown report ─────────────────────────────────────────────────
echo ""
echo ">>> Generating test report → $REPORT_FILE"

cat > "$REPORT_FILE" << REPORT_HEADER
# BabyTalk 全栈 E2E 测试报告

**日期**: $(date "+%Y-%m-%d %H:%M:%S")
**后端**: k8s (Docker Desktop) — namespace: babytalk
**前端测试**: Playwright (admin-web)
**移动端测试**: Flutter Integration Test (emulator: $EMULATOR)

---

## 测试结果摘要

| 测试套件 | 状态 |
|---------|------|
| Admin Web (Playwright) | $([ "${PLAYWRIGHT_EXIT:-0}" = "0" ] && echo "✅ 通过" || echo "❌ 失败 (exit ${PLAYWRIGHT_EXIT:-?})") |
| Mobile E2E (Flutter)   | $([ "${FLUTTER_EXIT:-0}" = "0" ] && echo "✅ 通过" || echo "❌ 失败 (exit ${FLUTTER_EXIT:-?})") |

---

## 基础设施

\`\`\`
App API:    $APP_API_URL  (kubectl port-forward → babytalk app-api pod)
Admin API:  $ADMIN_API_URL (kubectl port-forward → babytalk admin-api pod)
Admin Web:  $ADMIN_WEB_URL (Vite dev server 或 k8s pod)
Namespace:  babytalk
Dev SMS code: 246810
\`\`\`

---

## 移动端测试截图 (Flutter)

以下截图由集成测试在 Android 模拟器 ($EMULATOR) 上自动捕获。
截图按流程顺序排列：引导程序 → 主屏幕 → 练习 → 标签页 → 登录 → Mentor。

REPORT_HEADER

# Add mobile screenshots
for PNG in $(find "$SCREENSHOTS_MOBILE" -name "*.png" | sort); do
  BASENAME=$(basename "$PNG" .png)
  # Convert snake_case + index to readable label
  LABEL=$(echo "$BASENAME" | sed 's/^[0-9]*_//' | sed 's/_/ /g')
  cat >> "$REPORT_FILE" << SHOT

### $LABEL

![${LABEL}](screenshots/mobile/$(basename "$PNG"))

SHOT
done

cat >> "$REPORT_FILE" << ADMIN_SECTION

---

## Admin Web 测试截图 (Playwright)

完整的 HTML 报告（含所有页面截图）位于：
\`admin-web/playwright-report/index.html\`

测试覆盖范围：

| 功能模块 | 测试文件 |
|---------|---------|
| 登录 / 登出 | tests/login.spec.ts |
| 控制台概览 | tests/overview.spec.ts |
| 用户管理 | tests/users.spec.ts |
| 知识库操作 | tests/knowledge-ops.spec.ts |
| Mentor 审核 | tests/mentor-audit.spec.ts |
| 分发统计 | tests/distribution-stats.spec.ts |
| 花园数据 | tests/garden.spec.ts |
| 成长追踪 | tests/growth.spec.ts |

ADMIN_SECTION

# Add any standalone Playwright PNGs found
ADMIN_SHOT_COUNT=$(find "$SCREENSHOTS_ADMIN" -name "*.png" 2>/dev/null | wc -l | tr -d ' ')
if [ "$ADMIN_SHOT_COUNT" -gt 0 ]; then
  for PNG in $(find "$SCREENSHOTS_ADMIN" -name "*.png" | sort); do
    LABEL=$(basename "$PNG" .png | sed 's/-/ /g')
    echo "### $LABEL" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "![${LABEL}](screenshots/admin/$(basename "$PNG"))" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
  done
fi

cat >> "$REPORT_FILE" << FOOTER

---

## 日志摘录

### Flutter E2E 日志

\`\`\`
$(tail -50 /tmp/flutter-e2e-out.txt 2>/dev/null || echo "(no output captured)")
\`\`\`

### Playwright 日志

\`\`\`
$(tail -30 /tmp/playwright-out.txt 2>/dev/null || echo "(no output captured)")
\`\`\`
FOOTER

echo ""
echo "============================================================"
echo "  E2E Test Run Complete"
echo "  Report: $REPORT_FILE"
echo "  Mobile screenshots: $SCREENSHOTS_MOBILE ($MOBILE_SHOT_COUNT files)"
echo "  Admin Playwright report: $REPO_ROOT/admin-web/playwright-report/index.html"
echo "============================================================"

# Exit with non-zero if any suite failed
if [ "${PLAYWRIGHT_EXIT:-0}" != "0" ] || [ "${FLUTTER_EXIT:-0}" != "0" ]; then
  echo ""
  echo "  WARN: One or more test suites had failures. Check logs above."
  exit 1
fi
