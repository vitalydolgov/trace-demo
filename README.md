# TraceDemo

A tiny iPad demo inspired by ArtWorkout: a reference drawing is shown faded, you trace it with Apple Pencil or a finger, and the app scores how accurate you were. Rendering uses a minimal Metal pipeline.

## Build (XcodeGen)

```sh
brew install xcodegen && xcodegen && open TraceDemo.xcodeproj
```

Pick an iPad simulator or device, set your signing team, and run.

## Build (no XcodeGen)

1. In Xcode: File > New > Project > iOS App, interface SwiftUI, name `TraceDemo`.
2. Delete the generated `ContentView.swift` and `TraceDemoApp.swift`.
3. Drag the `Sources` folder into the project ("Copy items if needed", add to the target). Make sure `lessons.json` is in Copy Bundle Resources and `Shaders.metal` is in Compile Sources.
4. Target > General: set iPad only, iOS 16.0.

## Other

- `Tools/build_lessons.sh` converts `Lessons/src/*.svg` into `Sources/Resources/lessons.json` (see `docs/lesson-pipeline.md`).
- `swiftc Sources/Model.swift Sources/AppModel.swift Sources/Scoring.swift Sources/DistanceField.swift Tests/main.swift -o /tmp/t && /tmp/t` runs the model/scoring checks (macOS or Linux).
- See `ARCHITECTURE.md` for the design.

## Design notes

| Topic | Where to look |
|---|---|
| Core idea (trace a faded reference, get scored) | `ARCHITECTURE.md`, `Sources/Views.swift` (`LessonScreen`), `Sources/LessonViewModel.swift` |
| App data model | `Sources/AppModel.swift` (`UserProfile`, `Catalog` → `Course` → `LessonRef`, `LessonProgress`, `SavedState`), `ProgressStore` in `Sources/LessonViewModel.swift`, `Sources/Resources/catalog.json` |
| Lesson data model | `Sources/Model.swift` (`Lesson`, `Step`, `StepKind`, `Point`), `Sources/Resources/lessons.json` |
| Lesson creation pipeline | `docs/lesson-pipeline.md`, `Tools/build_lessons.sh` |
| Tools and formats | SVG sources `Lessons/src/*.svg`, converter `Tools/svg_to_lesson.py`, JSON output `Sources/Resources/lessons.json` |
| Scoring | `Sources/Scoring.swift` (resampling, precision/coverage, stars), `Sources/DistanceField.swift`, `Tests/main.swift` |
| Rendering (Metal) | `Sources/StrokeRenderer.swift`, `Sources/Shaders.metal`, `Sources/CanvasView.swift` |
