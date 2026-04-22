@echo off
setlocal enableextensions

if "%~1"=="" exit /b 1
if "%~2"=="" exit /b 1

set "flag=%~1"
set "target=%~2"

if /I "%flag%"=="-s" goto check_size
if /I "%flag%"=="-f" goto check_file
if /I "%flag%"=="-x" goto check_exec

echo Unsupported test flag: %flag% 1>&2
exit /b 2

:check_size
if not exist "%target%" exit /b 1
for %%I in ("%target%") do (
  if %%~zI GTR 0 exit /b 0
)
exit /b 1

:check_file
if not exist "%target%" exit /b 1
if exist "%target%\" exit /b 1
exit /b 0

:check_exec
if not exist "%target%" exit /b 1
if exist "%target%\" exit /b 1
exit /b 0
