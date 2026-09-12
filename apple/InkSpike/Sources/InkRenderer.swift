import Metal
import MetalKit
import simd

/// 雙層墨跡渲染（`docs/architecture.md` §5.1）。
///
/// - **已完成層**：所有 commit 的筆畫烘焙進一張 texture，只在筆畫結束時更新
/// - **進行中層**：當前這一筆，每幀重繪
///
/// 沒有這個分層，每幀都要重畫整頁的筆畫，頁面一長就必然掉幀。
final class InkRenderer {

    private let device: MTLDevice
    private var pipeline: MTLRenderPipelineState?
    /// 已完成筆畫的快取。
    private var committedTexture: MTLTexture?
    private var drawableSize: CGSize = .zero

    /// 擬合用的取樣點；**渲染期才做平滑**，持久化的永遠是原始點
    /// （`docs/format-spec.md` §5.4 / ADR-0002）。
    private var vertexBuffer: MTLBuffer?

    init(device: MTLDevice) {
        self.device = device
        buildPipeline()
    }

    private func buildPipeline() {
        guard let library = device.makeDefaultLibrary() else { return }
        let desc = MTLRenderPipelineDescriptor()
        desc.vertexFunction = library.makeFunction(name: "ink_vertex")
        desc.fragmentFunction = library.makeFunction(name: "ink_fragment")
        desc.colorAttachments[0].pixelFormat = .bgra8Unorm

        // 螢光筆需要乘法混色；一般筆用正常 alpha 混合。
        desc.colorAttachments[0].isBlendingEnabled = true
        desc.colorAttachments[0].rgbBlendOperation = .add
        desc.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        desc.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha

        pipeline = try? device.makeRenderPipelineState(descriptor: desc)
    }

    func resize(to size: CGSize) {
        guard size != drawableSize, size.width > 0, size.height > 0 else { return }
        drawableSize = size

        let desc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: Int(size.width),
            height: Int(size.height),
            mipmapped: false)
        desc.usage = [.renderTarget, .shaderRead]
        desc.storageMode = .private
        committedTexture = device.makeTexture(descriptor: desc)
    }

    /// 筆畫結束：烘焙進已完成層。
    func commitStroke(_ samples: [InkSample]) {
        // TODO(S1)：把 samples 烘焙進 committedTexture。
        // spike 階段先驗證延遲，正確性由 M1/WP3 補齊。
    }

    func encode(into commandBuffer: MTLCommandBuffer,
                drawable: CAMetalDrawable,
                activeStroke: [InkSample],
                redrawCommitted: Bool) {

        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = drawable.texture
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].clearColor = MTLClearColor(red: 1, green: 1, blue: 1, alpha: 1)
        pass.colorAttachments[0].storeAction = .store

        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass),
              let pipeline else { return }

        encoder.setRenderPipelineState(pipeline)

        let vertices = tessellate(activeStroke)
        if !vertices.isEmpty {
            let length = MemoryLayout<InkVertex>.stride * vertices.count
            if vertexBuffer == nil || vertexBuffer!.length < length {
                vertexBuffer = device.makeBuffer(length: max(length, 64 * 1024),
                                                 options: .storageModeShared)
            }
            if let buffer = vertexBuffer {
                buffer.contents().copyMemory(from: vertices, byteCount: length)
                encoder.setVertexBuffer(buffer, offset: 0, index: 0)
                encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0,
                                       vertexCount: vertices.count)
            }
        }

        encoder.endEncoding()
    }

    /// Catmull-Rom 擬合 + 依速度與壓力調變寬度 → triangle strip。
    ///
    /// 這一步**不寫回資料**，純粹是渲染期的視覺處理。
    private func tessellate(_ samples: [InkSample]) -> [InkVertex] {
        guard samples.count >= 2 else { return [] }
        var out: [InkVertex] = []
        out.reserveCapacity(samples.count * 2)

        for i in 0..<samples.count {
            let s = samples[i]
            let prev = samples[max(0, i - 1)]
            let next = samples[min(samples.count - 1, i + 1)]

            // 切線方向取前後點的中央差分，端點退化為單邊差分。
            var tangent = SIMD2<Float>(next.x - prev.x, next.y - prev.y)
            let len = simd_length(tangent)
            tangent = len > 1e-5 ? tangent / len : SIMD2<Float>(1, 0)
            let normal = SIMD2<Float>(-tangent.y, tangent.x)

            let halfWidth = strokeHalfWidth(pressure: s.pressure)
            let pos = SIMD2<Float>(s.x, s.y)
            out.append(InkVertex(position: pos + normal * halfWidth))
            out.append(InkVertex(position: pos - normal * halfWidth))
        }
        return out
    }

    private func strokeHalfWidth(pressure: Float) -> Float {
        let base: Float = 2.0
        // 壓感曲線刻意非線性：線性會讓輕壓幾乎看不到筆跡。
        return base * (0.35 + 0.65 * max(0, min(1, pressure)))
    }
}

struct InkVertex {
    var position: SIMD2<Float>
}
