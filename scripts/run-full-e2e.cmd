@echo off
REM run-full-e2e.cmd
REM
REM Full-stack E2E test runner (Windows):
REM   1. Validates k8s backend connectivity
REM   2. Sets up ADB reverse port-forwarding for emulator -> host
REM   3. Runs Playwright admin-web tests (screenshot: 'on')
REM   4. Runs Flutter mobile full-flow integration test
REM   5. Pulls screenshots from emulator
REM   6. Generates a combined Markdown report
REM
REM Prerequisites:
REM   - kubectl port-forward already running (app-api -> :8080, admin-api -> :8081)
REM   - Android emulator running (emulator-5554 by default)
REM   - pnpm install done at repo root
REM   - flutter pub get done in mobile/

setlocal enabledelayedexpansion

set EMULATOR=emulator-5554
set APP_API_URL=http://127.0.0.1:8080
set ADMIN_API_URL=http://127.0.0.1:8081
set ADMIN_WEB_URL=http://127.0.0.1:3000
set BACKEND_URL_EMULATOR=http://localhost:8080

set SCRIPT_DIR=%~dp0
set REPO_ROOT=%SCRIPT_DIR%..

REM Normalize path
pushd %REPO_ROOT%
set REPO_ROOT=%CD%
popd

set SCREENSHOTS_HOST=%REPO_ROOT%\docs\screenshots
set SCREENSHOTS_MOBILE=%SCREENSHOTS_HOST%\mobile
set SCREENSHOTS_ADMIN=%SCREENSHOTS_HOST%\admin

REM Generate date string for report filename
for /f "tokens=2 delims==" %%I in ('wmic os get localdatetime /value') do set datetime=%%I
set REPORT_DATE=%datetime:~0,4%-%datetime:~4,2%-%datetime:~6,2%
set REPORT_FILE=%REPO_ROOT%\docs\e2e-full-test-report-%REPORT_DATE%.md
set RUN_BATCH_ID=%datetime:~0,8%-%datetime:~8,6%

for /f %%I in ('git -C "%REPO_ROOT%" rev-parse --short HEAD 2^>NUL') do set GIT_COMMIT=%%I
if "%GIT_COMMIT%"=="" set GIT_COMMIT=unknown

set ARTIFACT_RUN_DIR=%REPO_ROOT%\artifacts\e2e\%REPORT_DATE%\%GIT_COMMIT%\fullstack-%RUN_BATCH_ID%
set PLAYWRIGHT_LOG=%ARTIFACT_RUN_DIR%\playwright-stdout-stderr.log
set PLAYWRIGHT_PREFLIGHT_LOG=%ARTIFACT_RUN_DIR%\playwright-preflight.log
set FLUTTER_LOG=%ARTIFACT_RUN_DIR%\flutter-stdout-stderr.log
set RUN_METADATA=%ARTIFACT_RUN_DIR%\run-metadata.txt

if not exist "%ARTIFACT_RUN_DIR%" mkdir "%ARTIFACT_RUN_DIR%"

(
echo run_batch_id=%RUN_BATCH_ID%
echo commit=%GIT_COMMIT%
echo date=%date%
echo time=%time%
echo app_api=%APP_API_URL%
echo admin_api=%ADMIN_API_URL%
echo admin_web=%ADMIN_WEB_URL%
echo emulator=%EMULATOR%
) > "%RUN_METADATA%"

echo ============================================================
echo   BabyTalk Full-Stack E2E Test
echo   Date: %date% %time%
echo ============================================================

REM ── Step 1: Verify backend connectivity ─────────────────────────────────────
echo.
echo ^>^>^> [1/5] Verifying backend connectivity...

set NO_PROXY=*
curl -s -o NUL -w "%%{http_code}" "%APP_API_URL%/actuator/health" > %TEMP%\health_status.txt 2>&1
set /p APP_STATUS=<%TEMP%\health_status.txt
if "%APP_STATUS%"=="200" (
    echo   OK: %APP_API_URL%/actuator/health [HTTP %APP_STATUS%]
) else (
    echo   ERROR: App API not reachable at %APP_API_URL% [HTTP %APP_STATUS%]
    echo   Ensure kubectl port-forward is running for app-api on :8080
    exit /b 1
)

