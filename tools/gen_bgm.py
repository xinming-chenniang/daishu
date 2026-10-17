#!/usr/bin/env python3
"""生成《代书》的两段循环 BGM（程序化合成，无第三方素材，授权干净）。

为什么程序化：仓库要自洽 —— 不引入来源不明 / 需署名 / 体积大的音乐；两段曲子都是
"古琴/筝的拨弦 + 低频持续音"，用 Karplus-Strong 拨弦合成器 + 简单延迟混响就能做到，
参数即文档，改一版气氛不用找素材。

产物（16-bit 单声道 22.05 kHz WAV，**首尾交叉淡化，可无缝循环**）：
  assets/audio/bgm/bgm_title.wav    标题 / 主界面：D 宫五声，稀疏拨弦 + 低音持续
  assets/audio/bgm/bgm_letter.wav   代写界面：更慢更轻，长音为主（不抢读信的注意力）

用法：
  python tools/gen_bgm.py
  python tools/gen_bgm.py --out <目录>

依赖：numpy（DSH 运行时自带）。不依赖 scipy。
"""

from __future__ import annotations

import argparse
import math
import os
import wave

import numpy as np

SR = 22050
LOOP_SEC = 24.0


# ---------------- 基础工具 ----------------

def _t(dur: float) -> np.ndarray:
    return np.arange(int(SR * dur), dtype=np.float64) / SR


def _lowpass(x: np.ndarray, cutoff: float) -> np.ndarray:
    a = math.exp(-2.0 * math.pi * cutoff / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1.0 - a) * v + a * acc
        y[i] = acc
    return y


def _normalize(x: np.ndarray, peak: float = 0.35) -> np.ndarray:
    m = float(np.max(np.abs(x))) if x.size else 0.0
    return x if m <= 0 else x * (peak / m)


