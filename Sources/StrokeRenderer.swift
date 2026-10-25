import MetalKit
import simd

private struct Uniforms {
    var canvasSize: SIMD2<Float>
    var color: SIMD4<Float>
}

final class StrokeRenderer: NSObject, MTKViewDelegate {
    private let device: MTLDevice
    private let queue: MTLCommandQueue
    private let pipeline: MTLRenderPipelineState

    var canvasSize = Size(width: 600, height: 600)
    var targetStrokes: [Stroke] = []
    var userStrokes: [Stroke] = []

    init?(view: MTKView) {
        guard let device = view.device ?? MTLCreateSystemDefaultDevice(),
              let queue = device.makeCommandQueue(),
              let library = device.makeDefaultLibrary() else { return nil }
        self.device = device
        self.queue = queue

        let desc = MTLRenderPipelineDescriptor()
        desc.vertexFunction = library.makeFunction(name: "stroke_vertex")
        desc.fragmentFunction = library.makeFunction(name: "stroke_fragment")
        let attachment = desc.colorAttachments[0]!
        attachment.pixelFormat = view.colorPixelFormat
        attachment.isBlendingEnabled = true
        attachment.rgbBlendOperation = .add
        attachment.alphaBlendOperation = .add
        attachment.sourceRGBBlendFactor = .sourceAlpha
        attachment.sourceAlphaBlendFactor = .sourceAlpha
        attachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
        attachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha

        guard let pipeline = try? device.makeRenderPipelineState(descriptor: desc) else { return nil }
        self.pipeline = pipeline
        super.init()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    }

    func draw(in view: MTKView) {
        guard let passDesc = view.currentRenderPassDescriptor,
              let drawable = view.currentDrawable,
              let commandBuffer = queue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: passDesc) else { return }

        encoder.setRenderPipelineState(pipeline)
        draw(targetStrokes, width: 10, color: SIMD4(0.2, 0.4, 1.0, 0.25), encoder: encoder)
        draw(userStrokes, width: 6, color: SIMD4(0.1, 0.1, 0.1, 0.9), encoder: encoder)

        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    private func draw(_ strokes: [Stroke], width: Float, color: SIMD4<Float>, encoder: MTLRenderCommandEncoder) {
        let vertices = Self.triangles(for: strokes, width: width)
        guard !vertices.isEmpty,
              let buffer = device.makeBuffer(bytes: vertices,
                                             length: vertices.count * MemoryLayout<SIMD2<Float>>.stride,
                                             options: .storageModeShared) else { return }
        var uniforms = Uniforms(canvasSize: SIMD2(Float(canvasSize.width), Float(canvasSize.height)),
                                color: color)
        encoder.setVertexBuffer(buffer, offset: 0, index: 0)
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertices.count)
    }

    static func triangles(for strokes: [Stroke], width: Float) -> [SIMD2<Float>] {
        var out: [SIMD2<Float>] = []
        let hw = width / 2
        for stroke in strokes {
            let pts = stroke.map { SIMD2<Float>(Float($0.x), Float($0.y)) }
            if pts.count == 1 {
                let p = pts[0]
                out += quad(p - SIMD2(hw, 0), p + SIMD2(hw, 0), hw)
                continue
            }
            for (a, b) in zip(pts, pts.dropFirst()) {
                out += quad(a, b, hw)
            }
        }
        return out
    }

    private static func quad(_ a: SIMD2<Float>, _ b: SIMD2<Float>, _ hw: Float) -> [SIMD2<Float>] {
        let d = b - a
        let len = simd_length(d)
        guard len > 0.0001 else { return [] }
        let dir = d / len
        let n = SIMD2(-dir.y, dir.x) * hw
        let a2 = a - dir * hw, b2 = b + dir * hw
        let p0 = a2 + n, p1 = a2 - n, p2 = b2 + n, p3 = b2 - n
        return [p0, p1, p2, p2, p1, p3]
    }
}
