import Foundation

struct DistanceField {
    let cellSize: Double
    let columns: Int
    let rows: Int
    private var values: [Float]

    init(target: [Stroke], canvasSize: Size, cellSize: Double = 4) {
        self.cellSize = cellSize
        columns = max(1, Int((canvasSize.width / cellSize).rounded(.up)))
        rows = max(1, Int((canvasSize.height / cellSize).rounded(.up)))
        let points = target.flatMap { Scoring.resample($0, spacing: cellSize / 2) }
        values = Array(repeating: 0, count: columns * rows)
        for r in 0..<rows {
            for c in 0..<columns {
                let cx = (Double(c) + 0.5) * cellSize
                let cy = (Double(r) + 0.5) * cellSize
                var best = Double.infinity
                for p in points {
                    let dx = p.x - cx, dy = p.y - cy
                    best = min(best, dx * dx + dy * dy)
                }
                values[r * columns + c] = Float(best.squareRoot())
            }
        }
    }

    func distance(at p: Point) -> Double {
        let c = min(max(Int(p.x / cellSize), 0), columns - 1)
        let r = min(max(Int(p.y / cellSize), 0), rows - 1)
        return Double(values[r * columns + c])
    }
}
