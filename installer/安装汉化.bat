@echo off
setlocal
chcp 65001 >nul 2>&1
cd /d "%~dp0"
title ROB RUN 汉化 - 安装

if not exist "%~dp0install.ps1" (
    echo.
    echo [错误] 没有找到 install.ps1
    echo 请把压缩包完整解压后再双击，不要在压缩包里直接运行。
    echo.
    pause
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" -NoPause %*
set "RC=%ERRORLEVEL%"

if not "%RC%"=="0" (
    echo.
    echo [安装未完成] 退出码 %RC%
    echo 日志: %TEMP%\ROBRUN-ZH-install.log
)
echo.
pause
endlocal
exit /b %RC%
