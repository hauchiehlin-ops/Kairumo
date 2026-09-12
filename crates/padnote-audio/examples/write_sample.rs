//! 產生一個真實的 .opus 檔，用外部播放器驗證容器正確性。
//!
//! ```bash
//! cargo run -p padnote-audio --example write_sample -- /tmp/sample.opus
//! ffprobe /tmp/sample.opus
//! ```

use padnote_audio::{OggOpusWriter, OpusEncoder};

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let path = std::env::args()
        .nth(1)
        .unwrap_or("/tmp/padnote-sample.opus".into());

    // 2 秒 440 Hz 正弦波
    let pcm: Vec<f32> = (0..32_000)
        .map(|i| (i as f32 * 2.0 * std::f32::consts::PI * 440.0 / 16_000.0).sin() * 0.5)
        .collect();

    let file = std::fs::File::create(&path)?;
    let mut writer = OggOpusWriter::new(std::io::BufWriter::new(file), 0x50414432)?;
    let mut encoder = OpusEncoder::new()?;

    for packet in encoder.encode(&pcm)? {
        writer.push(packet)?;
    }
    if let Some(last) = encoder.finish()? {
        writer.push(last)?;
    }
    writer.finish()?;

    println!("寫出 {path}（{} 個音框）", encoder.frames_encoded());
    Ok(())
}
