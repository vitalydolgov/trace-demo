import SwiftUI

@main
struct TraceDemoApp: App {
    @StateObject private var progress = ProgressStore()
    private let catalog = CatalogLoader.loadBundled()
    private let lessons = LessonLoader.loadBundled()

    var body: some Scene {
        WindowGroup {
            LessonListView(catalog: catalog, lessons: lessons)
                .environmentObject(progress)
        }
    }
}

struct LessonListView: View {
    let catalog: Catalog
    let lessons: [Lesson]
    @EnvironmentObject private var progress: ProgressStore

    var body: some View {
        NavigationStack {
            List {
                ForEach(catalog.courses) { course in
                    Section(course.title) {
                        ForEach(course.lessons) { ref in
                            NavigationLink(value: ref.lessonId) {
                                HStack {
                                    Text(ref.title).font(.title3)
                                    if ref.isPremium {
                                        Text("PRO").font(.caption).foregroundColor(.orange)
                                    }
                                    Spacer()
                                    StarsView(count: progress.progress(for: ref.lessonId).stars)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Lessons")
            .toolbar {
                Text("XP \(progress.state.profile.xp) · streak \(progress.state.profile.streakDays)")
            }
            .navigationDestination(for: String.self) { id in
                if let lesson = lessons.first(where: { $0.id == id }) {
                    LessonScreen(lesson: lesson, progress: progress)
                } else {
                    Text("Lesson content not available")
                }
            }
        }
    }
}

struct LessonScreen: View {
    @StateObject private var vm: LessonViewModel

    init(lesson: Lesson, progress: ProgressStore) {
        _vm = StateObject(wrappedValue: LessonViewModel(lesson: lesson, progress: progress))
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Step \(vm.stepIndex + 1) of \(vm.lesson.steps.count): \(vm.step.instruction)")
                .font(.headline)

            CanvasRepresentable(canvasSize: vm.lesson.canvasSize,
                                targets: vm.visibleTargets,
                                userStrokes: vm.userStrokes,
                                onStroke: { vm.add($0) })
                .aspectRatio(vm.lesson.canvasSize.width / vm.lesson.canvasSize.height, contentMode: .fit)
                .border(Color.gray.opacity(0.4))

            if let r = vm.result {
                Text("Score \(Int(r.score))  ·  precision \(Int(r.precision * 100))%  ·  coverage \(Int(r.coverage * 100))%  ·  \(r.passed ? "Passed" : "Try again")")
                    .foregroundColor(r.passed ? .green : .red)
            }

            if let stars = vm.finishedStars {
                VStack {
                    Text("Lesson complete!").font(.title2)
                    StarsView(count: stars).font(.largeTitle)
                    Button("Again") { vm.restart() }
                }
            } else {
                HStack(spacing: 24) {
                    Button("Clear") { vm.clear() }
                    Button("Check") { vm.check() }
                        .buttonStyle(.borderedProminent)
                        .disabled(vm.userStrokes.isEmpty && vm.step.kind == .trace)
                    Button(vm.isLastStep ? "Finish" : "Next step") { vm.next() }
                        .disabled(vm.result?.passed != true)
                }
            }
        }
        .padding()
        .navigationTitle(vm.lesson.title)
    }
}

struct StarsView: View {
    let count: Int
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { i in
                Image(systemName: i < count ? "star.fill" : "star")
                    .foregroundColor(.yellow)
            }
        }
    }
}

struct CanvasRepresentable: UIViewRepresentable {
    let canvasSize: Size
    let targets: [Stroke]
    let userStrokes: [Stroke]
    let onStroke: (Stroke) -> Void

    func makeUIView(context: Context) -> CanvasView {
        CanvasView()
    }

    func updateUIView(_ view: CanvasView, context: Context) {
        view.onStrokeFinished = onStroke
        if view.canvasSize != canvasSize { view.canvasSize = canvasSize }
        if view.targetStrokes != targets { view.targetStrokes = targets }
        if view.userStrokes != userStrokes { view.userStrokes = userStrokes }
    }
}
