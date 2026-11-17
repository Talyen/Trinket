"""Measure motion in a short, continuously animated region of the unedited take."""
import json
import math
import re
import statistics
import subprocess


def summarize(frames):
    if len(frames) < 3:
        raise ValueError("Need three or more decoded frames to measure cadence.")
    times = [frame[0] for frame in frames]
    # Ignore the first frame, for which signalstats has no predecessor.
    changes = [t for t, difference in frames[1:] if difference >= 0.15]
    elapsed = times[-1] - times[0]
    if elapsed <= 0:
        raise ValueError("Invalid timestamps in the source.")
    holds = sorted(b - a for a, b in zip([times[0], *changes], [*changes, times[-1]]))
    rate = len(changes) / elapsed
    return {"sample_seconds": elapsed, "decoded_fps": (len(times) - 1) / elapsed,
            "visibly_changed_fps": rate, "median_interval_ms": statistics.median(holds) * 1000,
            "p95_interval_ms": holds[math.ceil(0.95 * len(holds)) - 1] * 1000,
            "longest_hold_ms": max(holds) * 1000,
            "passed": elapsed >= 0.4 and rate >= 54 and max(holds) <= 0.0501}


def read_frames(path, start, end):
    if not all(map(math.isfinite, (start, end))) or start < 0 or end - start < 0.45:
        raise ValueError("Select at least 0.45s of continuous visible motion.")
    # Measure picture changes in the game area, excluding clock and home indicator.
    vf = ("crop=iw:ih*0.85:0:ih*0.075,scale=320:-2:flags=area,format=yuv420p,"
          "signalstats,metadata=mode=print:key=lavfi.signalstats.YDIF:file=-")
    data = subprocess.check_output(["ffmpeg", "-nostats", "-v", "error", "-ss", str(start), "-i", str(path),
                                    "-t", str(end - start), "-an", "-vf", vf, "-fps_mode", "passthrough",
                                    "-f", "null", "-"], text=True)
    pairs = re.findall(r"pts_time:([\d.e+-]+)[^\n]*\nlavfi\.signalstats\.YDIF=([\d.e+-]+)", data)
    return [(float(t), float(d)) for t, d in pairs if 0 <= float(t) < end - start]


def measure(path, start, end):
    return {"start": start, "end": end, **summarize(read_frames(path, start, end))}


def sample_action(path, start, end):
    frames = read_frames(path, start, end)
    length = 0.85
    candidates = []
    for t, _ in frames:
        if t < 0.05 or t + length >= end - start:
            continue
        window = [frame for frame in frames if t <= frame[0] < t + length]
        if len(window) >= 3:
            stats = summarize(window)
            candidates.append((stats["visibly_changed_fps"], -stats["longest_hold_ms"], t))
    if not candidates:
        raise ValueError("Too few samples in the moving boss action.")
    offset = max(candidates)[2]
    sample = measure(path, start + offset, start + offset + length)
    return {**sample, "whole_action": summarize(frames)}


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source")
    parser.add_argument("start", type=float)
    parser.add_argument("end", type=float)
    args = parser.parse_args()
    print(json.dumps(measure(args.source, args.start, args.end), indent=2))
