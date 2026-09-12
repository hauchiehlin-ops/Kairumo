#include <metal_stdlib>
using namespace metal;

struct InkVertex {
    float2 position;
};

struct VertexOut {
    float4 position [[position]];
};

// 座標已是 drawable 像素座標，此處轉為 NDC。
vertex VertexOut ink_vertex(uint vid [[vertex_id]],
                            constant InkVertex *vertices [[buffer(0)]],
                            constant float2 &viewport [[buffer(1)]]) {
    VertexOut out;
    float2 p = vertices[vid].position / viewport;
    out.position = float4(p.x * 2.0 - 1.0, 1.0 - p.y * 2.0, 0.0, 1.0);
    return out;
}

fragment float4 ink_fragment() {
    return float4(0.0, 0.0, 0.0, 1.0);
}
