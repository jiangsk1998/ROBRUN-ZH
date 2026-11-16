#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""打包发布版：生成可直接分发的 ROBRUN-ZH-CN.zip。

压缩包结构（用户解压后双击 bat 即可）:
    ROBRUN-ZH-CN/
        安装汉化.bat
        卸载汉化.bat
        install.ps1
        uninstall.ps1
        说明.txt
        bundle/<语言包>

用法:
    python tools/package.py
"""
from __future__ import annotations

import os
import shutil
import sys
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BUNDLE_NAME = (
    "localization-string-tables-english(unitedstates)(en-us)_assets_all.bundle"
)
ZIP_NAME = "ROBRUN-ZH-CN"

README_TXT = """ROB RUN 简体中文汉化包 v1.0.0
================================

安装
----
1. 完全退出游戏（任务管理器里 ROB RUN.exe 和 start_protected_game.exe 都要没了）
2. 双击「安装汉化.bat」
3. 看到「[成功] 汉化已安装」后，从 Steam 库启动游戏
   注意：游戏内语言请保持 English（我们替换的就是英文语言包）

还原英文
--------
双击「卸载汉化.bat」

游戏更新后
----------
Steam 更新会覆盖语言包，重新双击一次「安装汉化.bat」即可。

关于
----
- 已翻译 4763 条中的 4567 条（95.9%）
- 不修改 exe / dll，只替换语言包资源文件
- 项目主页：https://github.com/jiangsk1998/ROBRUN-ZH
- 仅供个人学习交流，请支持正版
"""


def main() -> None:
    patch = os.path.join(ROOT, "patch", BUNDLE_NAME)
    if not os.path.isfile(patch):
        sys.exit("[错误] 找不到汉化 bundle: %s" % patch)

    out = os.path.join(ROOT, ZIP_NAME + ".zip")
    if os.path.isfile(out):
        os.remove(out)

    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as zf:
        base = ZIP_NAME + "/"
        # 安装脚本
        for name in ("install.ps1", "uninstall.ps1", "安装汉化.bat", "卸载汉化.bat"):
            src = os.path.join(ROOT, "installer", name)
            if not os.path.isfile(src):
                sys.exit("[错误] 缺少文件: %s" % src)
            zf.write(src, base + name)
        # 语言包
        zf.write(patch, base + "bundle/" + BUNDLE_NAME)
        # 说明
        zf.writestr(base + "说明.txt", README_TXT.encode("utf-8-sig"))

    size = os.path.getsize(out) / 1024
    print("已生成: %s (%.0f KB)" % (out, size))
    print("\n文件清单:")
    with zipfile.ZipFile(out) as zf:
        for info in zf.infolist():
            print("  %8.1f KB  %s" % (info.file_size / 1024, info.filename))


if __name__ == "__main__":
    main()