def _loop_crossfade(x: np.ndarray, fade_sec: float = 0.8) -> np.ndarray:
    """把尾巴叠到头上，得到可无缝循环的片段（长度缩短 fade_sec）。"""
    n = min(int(SR * fade_sec), x.size // 4)
    if n <= 0:
        return x
    ramp = np.linspace(0.0, 1.0, n)
    head = x[:n] * ramp
    tail = x[-n:] * (1.0 - ramp)
    out = x[:-n].copy()
    out[:n] += tail
    out[:n] += head * 0.0  # 头部本身保留在 out 里（ramp 已把它压低），避免重复叠加
    return out


# ---------------- 拨弦合成（Karplus-Strong） ----------------

def pluck(freq: float, dur: float, rng: np.random.Generator,
          damp: float = 0.9965, brightness: float = 0.55) -> np.ndarray:
    """一根弦的拨奏：噪声激励 + 延迟线低通反馈，音色介于古琴与筝之间。"""
    n = max(2, int(round(SR / freq)))
    exc = rng.uniform(-1.0, 1.0, n)
    # 激励本身先低通一次：去掉最刺耳的高频，更像"指肉拨弦"
    exc = _lowpass(exc, 4500.0)
    buf = exc.copy()

    total = int(SR * dur)
    out = np.zeros(total)
    for i in range(total):
        v = buf[i % n]
        nxt = buf[(i + 1) % n]
        out[i] = v
        buf[i % n] = damp * (brightness * v + (1.0 - brightness) * nxt)

    # 尾部衰减包络：保证到 dur 结束前一定归零，避免拼接咔哒
    t = np.arange(total) / SR
    env = np.exp(-t / (dur * 0.45))
    env *= np.clip((dur - t) / (dur * 0.15), 0.0, 1.0)
    return out * env


# ---------------- 混响（简易多抽头延迟） ----------------

def add_reverb(x: np.ndarray, taps=((0.11, 0.28), (0.19, 0.20), (0.29, 0.13))) -> np.ndarray:
    y = x.copy()
    for delay_sec, gain in taps:
        d = int(SR * delay_sec)
        if d <= 0 or d >= x.size:
            continue
        y[d:] += gain * x[:-d]
    return y


# ---------------- 作曲 ----------------

# D 宫五声：D E F# A B（频率取中音区，按需上下移八度）
PENTA = [146.83, 164.81, 185.00, 220.00, 246.94, 293.66, 329.63, 369.99, 440.00, 493.88]


def compose_title(rng: np.random.Generator) -> np.ndarray:
    buf = np.zeros(int(SR * LOOP_SEC))

    # 低频持续音：D2 + A2，缓慢呼吸
    t = _t(LOOP_SEC)
    drone = 0.11 * np.sin(2 * math.pi * 73.42 * t) + 0.06 * np.sin(2 * math.pi * 110.0 * t)
    drone *= 0.85 + 0.15 * np.sin(2 * math.pi * 0.083 * t)
    buf += drone

    # 稀疏旋律：每 1.4–2.4 秒一个音，长度 2–4 秒，互相叠出"留白"
    rng_pos = 1.0
    while rng_pos < LOOP_SEC - 3.0:
        freq = PENTA[int(rng.integers(0, len(PENTA)))]
        dur = float(rng.uniform(2.0, 4.0))
        amp = float(rng.uniform(0.16, 0.30))
        note = pluck(freq, dur, rng) * amp
        start = int(rng_pos * SR)
        end = min(start + note.size, buf.size)
        buf[start:end] += note[: end - start]
        rng_pos += float(rng.uniform(1.4, 2.4))

    # 偶尔一个低八度的应答
    for at in (6.5, 15.0):
        note = pluck(PENTA[0] * 0.5, 5.0, rng) * 0.18
        s = int(at * SR)
        e = min(s + note.size, buf.size)
        buf[s:e] += note[: e - s]

    buf = add_reverb(buf)
    buf = _lowpass(buf, 7000.0)
    return _normalize(_loop_crossfade(buf), 0.30)


def compose_letter(rng: np.random.Generator) -> np.ndarray:
    buf = np.zeros(int(SR * LOOP_SEC))

    t = _t(LOOP_SEC)
    # 更低的持续音，音量再压一档（这是背景，玩家在读字）
    drone = 0.08 * np.sin(2 * math.pi * 73.42 * t) + 0.04 * np.sin(2 * math.pi * 146.83 * t)
    drone *= 0.9 + 0.1 * np.sin(2 * math.pi * 0.05 * t)
    buf += drone

    rng_pos = 2.0
    while rng_pos < LOOP_SEC - 3.0:
        freq = PENTA[int(rng.integers(0, 6))]  # 只用低六度，音区更沉
        dur = float(rng.uniform(3.0, 5.0))
        amp = float(rng.uniform(0.10, 0.18))
        note = pluck(freq, dur, rng, damp=0.9975, brightness=0.45) * amp
        start = int(rng_pos * SR)
        end = min(start + note.size, buf.size)
        buf[start:end] += note[: end - start]
        rng_pos += float(rng.uniform(2.6, 4.0))

    buf = add_reverb(buf, taps=((0.15, 0.22), (0.27, 0.14)))
    buf = _lowpass(buf, 5000.0)
    return _normalize(_loop_crossfade(buf), 0.22)


TRACKS = {"bgm_title": compose_title, "bgm_letter": compose_letter}


def write_wav(path: str, x: np.ndarray) -> None:
    pcm = (np.clip(x, -1.0, 1.0) * 32767.0).astype("<i2")
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    with wave.open(path, "wb") as fh:
        fh.setnchannels(1)
        fh.setsampwidth(2)
        fh.setframerate(SR)
        fh.writeframes(pcm.tobytes())


def main() -> int:
    here = os.path.dirname(os.path.abspath(__file__))
    default_out = os.path.join(os.path.dirname(here), "assets", "audio", "bgm")
    ap = argparse.ArgumentParser(description="生成《代书》循环 BGM")
    ap.add_argument("--out", default=default_out)
    args = ap.parse_args()

    rng = np.random.default_rng(20261018)
    print(f"输出目录：{args.out}  （采样率 {SR} Hz，循环 {LOOP_SEC:.0f}s）")
    for name, fn in TRACKS.items():
        x = fn(rng)
        path = os.path.join(args.out, f"{name}.wav")
        write_wav(path, x)
        print(
            f"  {name:<12} {x.size / SR:5.1f} s  peak {float(np.max(np.abs(x))):.2f}  "
            f"rms {float(np.sqrt(np.mean(x ** 2))):.3f}  {os.path.getsize(path):>9d} B"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
