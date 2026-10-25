import Foundation

struct ScoreResult: Equatable {
    var precision: Double
    var coverage: Double
    var score: Double
    var passed: Bool
}

enum Scoring {
    static let spacing = 4.0
    static let passThreshold = 70.0

    static func resample(_ stroke: Stroke, spacing: Double = spacing) -> Stroke {
        guard let first = stroke.first else { return [] }
        var out: Stroke = [first]
        var prev = first
        var carry = 0.0
        for next in stroke.dropFirst() {
            var segStart = prev
            var segLen = dist(segStart, next)
            while carry + segLen >= spacing {
                let t = (spacing - carry) / segLen
                let p = Point(segStart.x + (next.x - segStart.x) * t,
                              segStart.y + (next.y - segStart.y) * t)
                out.append(p)
                segStart = p
                segLen = dist(segStart, next)
                carry = 0
            }
            carry += segLen
            prev = next
        }
        if let last = stroke.last, out.count == 1 || dist(out[out.count - 1], last) > spacing * 0.5 {
            out.append(last)
        }
        return out
    }

    static func fractionNear(_ points: [Point], _ other: [Point], tolerance: Double) -> Double {
        guard !points.isEmpty, !other.isEmpty else { return 0 }
        let tol2 = tolerance * tolerance
        var hits = 0
        for p in points where other.contains(where: { dist2(p, $0) <= tol2 }) {
            hits += 1
        }
        return Double(hits) / Double(points.count)
    }

    static func fractionNear(_ points: [Point], field: DistanceField, tolerance: Double) -> Double {
        guard !points.isEmpty else { return 0 }
        let hits = points.filter { field.distance(at: $0) <= tolerance }.count
        return Double(hits) / Double(points.count)
    }

    static func score(user: [Stroke], target: [Stroke], tolerance: Double,
                      field: DistanceField? = nil) -> ScoreResult {
        let u = user.flatMap { resample($0) }
        let t = target.flatMap { resample($0) }
        let precision = field.map { fractionNear(u, field: $0, tolerance: tolerance) }
            ?? fractionNear(u, t, tolerance: tolerance)
        let coverage = fractionNear(t, u, tolerance: tolerance)
        let combined = (precision + coverage) > 0 ? 2 * precision * coverage / (precision + coverage) : 0
        let score = (combined * 100).rounded()
        return ScoreResult(precision: precision, coverage: coverage, score: score,
                           passed: score >= passThreshold)
    }

    static func stars(forAverage s: Double) -> Int {
        switch s {
        case 90...: return 3
        case 80..<90: return 2
        case passThreshold..<80: return 1
        default: return 0
        }
    }

    private static func dist2(_ a: Point, _ b: Point) -> Double {
        let dx = a.x - b.x, dy = a.y - b.y
        return dx * dx + dy * dy
    }
    private static func dist(_ a: Point, _ b: Point) -> Double { dist2(a, b).squareRoot() }
}
