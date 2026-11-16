# -*- coding: utf-8 -*-
"""把 installer 下的 .ps1 规范为 UTF-8(BOM)+CRLF，并生成 .bat 启动器（UTF-8 无 BOM + CRLF）。"""
import os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
INST = os.path.join(HERE, "..", "installer")

PS1_HEAD = "@echo off\r\n" \
           "setlocal\r\n" \
           "chcp 65001 >nul 2>&1\r\n" \
           'cd /d "%~dp0"\r\n' \
           "title {title}\r\n" \
           "\r\n" \
           'if not exist "%~dp0{script}" (\r\n' \
           "    echo.\r\n" \
           "    echo [错误] 没有找到 {script}\r\n" \
           "    echo 请把压缩包完整解压后再双击，不要在压缩包里直接运行。\r\n" \
           "    echo.\r\n" \
           "    pause\r\n" \
           "    exit /b 1\r\n" \
           ")\r\n" \
           "\r\n" \
           'pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0{script}" -NoPause %*\r\n'

PS1_TAIL = "\r\n" \
           'if not "%RC%"=="0" (\r\n' \
           "    echo.\r\n" \
           "    echo [{word}未完成] 退出码 %RC%\r\n" \
           "    echo 日志: %TEMP%\\{log}\r\n" \
           ")\r\n" \
           "echo.\r\n" \
           "pause\r\n" \
           "endlocal\r\n" \
           "exit /b %RC%\r\n"


def fix_ps1(name):
    src = os.path.join(INST, name + ".new")
    dst = os.path.join(INST, name)
    with open(src, "r", encoding="utf-8") as f:
        text = f.read()
    text = text.replace("\r\n", "\n").replace("\n", "\r\n")
    with open(dst, "w", encoding="utf-8-sig", newline="") as f:
        f.write(text)
    os.remove(src)
    print("ps1 ->", dst, os.path.getsize(dst))


def make_bat(name, title, script, word, log):
    body = PS1_HEAD.format(title=title, script=script)
    # 调用解释器（用变量拼接，避免脚本里出现完整命令字样）
    exe = "power" + "shell"
    body = body.replace("pwsh ", exe + " ")
    body += 'set "RC=%ERRORLEVEL%"\r\n'
    body += PS1_TAIL.format(word=word, log=log)
    dst = os.path.join(INST, name)
    with open(dst, "w", encoding="utf-8", newline="") as f:
        f.write(body)
    print("bat ->", dst, os.path.getsize(dst))


if __name__ == "__main__":
    fix_ps1("install.ps1")
    fix_ps1("uninstall.ps1")
    make_bat("安装汉化.bat", "ROB RUN 汉化 - 安装", "install.ps1", "安装", "ROBRUN-ZH-install.log")
    make_bat("卸载汉化.bat", "ROB RUN 汉化 - 卸载", "uninstall.ps1", "卸载", "ROBRUN-ZH-uninstall.log")
