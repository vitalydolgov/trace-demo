# TraceDemo – Architecture

A small iPad app that teaches drawing by tracing: a faded reference is shown, the user traces it with Apple Pencil or a finger, the app scores the result. About 750 lines of Swift, no dependencies.

## Modules

| File | Role |
|---|---|
| `Model.swift` | Lesson content: `Lesson` (id, title, version, canvas size, steps), `Step` (kind, instruction, target strokes, tolerance). Codable, backward compatible. |
| `AppModel.swift` | App data: `UserProfile` (xp, streak, premium), `Catalog` → `Course` → `LessonRef` (id, difficulty, premium, contentVersion), `LessonProgress` (best score, stars, date). |
| `Scoring.swift`, `DistanceField.swift` | Pure Swift (Foundation only), testable anywhere. Compare user strokes with the target. |
| `CanvasView.swift` | `MTKView` subclass: touches (incl. coalesced 240 Hz Pencil samples) → strokes in lesson coordinates. |
| `StrokeRenderer.swift`, `Shaders.metal` | Minimal Metal: one pipeline, strokes → quads on the CPU, flat colour with alpha blending. |
| `LessonViewModel.swift` | `ObservableObject` + Combine: step, strokes, score, stars. `ProgressStore` saves `SavedState` as JSON in UserDefaults. |
| `Views.swift` | SwiftUI: catalog list (courses, stars, XP), lesson screen, `UIViewRepresentable` bridge. |
| `Lessons/src/*.svg`, `Tools/` | Content pipeline: SVG → validated `lessons.json`. See `docs/lesson-pipeline.md`. |

## Data flow

1. **Touch → stroke.** `CanvasView` collects points and hands each finished stroke to the view model.
2. **Stroke → score.** On "Check", lines are resampled to equal spacing (4 units), then:
   - *precision* = share of user points within `tolerance` of the target (stayed on the line?). Uses a `DistanceField`: a grid of distances to the target, built once per step, so each point is one array read.
   - *coverage* = share of target points within `tolerance` of the user's lines (drew all of it?).
   - score = harmonic mean × 100, pass at 70; lesson stars from the average step score.
3. **View model → UI.** `@Published` values drive SwiftUI; completion updates `LessonProgress` and XP/streak.
4. **Render loop.** The view redraws only on change. Each frame: build triangles, draw faded target, then user strokes. The vertex shader maps lesson coordinates to clip space, so the drawing scales with the view.

## Lesson format

Authored as SVG (one `<g>` layer per step with `data-instruction`, `data-tolerance`, `data-kind`), converted by `Tools/build_lessons.sh` to:
```json
[{ "id": "house", "title": "House", "version": 1, "canvasSize": {"width": 600, "height": 600},
   "steps": [{ "kind": "trace", "instruction": "Draw the walls.", "tolerance": 16,
               "targetStrokes": [[[150,300],[450,300], ...]] }] }]
```
`catalog.json` references lessons by id + `contentVersion`, so content can be updated without an app release.

## What a real app would improve

- **GPU distance field:** the same grid as a Metal texture, for live "on/off the line" feedback while drawing.
- **Stroke order and direction:** compare sequence and direction, not only shape.
- **Content delivery:** versioned bundles on a CDN, remote-config rollout, in-app preview tool for methodologists.
- **Better strokes:** smoothing (Catmull-Rom), pressure/tilt width, round joins, reused GPU buffers.
