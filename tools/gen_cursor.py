#!/usr/bin/env python3
"""生成《代书》的毛笔系统光标（单一笔尖、透明背景、朝上、64×64）。

为什么不用拖拽预览那张 `brush_cursor.png`：那张是**场景插画**（带纸张与场景感），
缩到 16–32 px 的系统光标尺寸会糊成一团墨点（这一点在 word_button.gd 的注释里也记着）。
系统光标要的是"单一笔尖 + 干净轮廓 + 明确的尖端"，所以这里单独画：

  1. 4× 超采样画形状（256×256），再 LANCZOS 降采样到 64×64 —— 边缘才有抗锯齿
  2. 笔尖朝上（尖端在 (32,6)），向下逐渐变宽、收成圆角笔肚
  3. 加几道浅色鬃毛线，避免纯色块看起来像"三角形"
  4. 背景全透明；四周留 4 px 空白，避免光标贴边被裁

产物：assets/images/ui/cursor_brush_tip.png
用法：python tools/gen_cursor.py
"""

from __future__ import annotations

import os
import random

from PIL import Image, ImageDraw, ImageFilter

SS = 4            # 超采样倍数
SIZE = 64         # 最终尺寸
INK = (26, 22, 18, 255)
INK_SOFT = (58, 48, 38, 190)
BRISTLE = (120, 104, 84, 120)
HOTSPOT = (32, 6)


def build() -> Image.Image:
    rng = random.Random(20261018)
    s = SS
    cx = SIZE * s // 2
    y_top, y_bottom = 7 * s, 52 * s
    steps = 60

    # --- 1) 形状层：笔尖轮廓 + 圆笔肚 ---
    shape = Image.new("RGBA", (SIZE * SS, SIZE * SS), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shape)
    left, right = [], []
    for i in range(steps + 1):
        t = i / steps                                # 0=尖端, 1=笔肚
        y = y_top + (y_bottom - y_top) * t
        # 宽度曲线：尖端极窄，中段快速变宽，底端略收
        half = (1.2 + 26.0 * (t ** 0.62)) * (1.0 - 0.18 * (t ** 6))
        half *= s
        left.append((cx - half, y))
        right.append((cx + half, y))
    sd.polygon(left + list(reversed(right)), fill=INK)
    r = 12 * s
    sd.ellipse([cx - r, y_bottom - r, cx + r, y_bottom + r * 0.42], fill=INK)

    # --- 2) 鬃毛层：只保留落在形状内的部分（否则尖端上方会出现几根"刺"） ---
    bristle = Image.new("RGBA", shape.size, (0, 0, 0, 0))
    bd = ImageDraw.Draw(bristle)
    for k in range(-3, 4):
        offset = k * 5.5 * s
        pts = []
        for i in range(steps + 1):
            t = i / steps
            y = y_top + (y_bottom - y_top) * t
            spread = (1.0 - t) * 0.35 + 0.65
            pts.append((cx + offset * spread, y))
        if len(pts) > 1:
            bd.line(pts, fill=BRISTLE, width=max(1, int(0.7 * s)))

    mask = shape.split()[3]
    bristle.putalpha(Image.composite(bristle.split()[3], Image.new("L", shape.size, 0), mask))
    img = Image.alpha_composite(shape, bristle)

    # --- 3) 尖端提亮一点点，避免 16px 下是一坨实心 ---
    hl = Image.new("RGBA", shape.size, (0, 0, 0, 0))
    hd = ImageDraw.Draw(hl)
    hd.ellipse([cx - 2.2 * s, y_top, cx + 2.2 * s, y_top + 7 * s], fill=INK_SOFT)
    hl.putalpha(Image.composite(hl.split()[3], Image.new("L", shape.size, 0), mask))
    img = Image.alpha_composite(img, hl)

    out = img.resize((SIZE, SIZE), Image.LANCZOS)
    # 一点点高斯模糊让边缘不那么"矢量"，像墨
    return out.filter(ImageFilter.GaussianBlur(0.35))


def main() -> int:
    here = os.path.dirname(os.path.abspath(__file__))
    out = os.path.join(os.path.dirname(here), "assets", "images", "ui", "cursor_brush_tip.png")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    img = build()
    img.save(out)
    print(f"写出 {out}  {img.size[0]}×{img.size[1]}  热点={HOTSPOT}  {os.path.getsize(out)} B")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
