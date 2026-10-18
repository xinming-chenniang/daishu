#!/usr/bin/env python3
"""核对内容 JSON 里的汉字是否在寒蝉龙藏体（hanchanlongcang.otf）字形表里。

为什么必须查：信纸上的称谓/正文/落款用项目字体渲染。字体 CJK 覆盖率只有 32.4%，
一旦用了缺字的词，运行时靠 FontFallback 挂的系统字体兜底 —— 字能显示，但**和书法字混排**，
信纸观感就破了。所以改词库前后都要把每个字撞一遍 cmap。

真源：`data/npc_content.json`（运行时由 NPCManager 加载）。
历史候选文件仍可查：`--json data/content_candidates_2026-10-18.json`。

用法：
  python tools/check_content_chars.py
  python tools/check_content_chars.py --json data/npc_content.json
  python tools/check_content_chars.py --json data/npc_content.json data/content_candidates_2026-10-18.json

退出码：0 = 全部覆盖；1 = 有缺字（会列出缺字与受影响的词）；2 = 文件/字体不存在。
"""

from __future__ import annotations

import argparse
import json
import os
import sys

from fontTools.ttLib import TTFont
import sys as _sys
try:
    _sys.stdout.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONT = os.path.join(ROOT, "assets", "fonts", "hanchanlongcang.otf")
DEFAULT_JSON = os.path.join(ROOT, "data", "npc_content.json")


def load_cmap(path: str) -> set[str]:
    font = TTFont(path, fontNumber=0, lazy=True)
    chars: set[str] = set()
    for table in font["cmap"].tables:
        if table.isUnicode():
            chars.update(chr(cp) for cp in table.cmap.keys())
    font.close()
    return chars


def walk_strings(obj, trail=""):
    """递归收集 JSON 里所有字符串（跳过 _comment）。"""
    if isinstance(obj, str):
        if trail.endswith("_comment"):
            return
        yield trail, obj
    elif isinstance(obj, list):
        for i, v in enumerate(obj):
            yield from walk_strings(v, f"{trail}[{i}]")
    elif isinstance(obj, dict):
        for k, v in obj.items():
            if k == "_comment":
                continue
            yield from walk_strings(v, f"{trail}.{k}" if trail else k)


def main() -> int:
    ap = argparse.ArgumentParser(description="核对内容 JSON 的汉字是否能被项目字体渲染")
    ap.add_argument("--json", nargs="+", default=[DEFAULT_JSON],
                    help=f"要检查的 JSON（默认 {os.path.relpath(DEFAULT_JSON, ROOT)}）")
    ap.add_argument("--font", default=FONT)
    args = ap.parse_args()

    if not os.path.exists(args.font):
        print(f"字体不存在：{args.font}")
        return 2
    for path in args.json:
        if not os.path.exists(path):
            print(f"JSON 不存在：{path}")
            return 2

    cmap = load_cmap(args.font)
    all_chars: set[str] = set()
    bad_words: list[tuple[str, str, list[str]]] = []
    total_entries = 0

    for path in args.json:
        # utf-8-sig：允许文件带 BOM（PowerShell 的 Set-Content、记事本另存都会加）
        try:
            with open(path, "r", encoding="utf-8-sig") as f:
                data = json.load(f)
        except json.JSONDecodeError as e:
            print(f"JSON 解析失败：{path}\n  {e}")
            return 2
        for trail, text in walk_strings(data):
            total_entries += 1
            # 模板里的占位符 {name} 等不参与检查
            cleaned = text.replace("{", "").replace("}", "")
            chars = {c for c in cleaned if "\u4e00" <= c <= "\u9fff"}
            all_chars |= chars
            missing = sorted(c for c in chars if c not in cmap)
            if missing:
                bad_words.append((f"{os.path.basename(path)}:{trail}", text, missing))

    print(f"字体：{os.path.basename(args.font)}  字形表含 {len(cmap)} 个码位")
    print(f"检查文件：{', '.join(os.path.relpath(p, ROOT) for p in args.json)}")
    print(f"条目：{total_entries} 条，涉及汉字 {len(all_chars)} 个")
    if not bad_words:
        print("[OK] 全部覆盖：内容里的每个汉字在字体里都有字形")
        return 0

    print(f"[缺字] 有 {len(bad_words)} 条含缺字：")
    missing_all: set[str] = set()
    for trail, text, missing in bad_words:
        print(f"  - {text}  缺：{'、'.join(missing)}   ({trail})")
        missing_all.update(missing)
    print(f"\n共缺 {len(missing_all)} 个字：{'、'.join(sorted(missing_all))}")
    print("处置：换用同义且字形可用的词，或把这些字补进字体（不建议，字体是第三方授权文件）。")
    return 1


if __name__ == "__main__":
    sys.exit(main())
