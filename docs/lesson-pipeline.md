# Lesson pipeline

How a lesson goes from an idea to a user's iPad.

## Roles and tasks

| Step | Who | Output |
|---|---|---|
| 1. Pick the topic, split it into steps, write instructions, set tolerance | Methodologist (art teacher) | Step plan |
| 2. Draw the reference in a vector editor (Figma, Illustrator, Inkscape): one layer (`<g>`) per step, strokes only | Artist | `Lessons/src/<id>.svg` |
| 3. Add `data-instruction`, `data-tolerance`, `data-kind` to each layer, bump `data-version` | Methodologist | Same SVG, committed to git |
| 4. Convert + validate | Script (`Tools/build_lessons.sh`), locally or in CI | `lessons.json` |
| 5. Preview and play the lesson on an iPad | Methodologist / QA, debug build | Approve or fix tolerance/steps |
| 6. Publish | CI | Versioned bundle uploaded to a CDN, e.g. `lessons/house/v2.json` |
| 7. Roll out | Product | Remote config / `catalog.json` points to the new `contentVersion` (can be staged to a % of users) |

Results move between people as files in git (SVG in, JSON out), so every change is reviewable and reversible.

## SVG format

```xml
<svg viewBox="0 0 600 600" data-id="house" data-title="House" data-version="1">
  <g data-kind="trace" data-tolerance="16" data-instruction="Draw the walls.">
    <path d="M150 300 L450 300 L450 520 L150 520 Z"/>
  </g>
</svg>
```
Supported shapes: `path` (M, L, H, V, C, Z), `polyline`, `polygon`, `line`, `circle`. Curves are sampled into points.

## What this repo implements (the local part)

- `Lessons/src/*.svg` – source lessons (circle, house with a Bezier curve, star with a `color` step).
- `Tools/svg_to_lesson.py` – stdlib-only converter + validator (required fields, kinds, tolerance range, points inside the canvas, unique ids).
- `Tools/build_lessons.sh` – runs the converter, checks `catalog.json` references and versions, writes `Sources/Resources/lessons.json`.
- `Tests/main.swift` – loads the generated JSON with the app's own Swift decoder and checks that a perfect trace passes every step.

Not implemented: CDN upload, remote config, in-app download (the app uses the bundled JSON).