curl -s -o NUL -w "%%{http_code}" "%ADMIN_API_URL%/actuator/health" > %TEMP%\health_status.txt 2>&1
set /p ADMIN_STATUS=<%TEMP%\health_status.txt
if "%ADMIN_STATUS%"=="200" (
    echo   OK: %ADMIN_API_URL%/actuator/health [HTTP %ADMIN_STATUS%]
) else (
    echo   ERROR: Admin API not reachable at %ADMIN_API_URL% [HTTP %ADMIN_STATUS%]
    echo   Ensure kubectl port-forward is running for admin-api on :8081
    exit /b 1
)

curl -s -o NUL -w "%%{http_code}" "%ADMIN_WEB_URL%" > %TEMP%\health_status.txt 2>&1
set /p WEB_STATUS=<%TEMP%\health_status.txt
if "%WEB_STATUS%"=="200" (
    echo   OK: %ADMIN_WEB_URL% [HTTP %WEB_STATUS%]
) else (
    echo   ERROR: Admin Web not reachable at %ADMIN_WEB_URL% [HTTP %WEB_STATUS%]
    exit /b 1
)

REM ── Step 2: ADB reverse port-forwarding ─────────────────────────────────────
echo.
echo ^>^>^> [2/5] Setting up ADB reverse port-forwarding (%EMULATOR%)...

adb devices | findstr %EMULATOR% >NUL 2>&1
if errorlevel 1 (
    echo   ERROR: Emulator '%EMULATOR%' not found. Start Android emulator first.
    exit /b 1
)

adb -s %EMULATOR% reverse tcp:8080 tcp:8080
adb -s %EMULATOR% reverse tcp:8081 tcp:8081
echo   OK: tcp:8080 and tcp:8081 reversed on %EMULATOR%

REM ── Step 3: Playwright admin-web tests ───────────────────────────────────────
echo.
echo ^>^>^> [3/5] Running Playwright admin-web tests...

if not exist "%SCREENSHOTS_ADMIN%" mkdir "%SCREENSHOTS_ADMIN%"

cd /d "%REPO_ROOT%\admin-web"
set BABY_TALK_PLAYWRIGHT_SKIP_COMPOSE_BOOT=1

echo   Preflight: using system-installed Chrome via Playwright channel=chrome (no browser download).
(
echo mode=system-chrome
echo note=skip playwright install chromium
echo date=%date%
echo time=%time%
) > "%PLAYWRIGHT_PREFLIGHT_LOG%"

call pnpm exec playwright test --reporter=list,html > "%PLAYWRIGHT_LOG%" 2>&1
set PLAYWRIGHT_EXIT=%errorlevel%

if exist "%REPO_ROOT%\admin-web\playwright-report" (
    echo   OK: Playwright report at admin-web\playwright-report\index.html
) else (
    echo   WARN: Playwright report directory not found.
)

if exist "%REPO_ROOT%\admin-web\test-results" (
    xcopy /E /I /Y "%REPO_ROOT%\admin-web\test-results" "%ARTIFACT_RUN_DIR%\playwright\test-results" >NUL 2>&1
)
if exist "%REPO_ROOT%\admin-web\playwright-report" (
    xcopy /E /I /Y "%REPO_ROOT%\admin-web\playwright-report" "%ARTIFACT_RUN_DIR%\playwright\playwright-report" >NUL 2>&1
)

REM Copy any standalone PNGs from test-results
for /r "%REPO_ROOT%\admin-web\test-results" %%f in (*.png) do (
    copy "%%f" "%SCREENSHOTS_ADMIN%\" >NUL 2>&1
)

cd /d "%REPO_ROOT%"

REM ── Step 4: Flutter mobile full-flow test ────────────────────────────────────
echo.
echo ^>^>^> [4/5] Running Flutter mobile full-flow E2E test...

REM Screenshots are written to internal storage (getApplicationDocumentsDirectory)
REM Accessible via 'run-as' while the APK is installed.
set APP_INTERNAL=/data/user/0/com.babytalk.mobile/app_flutter/baby_talk_e2e

