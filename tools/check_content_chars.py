#!/usr/bin/env python3
"""核对内容候选里的汉字是否在寒蝉龙藏体（hanchanlongcang.otf）字形表里。

为什么必须查：信纸上的称谓/正文/落款用项目字体渲染。字体 CJK 覆盖率只有 32.4%，
一旦用了缺字的词，运行时靠 FontFallback 挂的系统字体兜底 —— 字能显示，但**和书法字混排**，
信纸观感就破了。所以扩充词库前先把每个候选字撞一遍 cmap。

用法：
  python tools/check_content_chars.py
  python tools/check_content_chars.py --json data/content_candidates_2026-10-18.json

退出码：0 = 全部覆盖；1 = 有缺字（会列出缺字与受影响的词）。
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

FONT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                    "assets", "fonts", "hanchanlongcang.otf")
DEFAULT_JSON = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                            "data", "content_candidates_2026-10-18.json")


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
    ap = argparse.ArgumentParser(description="核对候选内容字的字体覆盖")
    ap.add_argument("--json", default=DEFAULT_JSON)
    ap.add_argument("--font", default=FONT)
    args = ap.parse_args()

    if not os.path.exists(args.font):
        print(f"字体不存在：{args.font}")
        return 2
    if not os.path.exists(args.json):
        print(f"候选 JSON 不存在：{args.json}")
        return 2

    cmap = load_cmap(args.font)
    with open(args.json, "r", encoding="utf-8") as f:
        data = json.load(f)

    all_chars: set[str] = set()
    bad_words: list[tuple[str, str, list[str]]] = []
    for trail, text in walk_strings(data):
        # 模板里的占位符 {name} 等不参与检查
        cleaned = text.replace("{", "").replace("}", "")
        chars = {c for c in cleaned if "\u4e00" <= c <= "\u9fff"}
        all_chars |= chars
        missing = sorted(c for c in chars if c not in cmap)
        if missing:
            bad_words.append((trail, text, missing))

    print(f"字体：{os.path.basename(args.font)}  字形表含 {len(cmap)} 个码位")
    print(f"候选条目：{len(list(walk_strings(data)))} 条，涉及汉字 {len(all_chars)} 个")
    if not bad_words:
        print("[OK] 全部覆盖：候选里的每个汉字在字体里都有字形")
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
