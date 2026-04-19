@echo off
rem Windows CMD shim for grep — delegates to PowerShell Select-String
rem Handles: grep -q 'pattern' file
rem          grep -q 'two word pattern' file  (split by CMD into two tokens)
setlocal enabledelayedexpansion

if /I "%~1"=="-q" (
    set "A2=%~2"
    set "A3=%~3"
    set "A4=%~4"
    set "A5=%~5"

    rem Determine how many tokens the pattern was split into
    if "!A4!"=="" (
        rem 3 effective args after cmd name: -q  pattern  file
        set "PAT=!A2:'=!"
        set "FIL=!A3!"
    ) else if "!A5!"=="" (
        rem 4 effective args: -q  word1  word2  file  (pattern had one internal space)
        set "PAT=!A2:'=! !A3:'=!"
        set "FIL=!A4!"
    ) else (
        rem 5 effective args: -q  word1  word2  word3  file
        set "PAT=!A2:'=! !A3:'=! !A4:'=!"
        set "FIL=!A5!"
    )

    powershell -NoProfile -Command "if (Select-String -Path '!FIL!' -Pattern '!PAT!' -Quiet -SimpleMatch) { exit 0 } else { exit 1 }"
    exit /b %ERRORLEVEL%
)

rem Non -q mode: print matching lines
set "PAT=%~1"
set "PAT=!PAT:'=!"
powershell -NoProfile -Command "Select-String -Path '%~2' -Pattern '!PAT!' -SimpleMatch"
exit /b %ERRORLEVEL%