REM Clear old screenshots (requires com.babytalk.mobile to already be installed)
adb -s %EMULATOR% shell "run-as com.babytalk.mobile rm -rf %APP_INTERNAL%" 2>NUL
echo   OK: Cleared old screenshots from internal storage (if app was installed).

del /f /q "%FLUTTER_LOG%" 2>NUL

REM Run flutter test in BACKGROUND so Step 5 can extract screenshots during
REM the 30-second extraction window the test inserts at the end of its body.
cd /d "%REPO_ROOT%\mobile"
start /b cmd /c "flutter test integration_test/e2e_full_flow_test.dart --dart-define=BABY_TALK_E2E=true ""--dart-define=BABY_TALK_API_BASE_URL=%BACKEND_URL_EMULATOR%"" -d %EMULATOR% --timeout none > ""%FLUTTER_LOG%"" 2>&1"
echo   OK: flutter test started in background.

cd /d "%REPO_ROOT%"

REM ── Step 5: Pull screenshots via run-as during the 30-second extraction window ─
echo.
echo ^>^>^> [5/5] Waiting for extraction window, then pulling screenshots via run-as...

if not exist "%SCREENSHOTS_MOBILE%" mkdir "%SCREENSHOTS_MOBILE%"

REM Write a PowerShell helper script to a temp file to avoid messy escaping.
set PS_EXTRACT=%TEMP%\bt_extract_screenshots.ps1
(
echo $logFile = '%FLUTTER_LOG%'
echo $screenshotDir = '%SCREENSHOTS_MOBILE%'
echo $emulator = '%EMULATOR%'
echo $appInternal = '/data/user/0/com.babytalk.mobile/app_flutter/baby_talk_e2e'
echo $extracted = $false
echo for ^($i = 0; $i -lt 240; $i++^) {
echo   Start-Sleep -Seconds 1
echo   if ^(^(Test-Path $logFile^) -and ^(Select-String -Path $logFile -Pattern 'Waiting 30s for screenshot extraction' -Quiet^)^) {
echo     Write-Host "  Extraction window detected after $i seconds. Pulling PNGs via run-as..."
echo     $files = ^(adb -s $emulator shell "run-as com.babytalk.mobile ls '$appInternal/'" 2^>$null^) -split "`n" ^| ForEach-Object { $_.Trim^(^) } ^| Where-Object { $_ -ne '' }
echo     foreach ^($f in $files^) {
echo       $dest = Join-Path $screenshotDir $f
echo       cmd /c "adb -s $emulator exec-out ""run-as com.babytalk.mobile cat '$appInternal/$f'"" ^> ""$dest"""
echo       Write-Host "  OK: $f"
echo     }
echo     $extracted = $true; break
echo   }
echo }
echo if ^(-not $extracted^) { Write-Host 'WARN: Extraction window not detected within 240s.' }
) > "%PS_EXTRACT%"

REM Run the PowerShell extraction script (blocks until done or timeout)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PS_EXTRACT%"

REM Wait for flutter test to finish (poll flutter.exe process)
:WAIT_FLUTTER
timeout /t 3 /nobreak >NUL 2>&1
tasklist /fi "imagename eq flutter.exe" /fo csv 2>NUL | findstr /i "flutter.exe" >NUL
if not errorlevel 1 goto WAIT_FLUTTER

REM Determine pass/fail by inspecting log
findstr /i "All tests passed" "%FLUTTER_LOG%" >NUL 2>&1
if not errorlevel 1 (
    set FLUTTER_EXIT=0
) else (
    set FLUTTER_EXIT=1
)

type "%FLUTTER_LOG%"

set MOBILE_SHOT_COUNT=0
for %%f in ("%SCREENSHOTS_MOBILE%\*.png") do set /a MOBILE_SHOT_COUNT+=1
echo   OK: Pulled %MOBILE_SHOT_COUNT% mobile screenshots to %SCREENSHOTS_MOBILE%

REM ── Generate Markdown report ─────────────────────────────────────────────────
echo.
echo ^>^>^> Generating test report: %REPORT_FILE%

