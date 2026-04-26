@echo off
REM ──────────────────────────────────────────────────────────────
REM batch-ingest.cmd — 批量导入文献到 MemPalace ingestion 管道 (Windows)
REM
REM 用法: set ADMIN_ACCESS_TOKEN=... && scripts\batch-ingest.cmd <文献目录> [ADMIN_API_BASE_URL]
REM
REM 遍历目录中的所有文件，对每个文件：
REM   1. 从文件名推断 bookTitle
REM   2. curl POST /api/admin/knowledge/ingestion/upload
REM   3. 轮询 job 状态直到 COMPLETED / FAILED
REM   4. sleep 1s（rate limiting）
REM 最后输出汇总：成功 / 失败 / 总数
REM ──────────────────────────────────────────────────────────────
setlocal enabledelayedexpansion

REM ── 参数 ──
if "%~1"=="" (
    echo 用法: set ADMIN_ACCESS_TOKEN=... ^&^& %~nx0 ^<文献目录^> [ADMIN_API_BASE_URL]
    exit /b 1
)

if "%ADMIN_ACCESS_TOKEN%"=="" (
    echo 错误: 需要 ADMIN_ACCESS_TOKEN 环境变量。请先调用 /api/admin/auth/login 获取管理员 access token。
    exit /b 1
)

set "DOCS_DIR=%~1"
set "API_BASE=%~2"
if "%API_BASE%"=="" set "API_BASE=http://localhost:8081"
set "UPLOAD_URL=%API_BASE%/api/admin/knowledge/ingestion/upload"
set "JOBS_URL=%API_BASE%/api/admin/knowledge/ingestion/jobs"

REM ── 计数器 ──
set /a TOTAL=0
set /a SUCCESS=0
set /a FAILED=0

REM ── 轮询配置 ──
set /a POLL_INTERVAL=3
set /a POLL_MAX_ATTEMPTS=120

REM ── 检查目录 ──
if not exist "%DOCS_DIR%\" (
    echo 错误: 目录不存在: %DOCS_DIR%
    exit /b 1
)

REM ── 检查 curl ──
where curl >nul 2>&1
if errorlevel 1 (
    echo 错误: 需要 curl 命令，请确保已安装并在 PATH 中
    exit /b 1
)

echo [INFO] 批量导入开始
echo [INFO] 文献目录: %DOCS_DIR%
echo [INFO] Admin API: %UPLOAD_URL%
echo ────────────────────────────────────────

REM ── 遍历文件 ──
for %%F in ("%DOCS_DIR%\*.*") do (
    set /a TOTAL+=1

    set "FILENAME=%%~nxF"
    set "FILEPATH=%%F"

    REM 提取 bookTitle：文件名去扩展名，替换下划线和连字符为空格
    set "BOOK_TITLE=%%~nF"
    set "BOOK_TITLE=!BOOK_TITLE:_= !"
    set "BOOK_TITLE=!BOOK_TITLE:-= !"

    echo [INFO] [!TOTAL!] 上传: !FILENAME! ^(bookTitle: !BOOK_TITLE!^)

    REM 上传文件
    set "RESPONSE_FILE=%TEMP%\babytalk_upload_!TOTAL!.json"
    curl -s -o "!RESPONSE_FILE!" -w "%%{http_code}" ^
        -X POST "%UPLOAD_URL%" ^
        -H "Authorization: Bearer %ADMIN_ACCESS_TOKEN%" ^
        -F "file=@!FILEPATH!" ^
        -F "bookTitle=!BOOK_TITLE!" > "%TEMP%\babytalk_http_code.txt" 2>nul

    set /p HTTP_CODE=<"%TEMP%\babytalk_http_code.txt"

    if not "!HTTP_CODE!"=="202" (
        echo [FAIL] 上传失败 ^(HTTP !HTTP_CODE!^): !FILENAME!
        set /a FAILED+=1
        timeout /t 1 /nobreak >nul
    ) else (
        REM 提取 jobId（简单字符串解析）
        set "JOB_ID="
        for /f "tokens=2 delims=:}" %%J in ('findstr /i "jobId" "!RESPONSE_FILE!"') do (
            set "JOB_ID=%%~J"
            REM 去掉引号
            set "JOB_ID=!JOB_ID:"=!"
        )

        if "!JOB_ID!"=="" (
            echo [FAIL] 无法解析 jobId: !FILENAME!
            set /a FAILED+=1
        ) else (
            echo [INFO]   jobId: !JOB_ID!

            REM 轮询 job 状态
            set /a ATTEMPT=0
            set "JOB_DONE=0"

            :poll_loop
            if !ATTEMPT! geq %POLL_MAX_ATTEMPTS% (
                echo [FAIL] job !JOB_ID! 轮询超时
                set /a FAILED+=1
                set "JOB_DONE=1"
            )

            if "!JOB_DONE!"=="0" (
                set "STATUS_FILE=%TEMP%\babytalk_status_!TOTAL!.json"
                curl -s -o "!STATUS_FILE!" -H "Authorization: Bearer %ADMIN_ACCESS_TOKEN%" "%JOBS_URL%/!JOB_ID!" 2>nul

                findstr /i "COMPLETED" "!STATUS_FILE!" >nul 2>&1
                if not errorlevel 1 (
                    echo [OK]   job !JOB_ID! 完成
                    set /a SUCCESS+=1
                    set "JOB_DONE=1"
                )

                if "!JOB_DONE!"=="0" (
                    findstr /i "FAILED" "!STATUS_FILE!" >nul 2>&1
                    if not errorlevel 1 (
                        echo [FAIL] job !JOB_ID! 失败
                        set /a FAILED+=1
                        set "JOB_DONE=1"
                    )
                )

                if "!JOB_DONE!"=="0" (
                    timeout /t %POLL_INTERVAL% /nobreak >nul
                    set /a ATTEMPT+=1
                    goto :poll_loop
                )
            )
        )

        timeout /t 1 /nobreak >nul
    )

    REM 清理临时文件
    if exist "!RESPONSE_FILE!" del "!RESPONSE_FILE!" 2>nul
)

REM ── 汇总 ──
echo.
echo ════════════════════════════════════════
echo   批量导入完成
echo ────────────────────────────────────────
echo   总数:   %TOTAL%
echo   成功:   %SUCCESS%
echo   失败:   %FAILED%
if %TOTAL% gtr 0 (
    set /a RATE=SUCCESS*100/TOTAL
    echo   成功率: !RATE!%%
)
echo ════════════════════════════════════════

REM 清理
if exist "%TEMP%\babytalk_http_code.txt" del "%TEMP%\babytalk_http_code.txt" 2>nul

if %FAILED% gtr 0 exit /b 1
exit /b 0
