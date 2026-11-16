#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""把译文写回 Unity Addressables 语言包，生成可安装的 bundle。

流程:
    原版 bundle  --> UnityPy 解析 --> 替换 StaticStrings_en-US 的
    m_Localized 字段 --> 重新封包 --> dist/

关键点:
  * 只改 MonoBehaviour 的文本字段，不碰 dll / Assembly-CSharp / 可执行文件
  * 通过 TypeTree 结构化写入，不做字节级暴力替换，避免破坏资源
  * 术语表（glossary.json）优先级高于机器翻译
  * 译文缺失时回退到原文，保证不会出现空白

用法:
    python build.py --game "D:\\Steam\\steamapps\\common\\Rob Run"
    python build.py --game ... --zh strings_zh.json --out dist
"""
from __future__ import annotations

import argparse
import json
import os
import shutil
import sys

import UnityPy

BUNDLE_REL = os.path.join(
    "ROB RUN_Data", "StreamingAssets", "aa", "StandaloneWindows64"
)
BUNDLE_NAME = (
    "localization-string-tables-english(unitedstates)(en-us)_assets_all.bundle"
)
TABLE_NAME = "StaticStrings_en-US"


def load_json(path: str, default=None):
    if not os.path.isfile(path):
        return default
    with open(path, encoding="utf-8") as fp:
        return json.load(fp)


def resolve_source(game_dir: str, bundle: str | None) -> str:
    """优先用原版备份，避免在已汉化的包上二次打补丁。"""
    if bundle:
        return bundle
    target = os.path.join(game_dir, BUNDLE_REL, BUNDLE_NAME)
    backup = target + ".original_bak"
    if os.path.isfile(backup):
        return backup
    return target


def main() -> None:
    ap = argparse.ArgumentParser(description="生成 ROB RUN 简体中文语言包")
    ap.add_argument("--game", help="游戏根目录")
    ap.add_argument("--bundle", help="指定原始 .bundle（优先于 --game）")
    ap.add_argument("--zh", default="strings/strings_zh.json", help="译文 JSON")
    ap.add_argument("--glossary", default="tools/glossary.json", help="术语表 JSON")
    ap.add_argument("--out", default="dist", help="输出目录")
    args = ap.parse_args()

    if not args.game and not args.bundle:
        sys.exit("[错误] 需要 --game 或 --bundle 之一")

    src = resolve_source(args.game, args.bundle)
    if not os.path.isfile(src):
        sys.exit("[错误] 找不到原始 bundle: %s" % src)
    print("[1/4] 源文件: %s" % src)

    zh = load_json(args.zh, {})
    if not zh:
        sys.exit("[错误] 译文文件不存在或为空: %s" % args.zh)
    glossary = load_json(args.glossary, {})
    print("[2/4] 译文 %d 条, 术语表 %d 条" % (len(zh), len(glossary)))

    env = UnityPy.load(src)
    patched = False
    for obj in env.objects:
        if obj.type.name != "MonoBehaviour":
            continue
        tree = obj.read_typetree()
        if tree.get("m_Name") != TABLE_NAME:
            continue

        changed = 0
        for entry in tree["m_TableData"]:
            sid = str(entry["m_Id"])
            old = entry.get("m_Localized")
            if not isinstance(old, str):
                continue
            # 术语表优先，其次机器翻译，最后回退原文
            new = glossary.get(old) or zh.get(sid)
            if new and new != old:
                entry["m_Localized"] = new
                changed += 1
        obj.save_typetree(tree)
        print("[3/4] 写入 %d 条（共 %d 条）" % (changed, len(tree["m_TableData"])))
        patched = True
        break

    if not patched:
        sys.exit("[错误] 未找到文本表 %s，游戏版本可能已变化" % TABLE_NAME)

    outdir = os.path.join(args.out, "bundle")
    if os.path.isdir(outdir):
        shutil.rmtree(outdir)
    os.makedirs(outdir, exist_ok=True)
    env.save(out_path=outdir)

    produced = [f for f in os.listdir(outdir) if f.endswith(".bundle")]
    if not produced:
        sys.exit("[错误] 封包失败，没有生成 bundle")
    path = os.path.join(outdir, produced[0])
    print("[4/4] 生成: %s (%.0f KB)" % (path, os.path.getsize(path) / 1024))

    # 回读校验，确认中文真的写进去了
    env2 = UnityPy.load(path)
    for obj in env2.objects:
        if obj.type.name != "MonoBehaviour":
            continue
        tree = obj.read_typetree()
        if tree.get("m_Name") != TABLE_NAME:
            continue
        total = len(tree["m_TableData"])
        cjk = sum(
            1
            for e in tree["m_TableData"]
            if isinstance(e.get("m_Localized"), str)
            and any("\u4e00" <= ch <= "\u9fff" for ch in e["m_Localized"])
        )
        print("      校验: 共 %d 条，含中文 %d 条" % (total, cjk))
        if cjk == 0:
            sys.exit("[错误] 校验失败：生成的包里没有中文")
        break
    print("完成。")


if __name__ == "__main__":
    main()
