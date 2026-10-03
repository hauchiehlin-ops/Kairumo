//! ASR A/B 對照評估工具（docs/plans/recording-quality.md §4）。
//!
//! 用法：
//! ```bash
//! cargo run -p padnote-bench --bin asr-ab -- baseline.tsv experiment.tsv
//! ```
//!
//! 比較兩組轉錄結果（例如：原始 vs +降噪 或 原始 vs +高通/AGC）：
//! - 各場景分別計算 CER(A) 與 CER(B)
//! - 只有在至少一個場景 CER 有改善，且**其他場景皆無劣化**時，才判定為適合預設開啟。

use padnote_bench::{ScoreReport, parse_tsv};

fn main() -> std::process::ExitCode {
    let args: Vec<String> = std::env::args().collect();
    if args.len() < 3 {
        eprintln!("用法：asr-ab <baseline.tsv> <experiment.tsv>");
        return std::process::ExitCode::from(2);
    }

    let read_file = |path: &str| -> Result<Vec<padnote_bench::Utterance>, String> {
        let text = std::fs::read_to_string(path).map_err(|e| format!("讀取 {path} 失敗：{e}"))?;
        parse_tsv(&text).map_err(|e| format!("解析 {path} 失敗：{e}"))
    };

    let base_utts = match read_file(&args[1]) {
        Ok(u) => u,
        Err(e) => {
            eprintln!("{e}");
            return std::process::ExitCode::from(2);
        }
    };

    let exp_utts = match read_file(&args[2]) {
        Ok(u) => u,
        Err(e) => {
            eprintln!("{e}");
            return std::process::ExitCode::from(2);
        }
    };

    let rep_a = ScoreReport::compute(&base_utts);
    let rep_b = ScoreReport::compute(&exp_utts);

    println!("=== A/B 評估報告 ===");
    println!("Baseline (A):   {}", args[1]);
    println!("Experiment (B): {}\n", args[2]);

    println!(
        "{:<14} {:>10} {:>10} {:>10} {:>10}",
        "場景", "A CER", "B CER", "變化 (Δ)", "判定"
    );
    println!("{}", "-".repeat(58));

    let mut any_improved = false;
    let mut any_degraded = false;

    // 比對各場景
    let mut scenarios = rep_a.by_scenario.keys().collect::<Vec<_>>();
    for s in rep_b.by_scenario.keys() {
        if !scenarios.contains(&s) {
            scenarios.push(s);
        }
    }
    scenarios.sort();

    for s in scenarios {
        let stats_a = rep_a.by_scenario.get(s);
        let stats_b = rep_b.by_scenario.get(s);

        let cer_a = stats_a.map(|st| st.0).unwrap_or(0.0);
        let cer_b = stats_b.map(|st| st.0).unwrap_or(0.0);
        let delta = cer_b - cer_a; // 負值代表改善

        let verdict = if delta < -0.005 {
            any_improved = true;
            "改善 ✅"
        } else if delta > 0.005 {
            any_degraded = true;
            "劣化 ❌"
        } else {
            "持平 ➖"
        };

        println!(
            "{:<14} {:>9.2}% {:>9.2}% {:>+9.2}% {:>10}",
            s.to_string(),
            cer_a * 100.0,
            cer_b * 100.0,
            delta * 100.0,
            verdict
        );
    }

    println!();
    if any_degraded {
        println!(
            "⚠️ 警告：實驗組在部分場景出現 CER 劣化。降噪常產生人工痕跡，依專案規範不得預設開啟，僅供選用。"
        );
        std::process::ExitCode::FAILURE
    } else if any_improved {
        println!("✅ 通過：實驗組在無劣化情況下實現有效改善。");
        std::process::ExitCode::SUCCESS
    } else {
        println!("➖ 無顯著差異。");
        std::process::ExitCode::SUCCESS
    }
}
