//! 用 FunASR 官方的範例音檔比對 Rust 實作與 Python 參考輸出。
//!
//! 這是整條管線唯一真正端到端的測試：WAV → fbank → LFR → CMVN → encoder
//! → CIF → decoder → 文字。前面每一層都有單元測試，但只有這裡能證明
//! 它們串起來真的能辨識中文。
//!
//! 模型或音檔缺席時跳過（兩者都不入版控）。

use padnote_asr::AsrEngine;
use padnote_asr_paraformer::engine::{ModelPaths, ParaformerEngine};

/// FunASR 的 Python 實作（fp32 PyTorch）對同一音檔的輸出。
const FUNASR_REFERENCE: &str = "欢迎大家来体验达摩院推出的语音识别模型这ca";

fn model_dir() -> Option<std::path::PathBuf> {
    let d = std::path::Path::new(env!("CARGO_MANIFEST_DIR"))
        .join("../../models/exported-int8/paraformer-zh-streaming");
    ModelPaths::in_dir(&d).encoder.exists().then_some(d)
}

/// 官方範例音檔位於 HuggingFace 快取中。
fn example_wav() -> Option<std::path::PathBuf> {
    let home = std::env::var("HOME").ok()?;
    let base = std::path::Path::new(&home)
        .join(".cache/huggingface/hub/models--funasr--paraformer-zh-streaming/snapshots");
    std::fs::read_dir(base)
        .ok()?
        .filter_map(Result::ok)
        .find_map(|e| {
            let p = e.path().join("example/asr_example.wav");
            p.exists().then_some(p)
        })
}

fn read_wav_16k(path: &std::path::Path) -> Option<Vec<f32>> {
    let bytes = std::fs::read(path).ok()?;
    let mut pos = 12usize;
    while pos + 8 <= bytes.len() {
        let id = &bytes[pos..pos + 4];
        let size = u32::from_le_bytes(bytes[pos + 4..pos + 8].try_into().ok()?) as usize;
        let body = pos + 8;
        if id == b"data" {
            let end = (body + size).min(bytes.len());
            return Some(
                bytes[body..end]
                    .as_chunks::<2>()
                    .0
                    .iter()
                    .map(|c| i16::from_le_bytes([c[0], c[1]]) as f32 / 32_768.0)
                    .collect(),
            );
        }
        pos = body + size + (size & 1);
    }
    None
}

fn transcribe_whole(pcm: &[f32]) -> String {
    let mut e = ParaformerEngine::load(&ModelPaths::in_dir(model_dir().unwrap())).unwrap();
    // 預設即整段處理：feed 只累積，finish 才辨識。
    e.feed(pcm).unwrap();
    e.finish().unwrap().into_iter().map(|s| s.text).collect()
}

#[test]
fn transcribes_the_official_example_close_to_funasr() {
    let (Some(_), Some(wav)) = (model_dir(), example_wav()) else {
        return;
    };
    let pcm = read_wav_16k(&wav).expect("應能讀取 WAV");
    let got = transcribe_whole(&pcm);

    eprintln!("  Rust  : {got}");
    eprintln!("  FunASR: {FUNASR_REFERENCE}");

    let cer = padnote_bench::cer(FUNASR_REFERENCE, &got);
    eprintln!("  CER   : {:.1}%", cer * 100.0);

    // 與 fp32 PyTorch 的差異主要來自 int8 量化。門檻訂 20%：
    // 高於此代表管線某一層真的錯了，而不只是量化誤差。
    assert!(
        cer < 0.20,
        "與 FunASR 的差異過大（CER {:.1}%）——\n  得到：{got}\n  期望：{FUNASR_REFERENCE}",
        cer * 100.0
    );
}

#[test]
fn recognises_the_key_phrases() {
    // CER 是總體指標；這裡確認關鍵詞真的被辨識出來，
    // 避免「整體相近但重要內容全錯」的情況。
    let (Some(_), Some(wav)) = (model_dir(), example_wav()) else {
        return;
    };
    let got = transcribe_whole(&read_wav_16k(&wav).unwrap());

    for phrase in ["欢迎大家", "体验", "语音识别", "模型"] {
        assert!(got.contains(phrase), "未辨識出「{phrase}」：{got}");
    }
}

#[test]
fn transcription_is_reproducible() {
    // 同一段音訊必須得到相同結果。FunASR 預設的 dither=1.0 會破壞這點，
    // 因此我們的前端把它關掉了（frontend.rs 有說明）。
    let (Some(_), Some(wav)) = (model_dir(), example_wav()) else {
        return;
    };
    let pcm = read_wav_16k(&wav).unwrap();
    assert_eq!(transcribe_whole(&pcm), transcribe_whole(&pcm));
}
