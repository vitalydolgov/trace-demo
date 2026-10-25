import MetalKit
import UIKit

final class CanvasView: MTKView {
    var onStrokeFinished: ((Stroke) -> Void)?

    private var renderer: StrokeRenderer?
    private var committedStrokes: [Stroke] = []
    private var currentStroke: Stroke?

    var canvasSize = Size(width: 600, height: 600) { didSet { syncRenderer() } }
    var targetStrokes: [Stroke] = [] { didSet { syncRenderer() } }
    var userStrokes: [Stroke] {
        get { committedStrokes }
        set { committedStrokes = newValue; syncRenderer() }
    }

    init() {
        super.init(frame: .zero, device: MTLCreateSystemDefaultDevice())
        colorPixelFormat = .bgra8Unorm
        clearColor = MTLClearColor(red: 1, green: 1, blue: 1, alpha: 1)
        isPaused = true
        enableSetNeedsDisplay = true
        isMultipleTouchEnabled = false
        renderer = StrokeRenderer(view: self)
        delegate = renderer
    }

    required init(coder: NSCoder) { fatalError("init(coder:) is not used") }

    private func syncRenderer() {
        renderer?.canvasSize = canvasSize
        renderer?.targetStrokes = targetStrokes
        renderer?.userStrokes = committedStrokes + (currentStroke.map { [$0] } ?? [])
        setNeedsDisplay()
    }

    private func lessonPoint(_ touch: UITouch) -> Point {
        let p = touch.preciseLocation(in: self)
        let sx = canvasSize.width / Double(max(bounds.width, 1))
        let sy = canvasSize.height / Double(max(bounds.height, 1))
        return Point(Double(p.x) * sx, Double(p.y) * sy)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        currentStroke = [lessonPoint(t)]
        syncRenderer()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first, currentStroke != nil else { return }
        for c in event?.coalescedTouches(for: t) ?? [t] {
            currentStroke?.append(lessonPoint(c))
        }
        syncRenderer()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let stroke = currentStroke else { return }
        currentStroke = nil
        committedStrokes.append(stroke)
        syncRenderer()
        onStrokeFinished?(stroke)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        currentStroke = nil
        syncRenderer()
    }
}
