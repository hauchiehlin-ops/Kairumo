//! ASR CER 評分工具（M0/S2 的 Go/No-Go 判定器，後續作為 CI 閘門）。
//!
//! ```bash
//! cargo run -p padnote-bench --bin asr-score -- crates/padnote-bench/fixtures/sample.tsv
//! ```
//! 任一場景超出門檻即以非零碼結束 ⇒ 可直接掛進 CI。

use padnote_bench::{ScoreReport, parse_tsv};

fn main() -> std::process::ExitCode {
    let Some(path) = std::env::args().nth(1) else {
        eprintln!("用法：asr-score <fixtures.tsv>");
        return std::process::ExitCode::from(2);
    };

    let text = match std::fs::read_to_string(&path) {
        Ok(t) => t,
        Err(e) => {
            eprintln!("讀取 {path} 失敗：{e}");
            return std::process::ExitCode::from(2);
        }
    };

    let utterances = match parse_tsv(&text) {
        Ok(u) => u,
        Err(e) => {
            eprintln!("解析失敗：{e}");
            return std::process::ExitCode::from(2);
        }
    };

    if utterances.is_empty() {
        eprintln!("測試集是空的 —— 無法判定，視為失敗");
        return std::process::ExitCode::FAILURE;
    }

    let report = ScoreReport::compute(&utterances);
    print!("{report}");

    let failures = report.failures();
    if failures.is_empty() {
        println!("\n全部場景通過 M0/S2 門檻。");
        std::process::ExitCode::SUCCESS
    } else {
        println!();
        for (s, rate, t) in failures {
            println!("未達門檻：{s} CER {:.2}% > {:.1}%", rate * 100.0, t * 100.0);
        }
        std::process::ExitCode::FAILURE
    }
}
