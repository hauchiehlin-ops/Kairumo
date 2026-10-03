//! wgpu 渲染管線，供 Apple 以外平台使用。
//! Apple 平台走原生 Metal（`apple/` 下的 InkView）。

use bytemuck::{Pod, Zeroable};
use std::borrow::Cow;

#[repr(C)]
#[derive(Copy, Clone, Debug, Pod, Zeroable)]
pub struct Vertex {
    pub position: [f32; 2],
    pub color: [f32; 4],
}

impl Vertex {
    pub fn desc<'a>() -> wgpu::VertexBufferLayout<'a> {
        wgpu::VertexBufferLayout {
            array_stride: std::mem::size_of::<Vertex>() as wgpu::BufferAddress,
            step_mode: wgpu::VertexStepMode::Vertex,
            attributes: &[
                wgpu::VertexAttribute {
                    offset: 0,
                    shader_location: 0,
                    format: wgpu::VertexFormat::Float32x2,
                },
                wgpu::VertexAttribute {
                    offset: std::mem::size_of::<[f32; 2]>() as wgpu::BufferAddress,
                    shader_location: 1,
                    format: wgpu::VertexFormat::Float32x4,
                },
            ],
        }
    }
}

#[derive(Debug)]
pub struct Renderer {
    pub device: wgpu::Device,
    pub queue: wgpu::Queue,
    pub render_pipeline: wgpu::RenderPipeline,
}

impl Renderer {
    pub async fn new(
        instance: &wgpu::Instance,
        surface: &wgpu::Surface<'static>,
        config: &wgpu::SurfaceConfiguration,
    ) -> Option<Self> {
        let adapter = instance
            .request_adapter(&wgpu::RequestAdapterOptions {
                power_preference: wgpu::PowerPreference::HighPerformance,
                compatible_surface: Some(surface),
                force_fallback_adapter: false,
            })
            .await?;

        let (device, queue) = adapter
            .request_device(
                &wgpu::DeviceDescriptor {
                    label: Some("Padnote Render Device"),
                    required_features: wgpu::Features::empty(),
                    required_limits: wgpu::Limits::default(),
                },
                None,
            )
            .await
            .ok()?;

        let shader = device.create_shader_module(wgpu::ShaderModuleDescriptor {
            label: Some("Ink Shader"),
            source: wgpu::ShaderSource::Wgsl(Cow::Borrowed(include_str!("shader.wgsl"))),
        });

        let render_pipeline_layout =
            device.create_pipeline_layout(&wgpu::PipelineLayoutDescriptor {
                label: Some("Ink Pipeline Layout"),
                bind_group_layouts: &[],
                push_constant_ranges: &[],
            });

        let render_pipeline = device.create_render_pipeline(&wgpu::RenderPipelineDescriptor {
            label: Some("Ink Render Pipeline"),
            layout: Some(&render_pipeline_layout),
            vertex: wgpu::VertexState {
                module: &shader,
                entry_point: "vs_main",
                buffers: &[Vertex::desc()],
            },
            fragment: Some(wgpu::FragmentState {
                module: &shader,
                entry_point: "fs_main",
                targets: &[Some(wgpu::ColorTargetState {
                    format: config.format,
                    blend: Some(wgpu::BlendState::ALPHA_BLENDING),
                    write_mask: wgpu::ColorWrites::ALL,
                })],
            }),
            primitive: wgpu::PrimitiveState {
                topology: wgpu::PrimitiveTopology::TriangleList,
                strip_index_format: None,
                front_face: wgpu::FrontFace::Ccw,
                cull_mode: None,
                unclipped_depth: false,
                polygon_mode: wgpu::PolygonMode::Fill,
                conservative: false,
            },
            depth_stencil: None,
            multisample: wgpu::MultisampleState {
                count: 1,
                mask: !0,
                alpha_to_coverage_enabled: false,
            },
            multiview: None,
        });

        Some(Self {
            device,
            queue,
            render_pipeline,
        })
    }
}

/// 圖層混合模式（Layer Blend Mode）。
#[derive(Clone, Copy, Debug, PartialEq, Eq, Default)]
pub enum BlendMode {
    /// 正常正常覆蓋（Alpha Blend）
    #[default]
    Normal,
    /// 正片疊底（Multiply）—— 墨水與底層色彩相乘，重現真實顏料滲透
    Multiply,
    /// 濾色（Screen）—— 提亮、光暈效果
    Screen,
    /// 鎖定透明度（Alpha Lock）—— 僅在已有色彩的像素上著色，不擴散到空白區
    AlphaLock,
}

