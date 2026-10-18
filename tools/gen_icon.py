#!/usr/bin/env python3
"""生成《代书》应用图标（程序化、可重跑、无第三方素材）。

设计：暖纸底 + 朱砂内框 + 书法体「书」+ 右下角小朱印。
输出 256×256 PNG（Godot 的 config/icon 用这张），4× 超采样后降采样，边缘干净。

用法：python tools/gen_icon.py
"""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
FONT = ROOT / "assets" / "fonts" / "hanchanlongcang.otf"
OUT = ROOT / "assets" / "images" / "ui" / "icon.png"

SIZE = 256
SS = 4  # 超采样倍数
PAPER = (239, 227, 203, 255)
INK = (36, 28, 18, 255)
CINNABAR = (164, 60, 44, 255)


def main() -> int:
    if not FONT.exists():
        print(f"[FAIL] 缺字体：{FONT}")
        return 1

    big = SIZE * SS
    img = Image.new("RGBA", (big, big), PAPER)
    draw = ImageDraw.Draw(img)

    # 朱砂内框（留出 8% 边距，线宽 2.6%）
    margin = int(big * 0.08)
    width = max(2, int(big * 0.026))
    draw.rectangle(
        [margin, margin, big - margin - 1, big - margin - 1],
        outline=CINNABAR,
        width=width,
    )

    # 正中的「书」，书法体；字号按画布 62% 调
    font_size = int(big * 0.62)
    font = ImageFont.truetype(str(FONT), font_size)
    ch = "书"
    left, top, right, bottom = draw.textbbox((0, 0), ch, font=font)
    tw, th = right - left, bottom - top
    draw.text(
        ((big - tw) / 2 - left, (big - th) / 2 - top),
        ch,
        font=font,
        fill=INK,
    )

    # 右下角小朱印（对应"落款用印"的意象）
    seal = int(big * 0.11)
    sx = big - margin - seal - int(big * 0.02)
    sy = big - margin - seal - int(big * 0.02)
    draw.rectangle([sx, sy, sx + seal, sy + seal], fill=CINNABAR)

    img = img.resize((SIZE, SIZE), Image.LANCZOS)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    img.save(OUT, "PNG", optimize=True)

    print(f"[OK] 已生成 {OUT.relative_to(ROOT)}  {img.size[0]}x{img.size[1]}  {OUT.stat().st_size} B")
    return 0


if __name__ == "__main__":
    sys.exit(main())
