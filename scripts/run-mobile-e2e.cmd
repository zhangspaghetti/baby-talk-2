@echo off
REM scripts\run-mobile-e2e.cmd
REM
REM Runs the Flutter E2E smoke test against a real backend (via Docker Compose).
REM
REM Usage:
REM   scripts\run-mobile-e2e.cmd
REM
REM Requirements:
REM   - Docker Desktop running
REM   - Flutter SDK on PATH
REM   - A physical device or emulator running (check with: flutter devices)

setlocal EnableDelayedExpansion

set REPO_ROOT=%~dp0..
set BACKEND_URL=http://localhost:8080
set HEALTH_URL=%BACKEND_URL%/actuator/health
set MAX_WAIT=60
set ELAPSED=0

cd /d "%REPO_ROOT%"

echo === BabyTalk Mobile E2E Smoke Test ===
echo Backend: %BACKEND_URL%
echo.

echo --- Starting Docker Compose (backend + deps) ---
docker compose up -d postgres minio backend
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: docker compose up failed.
    exit /b 1
)

echo --- Waiting for backend health (%HEALTH_URL%) ---
:health_loop
curl -sf %HEALTH_URL% >nul 2>&1
if %ERRORLEVEL% EQU 0 goto health_ok
if %ELAPSED% GEQ %MAX_WAIT% (
    echo ERROR: Backend did not become healthy within %MAX_WAIT%s.
    docker compose logs backend
    goto cleanup
)
echo   ... waiting (%ELAPSED%s / %MAX_WAIT%s)
timeout /t 3 /nobreak >nul
set /a ELAPSED=%ELAPSED%+3
goto health_loop

:health_ok
echo   Backend is healthy [OK]
echo.

REM For physical Android device: adb reverse tcp:8080 tcp:8080 must be run first
REM (or pass a device flag: scripts\run-mobile-e2e.cmd -d emulator-5554)
set DEVICE_FLAG=%~1

echo --- Running Flutter E2E smoke test ---
cd /d "%REPO_ROOT%\mobile"
if "%DEVICE_FLAG%"=="" (
    flutter test integration_test\e2e_smoke_test.dart ^
      --dart-define=BABY_TALK_API_BASE_URL=%BACKEND_URL% ^
      --dart-define=BABY_TALK_E2E=true ^
      --reporter=expanded
) else (
    flutter test integration_test\e2e_smoke_test.dart ^
      %DEVICE_FLAG% ^
      --dart-define=BABY_TALK_API_BASE_URL=%BACKEND_URL% ^
      --dart-define=BABY_TALK_E2E=true ^
      --reporter=expanded
)
set TEST_EXIT=%ERRORLEVEL%

cd /d "%REPO_ROOT%"

:cleanup
echo.
echo --- Stopping backend container ---
docker compose stop backend

echo.
echo === E2E smoke test completed ===
exit /b %TEST_EXIT%
