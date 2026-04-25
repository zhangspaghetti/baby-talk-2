@echo off
setlocal EnableExtensions

set "REPO_ROOT=%~dp0.."
cd /d "%REPO_ROOT%"
set "BABY_TALK_FRONT_DOOR_SHELL=cmd"

where dart >nul 2>&1
if errorlevel 1 (
  echo smoke_status=failed
  echo tthw_seconds=0
  echo first_failure_stage=preflight
  echo likely_cause=dart_missing
  echo next_action=Install Dart or Flutter, then rerun scripts\dev-verify-admin-demo.cmd
  exit /b 127
)

dart run tool\verify_m006_s13_demo_path.dart smoke %*
exit /b %errorlevel%
