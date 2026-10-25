import Combine
import Foundation

final class ProgressStore: ObservableObject {
    @Published private(set) var state: SavedState
    private let key = "savedState.v1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key),
           let saved = try? JSONDecoder().decode(SavedState.self, from: data) {
            state = saved
        } else {
            state = SavedState()
        }
    }

    func progress(for lessonID: String) -> LessonProgress {
        state.progress[lessonID] ?? LessonProgress()
    }

    func recordCompletion(lessonID: String, score: Double, stars: Int, now: Date = Date()) {
        var p = progress(for: lessonID)
        p.bestScore = max(p.bestScore, score)
        p.stars = max(p.stars, stars)
        p.completedAt = now
        state.progress[lessonID] = p

        state.profile.xp += 10 + stars * 10
        let cal = Calendar.current
        if let last = state.profile.lastActiveDay, cal.isDateInYesterday(last) {
            state.profile.streakDays += 1
        } else if state.profile.lastActiveDay.map({ !cal.isDateInToday($0) }) ?? true {
            state.profile.streakDays = 1
        }
        state.profile.lastActiveDay = now
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(state) {
            defaults.set(data, forKey: key)
        }
    }
}

final class LessonViewModel: ObservableObject {
    let lesson: Lesson
    @Published private(set) var stepIndex = 0 { didSet { field = nil } }
    @Published var userStrokes: [Stroke] = []
    @Published private(set) var result: ScoreResult?
    @Published private(set) var finishedStars: Int?

    private var field: DistanceField?
    private var stepScores: [Double] = []
    private let progress: ProgressStore
    private var cancellables = Set<AnyCancellable>()

    init(lesson: Lesson, progress: ProgressStore) {
        self.lesson = lesson
        self.progress = progress
        $userStrokes
            .dropFirst()
            .sink { [weak self] _ in self?.result = nil }
            .store(in: &cancellables)
    }

    var step: Step { lesson.steps[stepIndex] }
    var isLastStep: Bool { stepIndex == lesson.steps.count - 1 }

    var visibleTargets: [Stroke] {
        lesson.steps[0...stepIndex].flatMap { $0.targetStrokes }
    }

    func add(_ stroke: Stroke) { userStrokes.append(stroke) }
    func clear() { userStrokes = [] }

    func check() {
        if step.kind == .color {
            result = ScoreResult(precision: 1, coverage: 1, score: 100, passed: true)
            return
        }
        if field == nil {
            field = DistanceField(target: step.targetStrokes, canvasSize: lesson.canvasSize)
        }
        result = Scoring.score(user: userStrokes, target: step.targetStrokes,
                               tolerance: step.tolerance, field: field)
    }

    func next() {
        guard let r = result, r.passed else { return }
        stepScores.append(r.score)
        if isLastStep {
            let avg = stepScores.reduce(0, +) / Double(stepScores.count)
            let stars = Scoring.stars(forAverage: avg)
            progress.recordCompletion(lessonID: lesson.id, score: avg, stars: stars)
            finishedStars = stars
        } else {
            stepIndex += 1
            userStrokes = []
            result = nil
        }
    }

    func restart() {
        stepIndex = 0
        stepScores = []
        userStrokes = []
        result = nil
        finishedStars = nil
    }
}
