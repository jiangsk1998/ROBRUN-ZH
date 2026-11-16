#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""从 Unity Addressables 语言包中提取原始文本表。

ROB RUN 使用 Unity Localization 框架，所有界面文本存在一个 MonoBehaviour
资源里，资源名形如 ``StaticStrings_en-US``，字段结构：

    m_TableData: [ { m_Id: int, m_Key: str, m_Localized: str }, ... ]

本脚本只读不写，输出 JSON 供人工校对或后续翻译使用。

用法:
    python extract.py --game "D:\\Steam\\steamapps\\common\\Rob Run" -o strings_en.json
    python extract.py --bundle path/to/xxx.bundle -o strings_en.json
"""
from __future__ import annotations

import argparse
import json
import os
import sys

import UnityPy

BUNDLE_REL = os.path.join(
    "ROB RUN_Data", "StreamingAssets", "aa", "StandaloneWindows64"
)
BUNDLE_NAME = (
    "localization-string-tables-english(unitedstates)(en-us)_assets_all.bundle"
)
TABLE_NAME = "StaticStrings_en-US"


def resolve_bundle(game_dir: str, bundle: str | None) -> str:
    """定位语言包文件。"""
    if bundle:
        if not os.path.isfile(bundle):
            sys.exit("[错误] 指定的 bundle 不存在: %s" % bundle)
        return bundle
    if not game_dir:
        sys.exit("[错误] 需要 --game 或 --bundle 之一")
    path = os.path.join(game_dir, BUNDLE_REL, BUNDLE_NAME)
    if not os.path.isfile(path):
        sys.exit("[错误] 游戏目录下找不到语言包: %s" % path)
    return path


def find_table(env, name: str = TABLE_NAME):
    """在 bundle 里找到指定名字的 MonoBehaviour，返回 (obj, typetree)。"""
    for obj in env.objects:
        if obj.type.name != "MonoBehaviour":
            continue
        tree = obj.read_typetree()
        if tree.get("m_Name") == name:
            return obj, tree
    return None, None


def extract(bundle_path: str) -> list[dict]:
    env = UnityPy.load(bundle_path)
    _, tree = find_table(env)
    if tree is None:
        sys.exit("[错误] bundle 中没有找到文本表 %s" % TABLE_NAME)
    rows = []
    for entry in tree["m_TableData"]:
        rows.append(
            {
                "id": entry["m_Id"],
                "key": entry.get("m_Key", ""),
                "value": entry.get("m_Localized", ""),
            }
        )
    return rows


def main() -> None:
    ap = argparse.ArgumentParser(description="提取 ROB RUN 语言包文本")
    ap.add_argument("--game", help="游戏根目录（含 ROB RUN_Data 的那一层）")
    ap.add_argument("--bundle", help="直接指定 .bundle 文件路径")
    ap.add_argument("-o", "--output", default="strings_en.json", help="输出 JSON 路径")
    args = ap.parse_args()

    bundle = resolve_bundle(args.game, args.bundle)
    print("[1/2] 读取: %s" % bundle)
    rows = extract(bundle)

    os.makedirs(os.path.dirname(os.path.abspath(args.output)) or ".", exist_ok=True)
    with open(args.output, "w", encoding="utf-8") as fp:
        json.dump(rows, fp, ensure_ascii=False, indent=1)

    nonempty = sum(1 for r in rows if (r["value"] or "").strip())
    print("[2/2] 已导出 %d 条（非空 %d 条）-> %s" % (len(rows), nonempty, args.output))


if __name__ == "__main__":
    main()
