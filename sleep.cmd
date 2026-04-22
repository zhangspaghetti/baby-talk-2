@echo off
REM sleep shim: Windows CMD 没有 sleep，用 timeout 替代
REM Usage: sleep <seconds>
timeout /T %1 /NOBREAK > NUL
