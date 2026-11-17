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
