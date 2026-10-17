#!/usr/bin/env python3
"""生成《代书》的 UI 音效（程序化合成，无第三方素材，授权干净）。

为什么程序化生成而不是去找 CC0 素材：
  - 仓库要能自洽：不引入来源不明/需要署名/体积大的音频；
  - 本项目是"毛笔 + 纸 + 木构"的听觉气质，短促的木头/纸声比通用 UI 音效更贴；
  - 合成脚本可重跑，参数即文档（改一版音色不用找素材）。

产物（16-bit 单声道 44.1 kHz WAV）：
  assets/audio/sfx/ui_click.wav    木头轻叩，~70 ms
  assets/audio/sfx/paper_drop.wav  纸落案上，~180 ms
  assets/audio/sfx/submit.wav      落笔/润墨，~450 ms
  assets/audio/sfx/day_end.wav     低音磬，~800 ms

用法：
  python tools/gen_sfx.py                # 写入 assets/audio/sfx/
  python tools/gen_sfx.py --out <目录>    # 写到别处（自检用）

依赖：numpy（DSH 运行时自带 2.3.5）。不依赖 scipy —— 滤波用一阶低通/高通手写。
"""

from __future__ import annotations

import argparse
import math
import os
import wave

import numpy as np

SR = 44100
PEAK = 0.45  # 留足余量，UI 音效不该顶满


def _t(duration: float) -> np.ndarray:
    return np.arange(int(SR * duration), dtype=np.float64) / SR


def _fade(x: np.ndarray, fade_in: float = 0.002, fade_out: float = 0.02) -> np.ndarray:
    """首尾淡入淡出，避免波形截断产生的"咔哒"声。"""
    n = x.size
    ni = min(int(SR * fade_in), n // 2)
    no = min(int(SR * fade_out), n // 2)
    if ni > 0:
        x[:ni] *= np.linspace(0.0, 1.0, ni)
    if no > 0:
        x[-no:] *= np.linspace(1.0, 0.0, no)
    return x


def _normalize(x: np.ndarray, peak: float = PEAK) -> np.ndarray:
    m = float(np.max(np.abs(x))) if x.size else 0.0
    if m <= 0:
        return x
    return x * (peak / m)


def _lowpass(x: np.ndarray, cutoff: float) -> np.ndarray:
    """一阶 IIR 低通（够用；不做相位校正）。"""
    a = math.exp(-2.0 * math.pi * cutoff / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1.0 - a) * v + a * acc
        y[i] = acc
    return y


def _highpass(x: np.ndarray, cutoff: float) -> np.ndarray:
    return x - _lowpass(x, cutoff)


def _noise(n: int, rng: np.random.Generator) -> np.ndarray:
    return rng.standard_normal(n)


def ui_click(rng: np.random.Generator) -> np.ndarray:
    """木鱼/算盘珠那种短促硬质轻叩。"""
    t = _t(0.07)
    body = (
        0.55 * np.sin(2 * math.pi * 1750 * t)
        + 0.30 * np.sin(2 * math.pi * 2600 * t)
        + 0.15 * np.sin(2 * math.pi * 950 * t)
    )
    body *= np.exp(-t / 0.010)

    n = t.size
    burst = _highpass(_noise(n, rng), 2200.0) * np.exp(-t / 0.003) * 0.35

    return _fade(_normalize(body + burst, 0.50), 0.0005, 0.012)


def paper_drop(rng: np.random.Generator) -> np.ndarray:
    """一张纸落到木案上：宽带沙沙 + 一点低频"咚"。"""
    t = _t(0.18)
    n = t.size
    noise = _highpass(_lowpass(_noise(n, rng), 5200.0), 900.0)
    # 纸面摩擦不是指数衰减，用"快起 + 拖尾"的两段包络
    env = np.exp(-t / 0.045) * (1.0 - np.exp(-t / 0.004))
    rustle = noise * env * 0.9

    thump = np.sin(2 * math.pi * 140 * t) * np.exp(-t / 0.030) * 0.5
    return _fade(_normalize(rustle + thump, 0.42), 0.001, 0.03)


def submit(rng: np.random.Generator) -> np.ndarray:
    """落笔润墨：先一声轻扫，再一记很轻的铃（提示"交出去了"）。"""
    t = _t(0.45)
    n = t.size

    sweep = _lowpass(_noise(n, rng), 3000.0) * (1.0 - np.exp(-t / 0.03)) * np.exp(-t / 0.12) * 0.55

    bell = np.zeros(n)
    for freq, amp, decay in ((880.0, 0.5, 0.22), (1320.0, 0.22, 0.14), (1760.0, 0.1, 0.09)):
        bell += amp * np.sin(2 * math.pi * freq * t) * np.exp(-t / decay)
    bell *= (1.0 - np.exp(-t / 0.002))

    return _fade(_normalize(sweep + bell * 0.7, 0.44), 0.002, 0.06)


def day_end(rng: np.random.Generator) -> np.ndarray:
    """日终结算：低音磬（不谐和泛音 + 缓慢衰减），收摊的意味。"""
    t = _t(0.80)
    n = t.size
    gong = np.zeros(n)
    # 磬/钟的泛音不是严格整数倍，这里刻意用非整数比制造金属感
    partials = ((156.8, 0.55, 0.42), (235.0, 0.28, 0.30), (313.6, 0.18, 0.24), (392.4, 0.10, 0.18))
    for i, (freq, amp, decay) in enumerate(partials):
        # 每个泛音略微失谐、起音错开，避免"电子音"的齐奏感
        detune = 1.0 + (0.0015 * (i + 1))
        onset = 0.004 * i
        env = np.exp(-np.maximum(t - onset, 0.0) / decay) * (t >= onset)
        gong += amp * np.sin(2 * math.pi * freq * detune * t) * env

    air = _lowpass(_noise(n, rng), 1200.0) * np.exp(-t / 0.05) * 0.05
    return _fade(_normalize(gong + air, 0.40), 0.003, 0.12)


SOUNDS = {
    "ui_click": ui_click,
    "paper_drop": paper_drop,
    "submit": submit,
    "day_end": day_end,
}


def write_wav(path: str, x: np.ndarray) -> None:
    data = np.clip(x, -1.0, 1.0)
    pcm = (data * 32767.0).astype("<i2")
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    with wave.open(path, "wb") as fh:
        fh.setnchannels(1)
        fh.setsampwidth(2)
        fh.setframerate(SR)
        fh.writeframes(pcm.tobytes())


def main() -> int:
    here = os.path.dirname(os.path.abspath(__file__))
    default_out = os.path.join(os.path.dirname(here), "assets", "audio", "sfx")

    ap = argparse.ArgumentParser(description="生成《代书》UI 音效")
    ap.add_argument("--out", default=default_out, help=f"输出目录（默认 {default_out}）")
    args = ap.parse_args()

    rng = np.random.default_rng(20261018)  # 固定种子：重跑得到同一批文件
    print(f"输出目录：{args.out}")
    for name, fn in SOUNDS.items():
        x = fn(rng)
        path = os.path.join(args.out, f"{name}.wav")
        write_wav(path, x)
        peak = float(np.max(np.abs(x)))
        rms = float(np.sqrt(np.mean(x ** 2)))
        print(
            f"  {name:<12} {x.size / SR * 1000:6.0f} ms  "
            f"peak {peak:.2f}  rms {rms:.3f}  {os.path.getsize(path):>7d} B"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
