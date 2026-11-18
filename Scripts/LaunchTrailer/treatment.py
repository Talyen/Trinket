"""Build frame-timed camera moves and feathered light masks on the cropped game picture."""
import math


def checked(value, low, high):
    value = float(value)
    if not math.isfinite(value) or not low <= value <= high:
        raise ValueError(f"Expected a number in [{low}, {high}], received {value}")
    return value


def compose(filters, shots, fps, width, height):
    """Times are local to the shot. All geometry is relative to the game viewport."""
    picture = "viewport"
    masks = []
    pushes = []
    camera_windows = []

    for shot in shots:
        start = round(shot["output_start"] * fps)
        stop = round(shot["output_end"] * fps)
        for effect in shot.get("effects", []):
            kind = effect["type"]
            begin = start + round(checked(effect["from"], 0, (stop - start + 0.5) / fps) * fps)
            end = start + round(checked(effect["to"], 0, (stop - start + 0.5) / fps) * fps)
            if not start <= begin < end <= stop or end - begin < 2:
                raise ValueError(f"Invalid effect interval on {shot['id']}")
            if kind == "push":
                x, y = [checked(v, 0, 1) for v in effect["center"]]
                zoom = checked(effect["zoom"], 1, 1.5)
                # The full frame eases toward the subject, then holds through the cut.
                ramp = f"clip((on-1-{begin})/{end - begin - 1},0,1)"
                amount = f"between(on-1,{begin},{stop - 1})*{1 - 1 / zoom:.8f}*(0.5-0.5*cos(PI*{ramp}))"
                pushes.append((x, y, amount))
                camera_windows.append(f"between(n,{begin},{stop - 1})")
            elif kind in {"focus", "dip"}:
                strength = checked(effect["strength"], 0, 1)
                alpha = f"{255 * strength:.4f}"
                if kind == "focus":
                    x, y = [checked(v, 0, 1) for v in effect["center"]]
                    rx, ry = [checked(v, 0.01, 1) for v in effect["radius"]]
                    distance = f"hypot((X/W-{x})/{rx},(Y/H-{y})/{ry})"
                    alpha += f"*clip(({distance}-0.72)/0.72,0,1)"
                masks.append((begin, end, alpha, kind))
            else:
                raise ValueError(f"Unknown trailer effect {kind!r}")

    if pushes:
        # One subpixel transform keeps text and UI edges steady during the move.
        def edge(axis, far):
            size = "WH"[axis]
            offset = "+".join(f"{(point[axis] - int(far)):.6f}*({point[2]})" for point in pushes)
            return f"'{size}*({int(far)}+{offset})'"

        corners = ":".join(f"x{i}={edge(0, i % 2 == 1)}:y{i}={edge(1, i >= 2)}" for i in range(4))
        active = "+".join(camera_windows)
        filters.append(f"[{picture}]perspective={corners}:eval=frame:interpolation=cubic:enable='{active}'[camera]")
        picture = "camera"

    for index, (begin, end, alpha, kind) in enumerate(masks):
        count = end - begin
        ramp = max(1, min(count // 2, round(fps * 0.22)))
        # A small, fixed matte gives a soft edge without recalculating distances
        # at phone resolution. Fade the alpha only, leaving the artwork in full color.
        matte = (f"nullsrc=s=96x192:r={fps},trim=end_frame=1,format=yuva444p,"
                 f"geq=lum=16:cb=128:cr=128:a='{alpha}',loop=loop={count - 1}:size=1:start=0,"
                 f"setpts=N/({fps}*TB),fade=t=in:s=0:n={ramp}:alpha=1")
        if kind == "focus":
            matte += f",fade=t=out:s={count - ramp - 1}:n={ramp}:alpha=1"
        filters.append(f"{matte},scale={width}:{height}:flags=bilinear,setpts=PTS+{begin}/({fps}*TB)[matte{index}]")
        filters.append(f"[{picture}][matte{index}]overlay=eof_action=pass:repeatlast=0[lit{index}]")
        picture = f"lit{index}"
    return picture


def compose_transitions(filters, picture, shots, fps, width, height):
    """Cover a cut with an angled matte while both game shots run at their original speed."""
    for index, shot in enumerate(shots):
        if "transition" not in shot:
            continue
        half = round(checked(shot["transition"], 0.15, 0.5) * fps / 2)
        cut = round(shot["output_start"] * fps)
        end = round(shot["output_end"] * fps)
        if index == 0 or half * 2 >= end - cut:
            raise ValueError(f"Transition needs a preceding shot and room on both sides of {shot['id']}.")
        if half * 2 >= cut - round(shots[index - 1]["output_start"] * fps):
            raise ValueError(f"Transition is too long for the shot before {shot['id']}.")
        # The slanted band fully covers the frame at the cut. Its rim is
        # feathered and warm to echo the game's gold UI accents.
        progress = f"(0.5-0.5*cos(PI*N/{2 * half}))"
        band_position = f"(X/W+0.18*(Y/H-0.5)-1.24+2.88*{progress})"
        distance = f"min({band_position},1.44-{band_position})"
        alpha = f"255*clip({distance}/0.042,0,1)"
        rim = f"1-clip(abs({distance}-0.021)/0.050,0,1)"
        mask = f"wipe{index}"
        output = f"transition{index}"
        filters.append(
            f"nullsrc=s=128x256:r={fps},trim=end_frame={2 * half + 1},format=yuva444p,"
            f"geq=lum='20+90*({rim})':cb='128-28*({rim})':cr='128+24*({rim})':a='{alpha}',"
            f"scale={width}:{height}:flags=bilinear,setpts=PTS+{cut - half}/({fps}*TB)[{mask}]"
        )
        filters.append(f"[{picture}][{mask}]overlay=eof_action=pass:repeatlast=0[{output}]")
        picture = output
    return picture


def compose_dissolves(command, filters, picture, shots, source, crop, fps):
    """Blend the incoming source frames over the outgoing tail without pausing either shot."""
    for index, shot in enumerate(shots):
        count = round(shot.get("dissolve", 0) * fps)
        if not count:
            continue
        first = round(shot["source_start"] * fps)
        offset = round(shot["output_start"] * fps)
        # Seek on the same integer-second grid as the primary decoder. Leave
        # preroll for a held frame to resolve before selecting the exact head.
        seek = max(0, first // fps - 1)
        local = first - seek * fps
        input_index = command.count("-i")
        command += ["-threads", "1", "-ss", str(seek),
                    "-t", str((local + count + 1) / fps), "-i", str(source)]
        head = f"head{index}"
        output = f"dissolved{index}"
        filters.append(
            f"[{input_index}:v]fps={fps}:start_time=0,trim=start_frame={local}:end_frame={local + count},"
            f"{crop},format=yuva420p,setpts=N/({fps}*TB),"
            f"fade=t=in:s=0:n={count - 1}:alpha=1,setpts=PTS+{offset}/({fps}*TB)[{head}]"
        )
        filters.append(f"[{picture}][{head}]overlay=eof_action=pass:repeatlast=0[{output}]")
        picture = output
    return picture
