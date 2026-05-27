# QA APK Install Script + Debug Root Cause Summary Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a standalone APK install script for Android emulator/device and show actionable startup root-cause summary in debug builds only.

**Architecture:** Keep deployment and mobile install concerns separated: `qa-up-helm.sh` remains full-stack bootstrap, while a new script handles only build/install. In Flutter boot failure UI, preserve user-facing generic message but conditionally show debug-only sanitized diagnostics.

**Tech Stack:** Bash, Flutter, Dart, adb, existing widget/smoke tests.

---

### Task 1: Add standalone APK install script

**Files:**
- Create: `scripts/qa-install-apk.sh`
- Test: manual shell execution + adb presence/device scenarios

- [ ] **Step 1: Write script skeleton with strict mode and args parser**

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

GATEWAY_PORT=8091
SKIP_BUILD=0
AVD_NAME=""
DEVICE_SERIAL=""
```

- [ ] **Step 2: Add preflight checks and target device resolution**

```bash
command -v flutter >/dev/null 2>&1 || { echo "install_status=failed"; echo "next_action=Install flutter"; exit 1; }
command -v adb >/dev/null 2>&1 || { echo "install_status=failed"; echo "next_action=Install adb"; exit 1; }

# resolve device in this priority: --device > --avd > first online adb device
```

- [ ] **Step 3: Add build/install flow with machine-readable summary**

```bash
cd "$REPO_ROOT/mobile"
if [ "$SKIP_BUILD" -eq 0 ]; then
  flutter build apk --debug --dart-define=BABY_TALK_API_BASE_URL="http://127.0.0.1:${GATEWAY_PORT}"
fi
adb -s "$TARGET_DEVICE" install -r "$APK_PATH"
echo "install_status=ok"
```

- [ ] **Step 4: Make script executable and run smoke invocation**

Run: `chmod +x scripts/qa-install-apk.sh`  
Run: `bash ./scripts/qa-install-apk.sh --help`  
Expected: prints usage and exits 0.

- [ ] **Step 5: Commit**

```bash
git add scripts/qa-install-apk.sh
git commit -m "feat(scripts): add standalone qa apk install script"
```

### Task 2: Add debug-only startup error root-cause summary

**Files:**
- Modify: `mobile/lib/app/app.dart`
- Test: `mobile/test/smoke/app_boot_test.dart`

- [ ] **Step 1: Add failing test assertion for debug summary on gate failure**

```dart
expect(find.textContaining('StateError'), findsOneWidget);
expect(find.textContaining('disk denied'), findsOneWidget);
```

- [ ] **Step 2: Run test to verify failure**

Run: `cd mobile && flutter test test/smoke/app_boot_test.dart`  
Expected: FAIL because debug summary text is not rendered yet.

- [ ] **Step 3: Implement debug summary plumbing in boot failure UI**

```dart
import 'package:flutter/foundation.dart' show kDebugMode;

// in snapshot.hasError branch:
final debugDetails = kDebugMode ? _buildDebugErrorSummary(snapshot.error) : null;

home: BootFailureScreen(
  message: '本地档案读取失败，请重试。',
  debugDetails: debugDetails,
  ...
)
```

- [ ] **Step 4: Add helper to sanitize/truncate error text**

```dart
String _buildDebugErrorSummary(Object? error) {
  if (error == null) return 'unknown startup error';
  final type = error.runtimeType.toString();
  final msg = '$error';
  final clipped = msg.length > 240 ? '${msg.substring(0, 240)}...' : msg;
  return '$type: $clipped';
}
```

- [ ] **Step 5: Re-run tests**

Run: `cd mobile && flutter test test/smoke/app_boot_test.dart`  
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add mobile/lib/app/app.dart mobile/test/smoke/app_boot_test.dart
git commit -m "feat(mobile): show debug-only startup root cause summary"
```

### Task 3: Document new script in README and run end-to-end install

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Add a new subsection under QA setup for APK-only install**

```markdown
### 仅构建并安装 Flutter APK（不重启 QA 环境）

```bash
./scripts/qa-install-apk.sh
```
```

- [ ] **Step 2: Add optional flags usage examples**

```markdown
./scripts/qa-install-apk.sh --gateway-port 8091 --avd <avd_name>
./scripts/qa-install-apk.sh --skip-build --device <serial>
```

- [ ] **Step 3: Run end-to-end command requested by user**

Run: `bash ./scripts/qa-install-apk.sh`  
Expected: `install_status=ok` and installed on emulator.

- [ ] **Step 4: Final verification**

Run: `cd mobile && flutter analyze lib/app/app.dart`  
Expected: no issues.

- [ ] **Step 5: Commit**

```bash
git add README.md
git commit -m "docs: add qa apk-only install workflow"
```

### Task 4: Final integrated verification and report

**Files:**
- Modify: none

- [ ] **Step 1: Run targeted regression tests**

Run: `cd mobile && flutter test test/smoke/app_boot_test.dart`  
Expected: PASS.

- [ ] **Step 2: Confirm script output from real install run**

Run: `bash ./scripts/qa-install-apk.sh --skip-build`  
Expected: `install_status=ok`.

- [ ] **Step 3: Summarize outcomes with file-level deltas and command results**

Expected summary includes:
- modified files
- validation commands and pass/fail
- emulator install result
