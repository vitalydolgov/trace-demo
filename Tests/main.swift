import Foundation
setvbuf(stdout, nil, _IONBF, 0)

func load(_ path: String) -> Data { try! Data(contentsOf: URL(fileURLWithPath: path)) }

let lessons = try! LessonLoader.load(from: load("Sources/Resources/lessons.json"))
let catalog = try! CatalogLoader.load(from: load("Sources/Resources/catalog.json"))
precondition(lessons.count == 3)
for ref in catalog.courses.flatMap({ $0.lessons }) {
    precondition(lessons.contains { $0.id == ref.lessonId && $0.version == ref.contentVersion })
}
print("lessons:", lessons.map { "\($0.id) v\($0.version) \($0.steps.map { $0.kind.rawValue })" })

let old = #"[{"id":"a","title":"A","canvasSize":{"width":10,"height":10},"steps":[{"instruction":"x","targetStrokes":[[[1,1],[2,2]]],"tolerance":3}]}]"#
let oldLesson = try! LessonLoader.load(from: Data(old.utf8))[0]
precondition(oldLesson.version == 1 && oldLesson.steps[0].kind == .trace)

var state = SavedState()
state.progress["house"] = LessonProgress(bestScore: 91, stars: 3, completedAt: Date())
let decoded = try! JSONDecoder().decode(SavedState.self, from: JSONEncoder().encode(state))
precondition(decoded.progress["house"]?.stars == 3)

func shift(_ s: [Stroke], _ dx: Double, _ dy: Double) -> [Stroke] { s.map { $0.map { Point($0.x + dx, $0.y + dy) } } }

for l in lessons {
    for s in l.steps where s.kind == .trace {
        let field = DistanceField(target: s.targetStrokes, canvasSize: l.canvasSize)
        for (name, user, shouldPass) in [("perfect", s.targetStrokes, true),
                                         ("jitter", shift(s.targetStrokes, 6, -5), true),
                                         ("shifted", shift(s.targetStrokes, 60, 60), false)] {
            let brute = Scoring.score(user: user, target: s.targetStrokes, tolerance: s.tolerance)
            let fast = Scoring.score(user: user, target: s.targetStrokes, tolerance: s.tolerance, field: field)
            print(l.id, name, "brute", brute.score, "field", fast.score)
            precondition(brute.passed == shouldPass && fast.passed == shouldPass)
            precondition(abs(brute.score - fast.score) <= 5)
        }
    }
}

let circle = lessons.first { $0.id == "circle" }!.steps[0].targetStrokes[0]
let half = Scoring.score(user: [Array(circle.prefix(37))], target: [circle], tolerance: 18)
print("half circle", half.score)
precondition(!half.passed)

let line: [Stroke] = [[Point(0, 0), Point(100, 0)]]
precondition(Scoring.score(user: [], target: line, tolerance: 10).score == 0)
precondition(Scoring.score(user: [[]], target: line, tolerance: 10).score == 0)
precondition(!Scoring.score(user: [[Point(50, 0)]], target: line, tolerance: 10).passed)
precondition(Scoring.resample([Point(1, 1), Point(1, 1), Point(1, 1)]).allSatisfy { $0 == Point(1, 1) })
precondition(Scoring.score(user: line, target: [], tolerance: 10).score == 0)
precondition(DistanceField(target: [], canvasSize: Size(width: 10, height: 10)).distance(at: Point(5, 5)) == .infinity)
precondition(DistanceField(target: line, canvasSize: Size(width: 100, height: 100)).distance(at: Point(-50, 500)) >= 0)

let scribble: [Stroke] = [(0..<2000).map { i in Point(300 + 200 * cos(Double(i) / 50), 300 + 200 * sin(Double(i) / 50)) }]
let f = DistanceField(target: [circle], canvasSize: Size(width: 600, height: 600))
var t0 = Date(); _ = Scoring.score(user: scribble, target: [circle], tolerance: 18)
let tb = Date().timeIntervalSince(t0)
t0 = Date(); _ = Scoring.score(user: scribble, target: [circle], tolerance: 18, field: f)
print(String(format: "timing brute %.1f ms, field %.1f ms", tb * 1000, Date().timeIntervalSince(t0) * 1000))
print("ALL OK")
