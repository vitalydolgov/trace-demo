#include <metal_stdlib>
using namespace metal;

struct Uniforms {
    float2 canvasSize;
    float4 color;
};

vertex float4 stroke_vertex(uint vid [[vertex_id]],
                            const device float2 *positions [[buffer(0)]],
                            constant Uniforms &u [[buffer(1)]])
{
    float2 p = positions[vid] / u.canvasSize;
    float2 ndc = float2(p.x * 2.0 - 1.0, 1.0 - p.y * 2.0);
    return float4(ndc, 0.0, 1.0);
}

fragment float4 stroke_fragment(constant Uniforms &u [[buffer(0)]])
{
    return u.color;
}
