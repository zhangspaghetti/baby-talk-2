@echo off
setlocal EnableExtensions

set "REPO_ROOT=%~dp0.."
cd /d "%REPO_ROOT%"
set "BABY_TALK_FRONT_DOOR_SHELL=cmd"

where dart >nul 2>&1
if errorlevel 1 (
  echo demo_status=failed
  echo tthw_seconds=0
  echo first_failure_stage=preflight
  echo likely_cause=dart_missing
  echo next_action=Install Dart or Flutter, then rerun scripts\dev-up-helm-demo.cmd
  echo gateway_url=http://127.0.0.1:8090/
  echo telemetry_path=tmp/m007-s01-helm-metrics.jsonl
  exit /b 127
)

rem "Running build hooks..." may appear before demo_status= output.
rem This is dart build-system noise on stdout; the structured output follows on the next line.
rem Exit code is correctly propagated from dart run.
dart run tool\verify_m007_s01_helm_baseline.dart demo %*
exit /b %errorlevel%
