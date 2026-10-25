#!/usr/bin/env python3
import json, math, re, sys
import xml.etree.ElementTree as ET

USAGE = "Usage: svg_to_lesson.py out.json in1.svg [in2.svg ...]"

NS = "{http://www.w3.org/2000/svg}"
CURVE_SAMPLES = 16
CIRCLE_SAMPLES = 72


class LessonError(Exception):
    pass


def tag(el):
    return el.tag.replace(NS, "")


def nums(text):
    return [float(n) for n in re.findall(r"-?\d*\.?\d+(?:[eE][-+]?\d+)?", text)]


def parse_path(d):
    tokens = re.findall(r"[A-DF-Za-df-z]|-?\d*\.?\d+(?:[eE][-+]?\d+)?", d)
    strokes, cur, x, y, start, cmd, i = [], None, 0.0, 0.0, (0.0, 0.0), None, 0

    def take(n):
        nonlocal i
        vals = [float(t) for t in tokens[i:i + n]]
        if len(vals) < n:
            raise LessonError(f"path ended early: {d!r}")
        i += n
        return vals

    while i < len(tokens):
        if tokens[i].isalpha():
            cmd = tokens[i]; i += 1
            if cmd.upper() not in "MLHVCZ":
                raise LessonError(f"unsupported path command {cmd!r} (convert arcs/quads to C): {d!r}")
        elif cmd is None:
            raise LessonError(f"path must start with a command: {d!r}")
        rel = cmd.islower()
        c = cmd.upper()
        if c != "M" and cur is None:
            raise LessonError(f"path has a drawing command before M: {d!r}")
        if c == "M":
            px, py = take(2)
            x, y = (x + px, y + py) if rel else (px, py)
            cur = [[x, y]]; strokes.append(cur); start = (x, y)
            cmd = "l" if rel else "L"
        elif c == "L":
            px, py = take(2)
            x, y = (x + px, y + py) if rel else (px, py)
            cur.append([x, y])
        elif c == "H":
            (px,) = take(1); x = x + px if rel else px; cur.append([x, y])
        elif c == "V":
            (py,) = take(1); y = y + py if rel else py; cur.append([x, y])
        elif c == "C":
            v = take(6)
            if rel:
                v = [v[k] + (x if k % 2 == 0 else y) for k in range(6)]
            p0, p1, p2, p3 = (x, y), v[0:2], v[2:4], v[4:6]
            for s in range(1, CURVE_SAMPLES + 1):
                t = s / CURVE_SAMPLES; u = 1 - t
                cur.append([u**3*p0[k] + 3*u*u*t*p1[k] + 3*u*t*t*p2[k] + t**3*p3[k] for k in (0, 1)])
            x, y = p3
        elif c == "Z":
            cur.append([start[0], start[1]]); x, y = start
            cmd = None
    return strokes


def shape_strokes(el):
    t = tag(el)
    if el.get("transform"):
        raise LessonError(f"<{t}> has a transform; flatten transforms in the editor before export")
    if t == "path":
        return parse_path(el.get("d", ""))
    if t in ("polyline", "polygon"):
        v = nums(el.get("points", ""))
        pts = [[v[k], v[k + 1]] for k in range(0, len(v) - 1, 2)]
        if t == "polygon" and pts:
            pts.append(pts[0])
        return [pts]
    if t == "line":
        x1, y1, x2, y2 = (float(el.get(k, "0")) for k in ("x1", "y1", "x2", "y2"))
        return [[[x1, y1], [x2, y2]]]
    if t == "circle":
        cx, cy, r = (float(el.get(k, "0")) for k in ("cx", "cy", "r"))
        return [[[cx + r * math.cos(2 * math.pi * s / CIRCLE_SAMPLES),
                  cy + r * math.sin(2 * math.pi * s / CIRCLE_SAMPLES)] for s in range(CIRCLE_SAMPLES + 1)]]
    return []


def convert(path):
    root = ET.parse(path).getroot()
    vb = nums(root.get("viewBox", ""))
    if len(vb) != 4:
        raise LessonError(f"{path}: missing viewBox")
    lesson = {
        "id": root.get("data-id") or "",
        "title": root.get("data-title") or "",
        "version": int(root.get("data-version", "1")),
        "canvasSize": {"width": vb[2], "height": vb[3]},
        "steps": [],
    }
    for g in root:
        if tag(g) != "g":
            continue
        strokes = [s for el in g.iter() for s in shape_strokes(el)]
        strokes = [[[round(x - vb[0], 1), round(y - vb[1], 1)] for x, y in s] for s in strokes if len(s) >= 2]
        lesson["steps"].append({
            "kind": g.get("data-kind", "trace"),
            "instruction": g.get("data-instruction") or "",
            "tolerance": float(g.get("data-tolerance", "16")),
            "targetStrokes": strokes,
        })
    validate(lesson, path)
    return lesson


def validate(lesson, path):
    if not lesson["id"] or not lesson["title"]:
        raise LessonError(f"{path}: data-id and data-title are required")
    if not lesson["steps"]:
        raise LessonError(f"{path}: no <g> steps")
    w, h = lesson["canvasSize"]["width"], lesson["canvasSize"]["height"]
    for n, s in enumerate(lesson["steps"], 1):
        where = f"{path} step {n}"
        if s["kind"] not in ("trace", "color"):
            raise LessonError(f"{where}: unknown kind {s['kind']!r}")
        if not s["instruction"]:
            raise LessonError(f"{where}: missing data-instruction")
        if not (2 <= s["tolerance"] <= 60):
            raise LessonError(f"{where}: tolerance out of range")
        if not s["targetStrokes"]:
            raise LessonError(f"{where}: no shapes")
        for st in s["targetStrokes"]:
            for x, y in st:
                if not (0 <= x <= w and 0 <= y <= h):
                    raise LessonError(f"{where}: point {x},{y} outside canvas")


def main(argv):
    if len(argv) < 3:
        print(USAGE); return 2
    out, inputs = argv[1], argv[2:]
    try:
        lessons = [convert(p) for p in inputs]
    except (LessonError, ET.ParseError, ValueError) as e:
        print(f"error: {e}", file=sys.stderr); return 1
    ids = [l["id"] for l in lessons]
    if len(set(ids)) != len(ids):
        print(f"error: duplicate lesson ids {ids}", file=sys.stderr); return 1
    with open(out, "w") as f:
        json.dump(lessons, f, separators=(",", ":"))
    for l in lessons:
        print(f"  {l['id']} v{l['version']}: {len(l['steps'])} steps")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
