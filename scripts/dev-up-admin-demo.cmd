@echo off
rem Helm-first alias since M007 — was compose-based M006 front door.
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

call scripts\dev-up-helm-demo.cmd %*
exit /b %errorlevel%
