#!/usr/bin/env python3
"""FlowDo 効果音を生成する（assets/sounds/ へ出力）"""

from __future__ import annotations

import math
import random
import struct
import wave
from pathlib import Path

SAMPLE_RATE = 44100
OUT_DIR = Path(__file__).resolve().parent.parent / "assets" / "sounds"


def write_wav(path: Path, samples: list[float]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SAMPLE_RATE)
        frames = b"".join(
            struct.pack("<h", max(-32767, min(32767, int(s)))) for s in samples
        )
        w.writeframes(frames)


def envelope(t: float, attack: float, decay: float, duration: float) -> float:
    if t < 0:
        return 0.0
    if t < attack:
        return t / attack if attack > 0 else 1.0
    if t > duration:
        return 0.0
    return math.exp(-(t - attack) * decay)


def pink_noise() -> float:
    # 簡易ピンクノイズ（木・紙の質感用）
    return sum(random.uniform(-1, 1) for _ in range(3)) / 3


def wood_tap(duration: float = 0.038, volume: float = 0.28) -> list[float]:
    """短く控えめな「コッ」— 木を軽く叩くイメージ"""
    n = int(SAMPLE_RATE * duration)
    samples: list[float] = []
    for i in range(n):
        t = i / SAMPLE_RATE
        env = envelope(t, 0.0015, 110, duration)
        body = math.sin(2 * math.pi * 210 * t) * 0.55
        body += math.sin(2 * math.pi * 420 * t) * 0.12
        click = math.sin(2 * math.pi * 340 * t) * math.exp(-t * 140) * 0.35
        noise = pink_noise() * math.exp(-t * 95) * 0.22
        val = volume * 32767 * env * (body + click + noise)
        samples.append(val)
    return samples


def soft_pon(
    duration: float = 0.19,
    volume: float = 0.26,
    base_freq: float = 392,
) -> list[float]:
    """旧版「ポン♪」（参考用）"""
    n = int(SAMPLE_RATE * duration)
    samples: list[float] = []
    for i in range(n):
        t = i / SAMPLE_RATE
        env = envelope(t, 0.006, 16, duration)
        freq = base_freq * (1 - 0.06 * min(t / duration, 1.0))
        tone = math.sin(2 * math.pi * freq * t) * 0.72
        tone += math.sin(2 * math.pi * freq * 2 * t) * 0.08
        tone += math.sin(2 * math.pi * freq * 3 * t) * 0.03
        samples.append(volume * 32767 * env * tone)
    return samples


def _mix_note(
    samples: list[float],
    *,
    freq: float,
    start: float,
    duration: float,
    volume: float,
    attack: float = 0.004,
    decay: float = 22,
    harmonics: tuple[tuple[float, float], ...] = ((1.0, 0.78), (2.0, 0.06), (3.0, 0.02)),
) -> None:
    start_i = int(start * SAMPLE_RATE)
    end_i = min(len(samples), int((start + duration) * SAMPLE_RATE))
    for i in range(start_i, end_i):
        t = i / SAMPLE_RATE - start
        env = envelope(t, attack, decay, duration)
        tone = sum(
            math.sin(2 * math.pi * freq * ratio * t) * amp
            for ratio, amp in harmonics
        )
        samples[i] += volume * 32767 * env * tone


def completion_poron_a(volume: float = 0.33) -> list[float]:
    """A案：ポロン♪ — 2音の柔らかい達成感"""
    total = 0.36
    samples = [0.0] * int(SAMPLE_RATE * total)
    _mix_note(samples, freq=784, start=0.0, duration=0.15, volume=volume * 0.95)
    _mix_note(samples, freq=659.25, start=0.085, duration=0.24, volume=volume)
    return samples


def completion_tin_b(volume: float = 0.31) -> list[float]:
    """B案：ティン♪ — 澄んだベル"""
    duration = 0.30
    freq = 880.0
    n = int(SAMPLE_RATE * duration)
    samples: list[float] = []
    for i in range(n):
        t = i / SAMPLE_RATE
        env = envelope(t, 0.002, 11, duration)
        shimmer = 1 + 0.0035 * math.sin(2 * math.pi * 6.5 * t)
        f = freq * shimmer
        tone = math.sin(2 * math.pi * f * t) * 0.52
        tone += math.sin(2 * math.pi * f * 2.76 * t) * 0.30
        tone += math.sin(2 * math.pi * f * 5.4 * t) * 0.11
        tone += math.sin(2 * math.pi * f * 8.1 * t) * 0.04
        samples.append(volume * 32767 * env * tone)
    return samples


def completion_marimba_c(volume: float = 0.34) -> list[float]:
    """C案：マリンバ — 温かい木琴"""
    duration = 0.36
    freq = 523.25
    random.seed(7)
    n = int(SAMPLE_RATE * duration)
    samples: list[float] = []
    for i in range(n):
        t = i / SAMPLE_RATE
        body_env = envelope(t, 0.0012, 13.5, duration)
        strike = pink_noise() * math.exp(-t * 165) * 0.32
        tone = math.sin(2 * math.pi * freq * t) * 0.62
        tone += math.sin(2 * math.pi * freq * 3 * t) * 0.20
        tone += math.sin(2 * math.pi * freq * 5 * t) * 0.07
        tone += math.sin(2 * math.pi * freq * 7 * t) * 0.025
        samples.append(volume * 32767 * body_env * (tone + strike))
    return samples


def organize_flow(duration: float = 0.72, volume: float = 0.18) -> list[float]:
    """紙を整える・風が流れる「シャーー…」"""
    n = int(SAMPLE_RATE * duration)
    samples: list[float] = []
    random.seed(42)
    for i in range(n):
        t = i / SAMPLE_RATE
        progress = t / duration
        amp_env = math.sin(math.pi * progress) ** 1.4
        center = 600 + 1400 * progress
        noise = pink_noise()
        tone = math.sin(2 * math.pi * center * t * 0.015) * 0.08
        val = volume * 32767 * amp_env * (noise * 0.85 + tone)
        samples.append(val)
    return samples


def main() -> None:
    write_wav(OUT_DIR / "task_registered.wav", wood_tap())
    # 本番: A案「ポロン♪」
    write_wav(OUT_DIR / "task_completed.wav", completion_poron_a())
    write_wav(OUT_DIR / "task_completed_a.wav", completion_poron_a())
    # 開発用候補（アプリからは未参照）
    write_wav(OUT_DIR / "task_completed_b.wav", completion_tin_b())
    write_wav(OUT_DIR / "task_completed_c.wav", completion_marimba_c())
    write_wav(OUT_DIR / "task_organize_flow.wav", organize_flow())
    print("Generated:", ", ".join(p.name for p in sorted(OUT_DIR.glob("*.wav"))))


if __name__ == "__main__":
    main()
