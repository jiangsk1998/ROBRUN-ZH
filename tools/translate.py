#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""机器翻译 + 术语表校正，生成 strings_zh.json。

设计要点:
  * 批量翻译：一次提交多行，用换行分隔，显著降低请求数
  * 富文本保护：<color=...> 之类的标签、{0} 之类的占位符先替换成
    <TG0>/<PH0> 标记，翻完再还原，避免被翻译引擎改坏
  * 断点续跑：每 100 条落盘一次，中断后重跑会跳过已完成的条目
  * 术语表优先：glossary.json 里的词条直接采用人工译法，不进翻译队列
  * 只翻译含英文字母的条目；纯数字/符号/已是中文的一律跳过

依赖: 无（只用标准库，走 Bing 网页翻译接口）

用法:
    python translate.py -i strings/strings_en.json -o strings/strings_zh.json
    python translate.py -i ... -o ... --batch 20 --sleep 0.35
"""
from __future__ import annotations

import argparse
import http.cookiejar
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

UA = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36"
)
HOST = "https://cn.bing.com"

TAG_RE = re.compile(r"<[^<>]{1,60}>")
PH_RE = re.compile(r"\{[^{}]{0,40}\}")
LETTER_RE = re.compile(r"[A-Za-z]")
CJK_RE = re.compile(r"[\u4e00-\u9fff]")


class BingFree:
    """Bing 网页翻译接口（免费，无需 key）。会被限流，所以需要退避重试。"""

    def __init__(self) -> None:
        self.jar = http.cookiejar.CookieJar()
        self.opener = urllib.request.build_opener(
            urllib.request.HTTPCookieProcessor(self.jar)
        )
        self.state: dict[str, str] = {}

    def refresh(self) -> None:
        req = urllib.request.Request(
            HOST + "/translator",
            headers={"User-Agent": UA, "Accept-Language": "zh-CN,zh;q=0.9"},
        )
        with self.opener.open(req, timeout=30) as resp:
            html = resp.read().decode("utf-8", "replace")
        ig = re.search(r'IG:"([^"]+)"', html)
        iid = re.search(r'data-iid="([^"]+)"', html)
        abuse = re.search(r"params_AbusePreventionHelper\s*=\s*\[([^\]]+)\]", html)
        if not (ig and iid and abuse):
            raise RuntimeError("页面结构变化，取不到翻译参数")
        parts = [p.strip().strip('"') for p in abuse.group(1).split(",")]
        self.state = {
            "IG": ig.group(1),
            "IID": iid.group(1),
            "KEY": parts[0],
            "TOKEN": parts[1],
        }

    def _post(self, text: str) -> str:
        body = urllib.parse.urlencode(
            [
                ("fromLang", "en"),
                ("to", "zh-Hans"),
                ("text", text),
                ("token", self.state["TOKEN"]),
                ("key", self.state["KEY"]),
            ]
        ).encode()
        url = "%s/ttranslatev3?isVertical=1&&IG=%s&IID=%s" % (
            HOST,
            self.state["IG"],
            self.state["IID"],
        )
        req = urllib.request.Request(
            url,
            data=body,
            headers={
                "User-Agent": UA,
                "Content-Type": "application/x-www-form-urlencoded",
                "Referer": HOST + "/translator",
                "Origin": HOST,
                "Accept": "*/*",
            },
        )
        try:
            with self.opener.open(req, timeout=40) as resp:
                return resp.read().decode("utf-8")
        except urllib.error.HTTPError as exc:
            return "HTTPERR:%d:%s" % (exc.code, exc.read().decode("utf-8", "replace")[:200])

    def translate(self, text: str, tries: int = 3) -> str:
        if not self.state:
            self.refresh()
        last = ""
        for attempt in range(tries):
            raw = self._post(text)
            if not raw.startswith("HTTPERR"):
                try:
                    return json.loads(raw)[0]["translations"][0]["text"]
                except Exception:
                    last = raw[:200]
                    time.sleep(1.0)
                    continue
            last = raw
            time.sleep(1.5 + attempt * 2)
            try:
                self.refresh()
            except Exception:
                pass
        raise RuntimeError(last)


def protect(text: str):
    """把标签/占位符/换行替换成安全标记，返回 (文本, 标签表, 占位符表)。"""
    tags: list[str] = []
    placeholders: list[str] = []

    def sub_tag(m):
        tags.append(m.group(0))
        return "<TG%d>" % (len(tags) - 1)

    s = TAG_RE.sub(sub_tag, text)
    s = s.replace("\r\n", "\n").replace("\r", "\n").replace("\n", "<NL>")

    def sub_ph(m):
        placeholders.append(m.group(0))
        return "<PH%d>" % (len(placeholders) - 1)

    return PH_RE.sub(sub_ph, s), tags, placeholders


def restore(text: str, tags, placeholders) -> str:
    for i, tag in enumerate(tags):
        text = re.sub(r"<\s*TG%d\s*>" % i, lambda _m, t=tag: t, text, flags=re.I)
    text = re.sub(r"<\s*NL\s*>", "\n", text, flags=re.I)
    for i, ph in enumerate(placeholders):
        text = re.sub(r"<\s*PH%d\s*>" % i, lambda _m, p=ph: p, text, flags=re.I)
    return text


def save_merge(path: str, done: dict) -> None:
    """与磁盘上已有结果合并后写回，避免中断丢数据。"""
    merged: dict[str, str] = {}
    if os.path.isfile(path):
        try:
            with open(path, encoding="utf-8") as fp:
                for k, v in json.load(fp).items():
                    if v is not None:
                        merged[k] = v
        except Exception:
            pass
    for k, v in done.items():
        if v is not None or k not in merged:
            merged[k] = v
    with open(path, "w", encoding="utf-8") as fp:
        json.dump(merged, fp, ensure_ascii=False)


def main() -> None:
    ap = argparse.ArgumentParser(description="ROB RUN 文本批量翻译")
    ap.add_argument("-i", "--input", default="strings/strings_en.json")
    ap.add_argument("-o", "--output", default="strings/strings_zh.json")
    ap.add_argument("--glossary", default="tools/glossary.json")
    ap.add_argument("--batch", type=int, default=20, help="每次提交的行数")
    ap.add_argument("--sleep", type=float, default=0.35, help="批次间隔秒数")
    ap.add_argument("--refresh-every", type=int, default=12, help="每 N 批刷新一次令牌")
    args = ap.parse_args()

    with open(args.input, encoding="utf-8") as fp:
        rows = json.load(fp)
    glossary = {}
    if os.path.isfile(args.glossary):
        with open(args.glossary, encoding="utf-8") as fp:
            glossary = json.load(fp)
    print("原文 %d 条, 术语表 %d 条" % (len(rows), len(glossary)))

    done: dict[str, str] = {}
    if os.path.isfile(args.output):
        try:
            with open(args.output, encoding="utf-8") as fp:
                done = {k: v for k, v in json.load(fp).items() if v is not None}
            print("续跑: 已有 %d 条" % len(done))
        except Exception:
            done = {}

    todo = []
    for row in rows:
        sid = str(row["id"])
        src = row.get("value") or ""
        if sid in done:
            continue
        if src in glossary:  # 术语表命中，直接采用人工译法
            done[sid] = glossary[src]
            continue
        if not src.strip() or not LETTER_RE.search(src) or CJK_RE.search(src):
            done[sid] = src  # 无需翻译
            continue
        protected, tags, phs = protect(src)
        todo.append((sid, protected, tags, phs))
    print("待翻译 %d 条" % len(todo))

    engine = BingFree()
    engine.refresh()
    batch_no = 0
    index = 0
    while index < len(todo):
        chunk = todo[index : index + args.batch]
        batch_no += 1
        if batch_no % args.refresh_every == 0:
            try:
                engine.refresh()
            except Exception:
                pass
        payload = "\n".join(item[1] for item in chunk)
        try:
            out = engine.translate(payload)
            parts = out.replace("\r\n", "\n").split("\n")
            if len(parts) != len(chunk):
                raise RuntimeError("行数不匹配 %d != %d" % (len(parts), len(chunk)))
            for (sid, _p, tags, phs), line in zip(chunk, parts):
                done[sid] = restore(line.strip(), tags, phs)
        except Exception as exc:
            # 批量失败就退化成逐条，避免整批丢失
            print("  批次 %d 失败(%s)，改为逐条" % (batch_no, str(exc)[:80]))
            for sid, protected, tags, phs in chunk:
                try:
                    done[sid] = restore(engine.translate(protected).strip(), tags, phs)
                    time.sleep(0.25)
                except Exception:
                    done[sid] = None
        index += len(chunk)
        if index % 100 < args.batch:
            save_merge(args.output, done)
            print("  进度 %d/%d" % (index, len(todo)))
        time.sleep(args.sleep)

    save_merge(args.output, done)
    good = sum(1 for v in done.values() if v is not None)
    print("完成: 有效 %d 条 -> %s" % (good, args.output))
    if good < len(rows):
        sys.exit(1)


if __name__ == "__main__":
    main()
