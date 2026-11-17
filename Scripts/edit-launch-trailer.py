#!/usr/bin/env python3
"""Trim chronological keep spans from one capture and optionally mix one score."""

import argparse
import json
import math
import re
from pathlib import Path
import subprocess

from LaunchTrailer.cadence import measure, sample_action
from LaunchTrailer.treatment import compose


def probe(path):
    result = subprocess.run(
        ["ffprobe", "-v", "error", "-show_format", "-show_streams", "-of", "json", str(path)],
        check=True, capture_output=True, text=True,
    )
    return json.loads(result.stdout)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", required=True, type=Path)
    parser.add_argument("--timeline", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--soundtrack", type=Path)
    parser.add_argument("--music-offset", type=float, default=0)
    parser.add_argument("--keep-source-audio", action="store_true")
    parser.add_argument("--clean-picture", action="store_true", help="Use the same cuts without camera or light effects.")
    parser.add_argument("--crop", help="Measured game viewport as width:height:x:y")
    parser.add_argument("--fps", type=int, choices=[30, 60], default=60)
    parser.add_argument("--videotoolbox", action="store_true", help="Use the Mac hardware codec for the 60 fps press master.")
    parser.add_argument("--app-store", action="store_true", help="Export the iPhone 14 Pro 886x1920 preview at 30 fps.")
    parser.add_argument("--motion-span", type=float, nargs=2, action="append", default=[], metavar=("START", "END"),
                        help="Source seconds spanning continuous motion during combat; repeat for two distinct actions.")
    args = parser.parse_args()
    fps = 30 if args.app_store else args.fps
    if args.videotoolbox and (args.app_store or fps != 60):
        parser.error("VideoToolbox is available for the 60 fps press master.")
    cue_path = args.output.with_suffix(".cues.json")
    if args.output.exists() or cue_path.exists():
        parser.error("Output or cue map already exists. Choose a new output name.")
    if not math.isfinite(args.music_offset) or args.music_offset < 0:
        parser.error("Music offset must be finite and nonnegative.")
    source = probe(args.source)
    video = next(stream for stream in source["streams"] if stream["codec_type"] == "video")
    duration = float(source["format"]["duration"])
    shots = json.loads(args.timeline.read_text())["shots"]
    if not shots:
        parser.error("The timeline needs at least one shot.")
    if args.keep_source_audio and not any(s["codec_type"] == "audio" for s in source["streams"]):
        parser.error("The capture has no audio stream.")
    if args.soundtrack:
        music = probe(args.soundtrack)
        if not any(s["codec_type"] == "audio" for s in music["streams"]):
            parser.error("The soundtrack has no audio stream.")
        if args.music_offset >= float(music["format"]["duration"]):
            parser.error("Music offset exceeds the soundtrack duration.")
    crop = "null"
    width, height = video.get("width"), video.get("height")
    if args.crop:
        try:
            width, height, x, y = [int(value) for value in args.crop.split(":")]
        except ValueError:
            parser.error("Crop must contain four integers as width:height:x:y.")
        if min(width, height) <= 0 or min(x, y) < 0:
            parser.error("Crop dimensions must be positive and its origin nonnegative.")
        if x + width > video["width"] or y + height > video["height"]:
            parser.error("Crop exceeds the captured video bounds.")
        crop = f"crop={width}:{height}:{x}:{y}"
    filters = []
    inputs = []
    frame_ranges = []
    cue_map = []
    previous_end = 0
    output_time = 0
    for index, shot in enumerate(shots):
        start, end = float(shot["start"]), float(shot["end"])
        if not all(math.isfinite(value) for value in (start, end)):
            parser.error("Shot times must be finite.")
        if start < previous_end or end <= start or end > duration:
            parser.error(f"Invalid or overlapping source range for shot {index}.")
        # Quantize the cut boundaries on one output clock. iOS may hold a
        # single source frame across an entire menu shot.
        first_frame = round(start * fps)
        count = round((output_time + end - start) * fps) - round(output_time * fps)
        if count < 1:
            parser.error(f"Shot {index} is shorter than one output frame.")
        frame_ranges.append(f"between(n,{first_frame},{first_frame + count - 1})")
        if args.keep_source_audio:
            filters.append(
                f"[0:a]atrim=start={start}:end={end},asetpts=PTS-STARTPTS,"
                f"aresample=48000,aformat=channel_layouts=stereo[a{index}]"
            )
            inputs.append(f"[a{index}]")
        length = end - start
        cue_map.append({
            "id": shot["id"], "source_start": start, "source_end": end,
            "output_start": output_time, "output_end": output_time + length,
        })
        if shot.get("effects") and not args.clean_picture:
            cue_map[-1]["effects"] = shot["effects"]
        if args.soundtrack and shot.get("sounds"):
            if args.keep_source_audio:
                parser.error("Choose captured audio or synchronized sound cues for the score.")
            cue_map[-1]["sounds"] = shot["sounds"]
        output_time += length
        previous_end = end
    motion = []
    if fps == 60:
        actions = [s for s in cue_map if s["id"].startswith("boss-play-")]
        if len(actions) < 2:
            parser.error("A 60 fps trailer needs at least two retained boss actions.")
        if args.motion_span and len(args.motion_span) != len(actions):
            parser.error("Supply one motion sample per retained boss action, or let the editor find them.")
        for index, action in enumerate(actions):
            if args.motion_span:
                start, end = args.motion_span[index]
                if not action["source_start"] <= start < end <= action["source_end"]:
                    parser.error(f"Motion sample must lie within {action['id']}.")
                observation = measure(args.source, start, end)
            else:
                observation = sample_action(args.source, action["source_start"], action["source_end"])
            motion.append({"shot": action["id"], **observation})
            if not observation["passed"]:
                parser.error(f"Source motion falls short of the 60 fps target: {observation}")
    if args.app_store and (not 15 <= output_time <= 30 or not (args.soundtrack or args.keep_source_audio)):
        parser.error("The iPhone App Store preview requires 15–30 seconds and stereo audio.")
    if args.keep_source_audio:
        filters.append("".join(inputs) + f"concat=n={len(shots)}:v=0:a=1[effects]")
    selected = "+".join(frame_ranges)
    filters.append(f"[0:v]fps={fps}:start_time=0,select='{selected}',setpts=N/({fps}*TB)[picture]")
    geometry = ("scale=886:1920:force_original_aspect_ratio=decrease:force_divisible_by=2,"
                "pad=886:1920:(ow-iw)/2:(oh-ih)/2,setsar=1" if args.app_store
                else "pad=ceil(iw/2)*2:ceil(ih/2)*2")
    filters.append(f"[picture]{crop}[viewport]")
    try:
        treated = compose(filters, cue_map, fps, width, height)
    except (KeyError, ValueError, TypeError) as error:
        parser.error(f"Invalid trailer treatment: {error}")
    filters.append(f"[{treated}]{geometry},format=yuv420p[video]")
    command = ["ffmpeg", "-hide_banner", "-loglevel", "error", "-n", "-threads", "2", "-filter_complex_threads", "2"]
    if args.videotoolbox:
        command += ["-hwaccel", "videotoolbox"]
    command += ["-i", str(args.source)]
    audio_label = None
    if args.soundtrack:
        if args.music_offset + output_time > float(music["format"]["duration"]):
            parser.error("The selected musical passage must cover the entire edit.")
        command += ["-ss", str(args.music_offset), "-i", str(args.soundtrack)]
        fade_start = max(0, output_time - 0.6)
        filters.append(
            f"[1:a]atrim=duration={output_time},asetpts=PTS-STARTPTS,"
            f"aresample=48000,aformat=channel_layouts=stereo,"
            f"afade=t=in:d=0.08,afade=t=out:st={fade_start}:d=0.6[score]"
        )
        if args.keep_source_audio:
            filters.append("[score]volume=0.3[bed]")
            filters.append("[effects][bed]amix=inputs=2:duration=longest:normalize=0[mix]")
            filters.append("[mix]loudnorm=I=-16:TP=-1.5:LRA=11,volume=-1dB[audio]")
        else:
            tracks = ["[score]"]
            for shot in cue_map:
                for sound in shot.get("sounds", []):
                    name = sound["id"]
                    at = float(sound["at"])
                    gain = float(sound["gain_db"])
                    if (not re.fullmatch(r"[a-z0-9_]+", name) or not -30 <= gain <= 12
                            or not 0 <= at < shot["output_end"] - shot["output_start"]):
                        parser.error(f"Invalid synchronized sound on {shot['id']}.")
                    asset = Path(__file__).resolve().parents[1] / "Trinket/Media/SFX" / f"sfx_{name}.m4a"
                    if not asset.is_file():
                        parser.error(f"Missing game sound {name}.")
                    command += ["-i", str(asset)]
                    label = f"[hit{len(tracks)}]"
                    delay = round((shot["output_start"] + at) * 48000)
                    filters.append(f"[{len(tracks) + 1}:a]aresample=48000,aformat=channel_layouts=stereo,"
                                   f"volume={gain}dB,adelay={delay}S:all=1{label}")
                    tracks.append(label)
            bed = tracks[0]
            if len(tracks) > 1:
                filters.append("".join(tracks) + f"amix=inputs={len(tracks)}:duration=first:normalize=0[scored]")
                bed = "[scored]"
            filters.append(bed + "loudnorm=I=-16:TP=-1.5:LRA=11,volume=-1dB[audio]")
        audio_label = "[audio]"
    elif args.keep_source_audio:
        filters.append("[effects]loudnorm=I=-16:TP=-1.5:LRA=11,volume=-1dB[audio]")
        audio_label = "[audio]"
    command += ["-filter_complex", ";".join(filters), "-map", "[video]"]
    if audio_label:
        command += ["-map", audio_label, "-c:a", "aac", "-b:a", "256k", "-ar", "48000", "-ac", "2"]
    quality = (["-profile:v", "high", "-level:v", "4.0", "-b:v", "11M", "-minrate", "11M", "-maxrate", "11M",
                "-bufsize", "22M", "-x264-params", "nal-hrd=cbr"]
               if args.app_store else ["-crf", "18"])
    if args.videotoolbox:
        command += ["-c:v", "h264_videotoolbox", "-profile:v", "high", "-b:v", "28M"]
    else:
        command += ["-c:v", "libx264", "-threads", "3", "-preset", "medium", *quality]
    command += ["-movflags", "+faststart", "-t", str(output_time), str(args.output)]
    args.output.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(command, check=True)
    result = probe(args.output)
    actual_duration = float(result["format"]["duration"])
    picture = next(stream for stream in result["streams"] if stream["codec_type"] == "video")
    if int(picture["nb_frames"]) != round(output_time * fps):
        raise RuntimeError(f"Exported {picture['nb_frames']} picture frames, expected {round(output_time * fps)}")
    if abs(actual_duration - output_time) > 1.5 / fps:
        raise RuntimeError(f"Export duration differs from cue map: {actual_duration} versus {output_time}")
    cue_path.write_text(json.dumps({
        "source": str(args.source.resolve()), "timeline": str(args.timeline.resolve()),
        "soundtrack": str(args.soundtrack.resolve()) if args.soundtrack else None,
        "music_offset": args.music_offset, "source_audio_kept": args.keep_source_audio,
        "duration": actual_duration, "fps": fps, "source_motion": motion, "shots": cue_map, "command": command,
    }, indent=2) + "\n")
    print(f"Exported {actual_duration:.2f}s to {args.output}")
    print(f"Cue map: {cue_path}")


if __name__ == "__main__":
    main()