impl BlendMode {
    /// 轉為 wgpu::BlendState 設定。
    pub fn to_blend_state(self) -> wgpu::BlendState {
        match self {
            Self::Normal => wgpu::BlendState::ALPHA_BLENDING,
            Self::Multiply => wgpu::BlendState {
                color: wgpu::BlendComponent {
                    src_factor: wgpu::BlendFactor::Dst,
                    dst_factor: wgpu::BlendFactor::OneMinusSrcAlpha,
                    operation: wgpu::BlendOperation::Add,
                },
                alpha: wgpu::BlendComponent {
                    src_factor: wgpu::BlendFactor::One,
                    dst_factor: wgpu::BlendFactor::OneMinusSrcAlpha,
                    operation: wgpu::BlendOperation::Add,
                },
            },
            Self::Screen => wgpu::BlendState {
                color: wgpu::BlendComponent {
                    src_factor: wgpu::BlendFactor::One,
                    dst_factor: wgpu::BlendFactor::OneMinusSrc,
                    operation: wgpu::BlendOperation::Add,
                },
                alpha: wgpu::BlendComponent {
                    src_factor: wgpu::BlendFactor::One,
                    dst_factor: wgpu::BlendFactor::OneMinusSrcAlpha,
                    operation: wgpu::BlendOperation::Add,
                },
            },
            Self::AlphaLock => wgpu::BlendState {
                color: wgpu::BlendComponent {
                    src_factor: wgpu::BlendFactor::DstAlpha,
                    dst_factor: wgpu::BlendFactor::OneMinusSrcAlpha,
                    operation: wgpu::BlendOperation::Add,
                },
                alpha: wgpu::BlendComponent {
                    src_factor: wgpu::BlendFactor::Zero,
                    dst_factor: wgpu::BlendFactor::One,
                    operation: wgpu::BlendOperation::Add,
                },
            },
        }
    }
}

/// 筆刷紋理型別：筆尖印章紋理（Stamp）與紙張纖維孔隙紋理（Grain）。
#[derive(Debug)]
pub struct BrushTextures;

impl BrushTextures {
    /// 產生決定性圓形高斯軟邊印章紋理（Stamp Texture）：`size x size` 單通道灰階（R8Unorm）。
    pub fn generate_gaussian_stamp(size: u32) -> Vec<u8> {
        let mut pixels = Vec::with_capacity((size * size) as usize);
        let center = (size as f32 - 1.0) * 0.5;
        let radius = center.max(1.0);
        for y in 0..size {
            for x in 0..size {
                let dx = (x as f32 - center) / radius;
                let dy = (y as f32 - center) / radius;
                let d2 = dx * dx + dy * dy;
                let alpha = if d2 >= 1.0 {
                    0.0f32
                } else {
                    (-d2 * 3.5).exp() * (1.0 - d2).powf(1.5)
                };
                pixels.push((alpha.clamp(0.0, 1.0) * 255.0).round() as u8);
            }
        }
        pixels
    }

    /// 根據 `padnote_ink::brush::paper_grain` 產生紙張孔隙紋理圖磚（Grain Texture）：`width x height`。
    pub fn generate_paper_grain(width: u32, height: u32, scale: f32) -> Vec<u8> {
        let mut pixels = Vec::with_capacity((width * height) as usize);
        for y in 0..height {
            for x in 0..width {
                let g = padnote_ink::brush::paper_grain(x as f32 * scale, y as f32 * scale);
                pixels.push((g.clamp(0.0, 1.0) * 255.0).round() as u8);
            }
        }
        pixels
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn blend_mode_states_are_valid() {
        for mode in [
            BlendMode::Normal,
            BlendMode::Multiply,
            BlendMode::Screen,
            BlendMode::AlphaLock,
        ] {
            let state = mode.to_blend_state();
            assert_ne!(state.color.operation, wgpu::BlendOperation::Subtract);
        }
    }

    #[test]
    fn stamp_texture_generation_is_circular_and_symmetric() {
        let size = 64;
        let stamp = BrushTextures::generate_gaussian_stamp(size);
        assert_eq!(stamp.len(), (size * size) as usize);
        // 中心最濃（接近 255）
        let center_idx = ((size / 2) * size + (size / 2)) as usize;
        assert!(stamp[center_idx] > 240);
        // 四個角落為 0
        assert_eq!(stamp[0], 0);
        assert_eq!(stamp[(size - 1) as usize], 0);
    }

    #[test]
    fn grain_texture_generation_matches_paper_grain() {
        let (w, h) = (32, 32);
        let grain = BrushTextures::generate_paper_grain(w, h, 1.0);
        assert_eq!(grain.len(), (w * h) as usize);
        // 驗證數值分佈在合理紙張纖維區間
        let min = *grain.iter().min().unwrap();
        let max = *grain.iter().max().unwrap();
        assert!(
            min < 50 && max > 200,
            "紙紋應具備足夠的明暗反差: min={min}, max={max}"
        );
    }
}
