import Foundation

struct UserProfile: Codable, Equatable {
    var xp: Int = 0
    var streakDays: Int = 0
    var lastActiveDay: Date?
    var isPremium: Bool = false
}

struct Catalog: Codable, Equatable {
    var courses: [Course]
}

struct Course: Codable, Equatable, Identifiable {
    var id: String
    var title: String
    var lessons: [LessonRef]
}

struct LessonRef: Codable, Equatable, Identifiable {
    var lessonId: String
    var title: String
    var difficulty: Int
    var isPremium: Bool
    var contentVersion: Int
    var id: String { lessonId }
}

struct LessonProgress: Codable, Equatable {
    var bestScore: Double = 0
    var stars: Int = 0
    var completedAt: Date?
}

struct SavedState: Codable {
    var profile = UserProfile()
    var progress: [String: LessonProgress] = [:]
}

enum CatalogLoader {
    static func load(from data: Data) throws -> Catalog {
        try JSONDecoder().decode(Catalog.self, from: data)
    }

    static func loadBundled(_ bundle: Bundle = .main) -> Catalog {
        guard let url = bundle.url(forResource: "catalog", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let catalog = try? load(from: data) else { return Catalog(courses: []) }
        return catalog
    }
}