REM Determine pass/fail labels
if "%PLAYWRIGHT_EXIT%"=="0" (
    set PW_STATUS=PASS
) else (
    set PW_STATUS=FAIL exit %PLAYWRIGHT_EXIT%
)
if "%FLUTTER_EXIT%"=="0" (
    set FL_STATUS=PASS
) else (
    set FL_STATUS=FAIL exit %FLUTTER_EXIT%
)

(
echo # BabyTalk 全栈 E2E 测试报告
echo.
echo **日期**: %date% %time%
echo **后端**: k8s ^(Docker Desktop^) — namespace: babytalk
echo **前端测试**: Playwright ^(admin-web^)
echo **移动端测试**: Flutter Integration Test ^(emulator: %EMULATOR%^)
echo.
echo ---
echo.
echo ## 测试结果摘要
echo.
echo ^| 测试套件 ^| 状态 ^|
echo ^|---------^|------^|
echo ^| Admin Web ^(Playwright^) ^| %PW_STATUS% ^|
echo ^| Mobile E2E ^(Flutter^)   ^| %FL_STATUS% ^|
echo.
echo ---
echo.
echo ## 基础设施
echo.
echo ```
echo App API:    %APP_API_URL%  ^(kubectl port-forward -^> babytalk app-api pod^)
echo Admin API:  %ADMIN_API_URL% ^(kubectl port-forward -^> babytalk admin-api pod^)
echo Admin Web:  %ADMIN_WEB_URL% ^(Vite dev server 或 k8s pod^)
echo Namespace:  babytalk
echo Dev SMS code: 246810
echo Commit SHA: %GIT_COMMIT%
echo Run batch ID: %RUN_BATCH_ID%
echo Artifacts: %ARTIFACT_RUN_DIR%
echo ```
echo.
echo ---
echo.
echo ## 移动端测试截图 ^(Flutter^)
echo.
echo 以下截图由集成测试在 Android 模拟器 ^(%EMULATOR%^) 上自动捕获。
echo 截图按流程顺序排列：引导程序 -^> 主屏幕 -^> 练习 -^> 标签页 -^> 登录 -^> Mentor。
echo.
) > "%REPORT_FILE%"

REM Add mobile screenshots to report
for %%f in ("%SCREENSHOTS_MOBILE%\*.png") do (
    set FNAME=%%~nf
    set LABEL=!FNAME:_= !
    (
    echo ### !LABEL!
    echo.
    echo ^<img src="screenshots/mobile/%%~nxf" alt="!LABEL!" /^>
    echo.
    ) >> "%REPORT_FILE%"
)

(
echo ---
echo.
echo ## Admin Web 测试截图 ^(Playwright^)
echo.
echo 完整的 HTML 报告（含所有页面截图）位于：
echo `admin-web/playwright-report/index.html`
echo.
echo 测试覆盖范围：
echo.
echo ^| 功能模块 ^| 测试文件 ^|
echo ^|---------^|---------^|
echo ^| 登录 / 登出 ^| tests/login.spec.ts ^|
echo ^| 控制台概览 ^| tests/overview.spec.ts ^|
echo ^| 用户管理 ^| tests/users.spec.ts ^|
echo ^| 知识库操作 ^| tests/knowledge-ops.spec.ts ^|
echo ^| Mentor 审核 ^| tests/mentor-audit.spec.ts ^|
echo ^| 分发统计 ^| tests/distribution-stats.spec.ts ^|
echo ^| 花园数据 ^| tests/garden.spec.ts ^|
echo ^| 成长追踪 ^| tests/growth.spec.ts ^|
echo.
) >> "%REPORT_FILE%"

echo.
echo ============================================================
echo   E2E Test Run Complete
echo   Report: %REPORT_FILE%
echo   Mobile screenshots: %SCREENSHOTS_MOBILE% (%MOBILE_SHOT_COUNT% files)
echo   Admin Playwright report: %REPO_ROOT%\admin-web\playwright-report\index.html
echo ============================================================

if "%PLAYWRIGHT_EXIT%"=="0" (
    if "%FLUTTER_EXIT%"=="0" (
        echo.
        echo   All tests PASSED.
        exit /b 0
    )
)

echo.
echo   WARN: One or more test suites had failures. Check logs above.
exit /b 1
