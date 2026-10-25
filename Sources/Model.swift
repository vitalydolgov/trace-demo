import Foundation

struct Point: Codable, Equatable {
    var x: Double
    var y: Double

    init(_ x: Double, _ y: Double) { self.x = x; self.y = y }

    init(from decoder: Decoder) throws {
        var c = try decoder.unkeyedContainer()
        x = try c.decode(Double.self)
        y = try c.decode(Double.self)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.unkeyedContainer()
        try c.encode(x)
        try c.encode(y)
    }
}

typealias Stroke = [Point]

struct Size: Codable, Equatable {
    var width: Double
    var height: Double
}

enum StepKind: String, Codable {
    case trace
    case color
}

struct Step: Codable, Equatable {
    var kind: StepKind = .trace
    var instruction: String
    var targetStrokes: [Stroke]
    var tolerance: Double
}

struct Lesson: Codable, Identifiable, Equatable {
    var id: String
    var title: String
    var version: Int = 1
    var canvasSize: Size
    var steps: [Step]
}

extension Step {
    enum CodingKeys: String, CodingKey { case kind, instruction, targetStrokes, tolerance }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        kind = try c.decodeIfPresent(StepKind.self, forKey: .kind) ?? .trace
        instruction = try c.decode(String.self, forKey: .instruction)
        targetStrokes = try c.decode([Stroke].self, forKey: .targetStrokes)
        tolerance = try c.decode(Double.self, forKey: .tolerance)
    }
}

extension Lesson {
    enum CodingKeys: String, CodingKey { case id, title, version, canvasSize, steps }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 1
        canvasSize = try c.decode(Size.self, forKey: .canvasSize)
        steps = try c.decode([Step].self, forKey: .steps)
    }
}

enum LessonLoader {
    static func load(from data: Data) throws -> [Lesson] {
        try JSONDecoder().decode([Lesson].self, from: data)
    }

    static func loadBundled(_ bundle: Bundle = .main) -> [Lesson] {
        guard let url = bundle.url(forResource: "lessons", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let lessons = try? load(from: data) else { return [] }
        return lessons
    }
}
