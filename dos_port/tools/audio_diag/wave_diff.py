#!/usr/bin/env python3
"""wave_diff.py — compare a suspect render against a clean reference.

Shared helper for the dos-gb-audio-debugger hunters (same pattern as
jev_ask.sh): hunters RUN this, they never write analysis code of their own.

Usage:
  wave_diff.py OURS.wav REF.wav [--scope NAME] [--out DIR] [--min-drop SEC]

Method: parse both WAVs (PCM16 or FLOAT32, any rate), resample to a common
rate, align by cross-correlating RMS envelopes, then report (a) dropout
ranges where the reference is active but ours is quiet, with timestamps,
and (b) one-second blocks where ours carries excess high-frequency energy
vs the reference (static/rasp). Never bit-equality: level/timbre differences
between render paths are expected and ignored.

Race safety: all outputs go under --out (default /tmp/opencode/<scope>),
so parallel hunters never share a path. Requires numpy (present on host).
Exit 0 on success, 2 on argument/file errors.
"""

import argparse
import json
import os
import struct
import sys

try:
    import numpy as np
except ImportError:
    print("wave_diff.py: numpy is required", file=sys.stderr)
    sys.exit(2)


def read_wav(path):
    """Return (mono float64 array, sample rate). Handles PCM16 + FLOAT32."""
    try:
        with open(path, "rb") as f:
            raw = f.read()
    except OSError as e:
        print(f"wave_diff.py: cannot read {path}: {e}", file=sys.stderr)
        sys.exit(2)
    if raw[0:4] != b"RIFF" or raw[8:12] != b"WAVE":
        print(f"wave_diff.py: not a RIFF/WAVE file: {path}", file=sys.stderr)
        sys.exit(2)
    fmt = None
    data = None
    pos = 12
    while pos + 8 <= len(raw):
        tag, size = struct.unpack("<4sI", raw[pos:pos + 8])
        chunk = raw[pos + 8:pos + 8 + size]
        if tag == b"fmt ":
            (wformat, channels, rate, _, _, bits) = struct.unpack(
                "<HHIIHH", chunk[:16])
            fmt = (wformat, channels, rate, bits)
        elif tag == b"data":
            data = chunk
        pos += 8 + size + (size & 1)
    if fmt is None or data is None:
        print(f"wave_diff.py: missing fmt/data chunk: {path}",
              file=sys.stderr)
        sys.exit(2)
    wformat, channels, rate, bits = fmt
    if wformat == 1 and bits == 16:
        samples = np.frombuffer(data, dtype=np.int16).astype(np.float64)
        samples /= 32768.0
    elif wformat == 3 and bits == 32:
        samples = np.frombuffer(data, dtype=np.float32).astype(np.float64)
    else:
        print(f"wave_diff.py: unsupported format={wformat} bits={bits}: "
              f"{path}", file=sys.stderr)
        sys.exit(2)
    n = (len(samples) // channels) * channels
    mono = samples[:n].reshape(-1, channels).mean(axis=1)
    return mono, rate


def resample_to(x, src_rate, dst_rate):
    if src_rate == dst_rate:
        return x
    n_out = int(round(len(x) * dst_rate / src_rate))
    old_idx = np.linspace(0, len(x) - 1, n_out)
    return np.interp(old_idx, np.arange(len(x)), x).astype(np.float64)


def rms_envelope(x, win=2048, hop=1024):
    n = 1 + max(0, (len(x) - win) // hop)
    if n <= 0:
        return np.array([np.sqrt(np.mean(x ** 2))])
    idx = (np.arange(n) * hop)[:, None] + np.arange(win)
    frames = x[idx]
    return np.sqrt(np.mean(frames ** 2, axis=1))


def merge_ranges(flags, hop_sec, min_len=3):
    ranges = []
    start = None
    for i, flag in enumerate(flags):
        if flag and start is None:
            start = i
        elif not flag and start is not None:
            if i - start >= min_len:
                ranges.append((start * hop_sec, i * hop_sec))
            start = None
    if start is not None and len(flags) - start >= min_len:
        ranges.append((start * hop_sec, len(flags) * hop_sec))
    return [(round(a, 2), round(b, 2)) for a, b in ranges]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("ours")
    ap.add_argument("ref")
    ap.add_argument("--scope", default="run")
    ap.add_argument("--out", default=None)
    ap.add_argument("--min-drop", type=float, default=0.15)
    args = ap.parse_args()

    out_dir = args.out or os.path.join("/tmp/opencode", args.scope)
    os.makedirs(out_dir, exist_ok=True)

    ours, ours_rate = read_wav(args.ours)
    ref, ref_rate = read_wav(args.ref)
    rate = min(ours_rate, ref_rate)
    ours = resample_to(ours, ours_rate, rate)
    ref = resample_to(ref, ref_rate, rate)

    win, hop = 2048, 1024
    hop_sec = hop / rate
    ours_env = rms_envelope(ours, win, hop)
    ref_env = rms_envelope(ref, win, hop)

    # Align by envelope cross-correlation.
    corr = np.correlate(ref_env - ref_env.mean(),
                        ours_env - ours_env.mean(), mode="full")
    lag = int(np.argmax(corr)) - (len(ours_env) - 1)
    lag_sec = round(lag * hop_sec, 3)
    if lag > 0:
        ours_env = np.concatenate([np.zeros(lag), ours_env])
    elif lag < 0:
        ref_env = np.concatenate([np.zeros(-lag), ref_env])
    n = min(len(ours_env), len(ref_env))
    ours_env, ref_env = ours_env[:n], ref_env[:n]

    ref_peak = float(ref_env.max()) if n else 0.0
    min_len = max(1, int(round(args.min_drop / hop_sec)))
    dropouts = []
    if ref_peak > 0:
        ref_active = ref_env > 0.05 * ref_peak
        ours_quiet = ours_env < 0.03 * ref_peak
        dropouts = merge_ranges(ref_active & ours_quiet, hop_sec, min_len)

    # HF excess per one-second block (first-difference energy ratio).
    blk = int(rate // hop)
    hf_blocks = []
    if ref_peak > 0 and blk > 0:
        for b in range(0, n, blk):
            o = ours_env[b:b + blk]
            r = ref_env[b:b + blk]
            if r.mean() < 0.03 * ref_peak or o.mean() < 0.03 * ref_peak:
                continue
            # Recompute HF on raw samples for this block.
            s0, s1 = b * hop, min(len(ours), len(ref), (b + len(o)) * hop)
            oh = float(np.mean(np.diff(ours[s0:s1]) ** 2) /
                       (np.mean(ours[s0:s1] ** 2) + 1e-12))
            rh = float(np.mean(np.diff(ref[s0:s1]) ** 2) /
                       (np.mean(ref[s0:s1] ** 2) + 1e-12))
            if oh > 2.0 * rh:
                hf_blocks.append({"t0": round(b * hop_sec, 2),
                                  "ours_hf": round(oh, 4),
                                  "ref_hf": round(rh, 4)})

    report = {
        "ours": args.ours,
        "ref": args.ref,
        "rate": rate,
        "align_lag_sec": lag_sec,
        "ref_peak": round(ref_peak, 4),
        "dropouts": [{"t0": a, "t1": b} for a, b in dropouts],
        "hf_excess_blocks": hf_blocks,
    }
    with open(os.path.join(out_dir, "wave_diff.json"), "w") as f:
        json.dump(report, f, indent=2)

    print(f"align_lag_sec={lag_sec} ref_peak={ref_peak:.4f}")
    if dropouts:
        print(f"dropouts={len(dropouts)}:")
        for a, b in dropouts:
            print(f"  quiet {a:.2f}s..{b:.2f}s while reference active")
    else:
        print("dropouts=0")
    if hf_blocks:
        print(f"hf_excess_blocks={len(hf_blocks)}:")
        for blk_info in hf_blocks:
            print(f"  {blk_info['t0']:.2f}s ours_hf={blk_info['ours_hf']} "
                  f"ref_hf={blk_info['ref_hf']}")
    else:
        print("hf_excess_blocks=0")
    print(f"report={out_dir}/wave_diff.json")


if __name__ == "__main__":
    main()
