@echo off
REM 委托脚本：从 worktree 根运行 flutter 命令时，自动切换到 mobile/ 子工程
REM 这样 gate 运行 "flutter test test/smoke/" 时可以找到正确的 pubspec.yaml
cd /d "%~dp0mobile" && flutter %*
