//! 對一個 16 kHz 單聲道 WAV 做辨識，用來與 FunASR 的 Python 輸出比對。
//!
//! ```bash
//! cargo run -p padnote-asr-paraformer --example transcribe_wav -- <model_dir> <file.wav>
//! ```

use padnote_asr::AsrEngine;
use padnote_asr_paraformer::engine::{ModelPaths, ParaformerEngine};

/// 最小的 WAV 解析：找到 `fmt ` 與 `data` 區塊，回傳 16-bit PCM 轉成的 f32。
fn read_wav(bytes: &[u8]) -> Option<(u32, Vec<f32>)> {
    if bytes.len() < 12 || &bytes[0..4] != b"RIFF" || &bytes[8..12] != b"WAVE" {
        return None;
    }
    let (mut pos, mut rate, mut channels) = (12usize, 0u32, 1u16);

    while pos + 8 <= bytes.len() {
        let id = &bytes[pos..pos + 4];
        let size = u32::from_le_bytes(bytes[pos + 4..pos + 8].try_into().ok()?) as usize;
        let body = pos + 8;

        if id == b"fmt " && body + 16 <= bytes.len() {
            channels = u16::from_le_bytes(bytes[body + 2..body + 4].try_into().ok()?);
            rate = u32::from_le_bytes(bytes[body + 4..body + 8].try_into().ok()?);
        } else if id == b"data" {
            let end = (body + size).min(bytes.len());
            let samples: Vec<f32> = bytes[body..end]
                .chunks_exact(2)
                .map(|c| i16::from_le_bytes([c[0], c[1]]) as f32 / 32_768.0)
                // 多聲道只取第一聲道
                .step_by(channels.max(1) as usize)
                .collect();
            return Some((rate, samples));
        }
        // 區塊長度是奇數時要補一個位元組
        pos = body + size + (size & 1);
    }
    None
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let mut args = std::env::args().skip(1);
    let model_dir = args
        .next()
        .ok_or("用法：transcribe_wav <model_dir> <file.wav>")?;
    let wav_path = args.next().ok_or("缺少 wav 路徑")?;

    let (rate, pcm) = read_wav(&std::fs::read(&wav_path)?).ok_or("無法解析 WAV")?;
    println!(
        "音檔：{rate} Hz，{} 樣本（{:.2} 秒）",
        pcm.len(),
        pcm.len() as f32 / rate as f32
    );
    if rate != 16_000 {
        return Err(format!("需要 16 kHz，實得 {rate}").into());
    }

    let mut engine = ParaformerEngine::load(&ModelPaths::in_dir(&model_dir))?;

    let mode = std::env::args().nth(3).unwrap_or_else(|| "whole".into());

    let mut text = String::new();
    if let Some(n) = std::env::args().nth(4).and_then(|s| s.parse().ok()) {
        engine.set_context_frames(n);
    }

    if mode == "chunked" {
        engine.enable_experimental_frame_streaming();
        // 每 100 ms 餵一次
        for chunk in pcm.chunks(1_600) {
            for seg in engine.feed(chunk)? {
                text.push_str(&seg.text);
            }
        }
    } else {
        // 整段一次處理（預設行為）
        engine.feed(&pcm)?;
    }
    for seg in engine.finish()? {
        text.push_str(&seg.text);
    }

    println!("Rust 輸出（{mode}）：{text}");
    Ok(())
}
