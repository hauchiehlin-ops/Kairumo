//! 走完整的錄音流程並產出真實的 `.padnote` 套件，供外部工具檢驗。
//!
//! ```bash
//! cargo run -p padnote-core --example record_session -- /tmp/demo.padnote
//! ffprobe /tmp/demo.padnote/media/audio/*.opus
//! ```

use padnote_core::app::NotebookSession;
use padnote_core::doc::NotebookTime;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let root = std::env::args()
        .nth(1)
        .unwrap_or("/tmp/padnote-demo.padnote".into());
    let _ = std::fs::remove_dir_all(&root);

    let mut s = NotebookSession::create(&root, "示範筆記", 1_757_635_200_000, 0xA1)?;
    let page = s.first_page().expect("新筆記本必有一頁");

    s.advance_time(NotebookTime::from_micros(1_000_000));
    let rec = s.start_recording()?;
    s.add_text_block(
        page,
        "第三週：特徵值",
        padnote_core::doc::TextStyle::Heading2,
    )?;

    // 3 秒語音：1 秒有聲、1 秒靜音、1 秒有聲
    for (i, chunk) in [1, 0, 1].iter().enumerate() {
        let pcm: Vec<f32> = (0..16_000)
            .map(|n| {
                if *chunk == 1 {
                    (n as f32 * 2.0 * std::f32::consts::PI * 220.0 / 16_000.0).sin() * 0.5
                } else {
                    0.0
                }
            })
            .collect();
        s.advance_time(NotebookTime::from_micros(
            1_000_000 + (i as u64 + 1) * 1_000_000,
        ));
        let out = s.feed_audio(&pcm)?;
        println!(
            "  chunk {i}: {} 音框, {} 段入列",
            out.frames_written, out.segments_queued
        );
    }

    s.advance_time(NotebookTime::from_micros(4_000_000));
    s.stop_recording()?;

    println!("錄音 session: {rec}");
    println!("音檔時長: {} ms", s.recorded_audio_us() / 1_000);
    println!("套件位置: {root}");
    Ok(())
}
