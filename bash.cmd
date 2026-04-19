@echo off
rem Route bash to Git Bash, bypassing WSL relay (C:\Windows\System32\bash.exe)
if exist "C:\Program Files\Git\usr\bin\bash.exe" (
    "C:\Program Files\Git\usr\bin\bash.exe" %*
    exit /b %errorlevel%
)
rem Fallback: find non-WSL bash in PATH
for /f "delims=" %%i in ('where bash 2^>nul') do (
    echo %%i | findstr /v /i "System32\bash.exe" > /dev/null 2>&1
    if not errorlevel 1 (
        "%%i" %*
        exit /b %errorlevel%
    )
)
echo bash: Git Bash not found >&2
exit /b 127
