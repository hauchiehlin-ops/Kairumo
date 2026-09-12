//! ASR 評測報告（M0/S2）。
//!
//! 測試集格式為 TSV，刻意不用 JSON —— 無外部相依、diff 友善、標註者可用試算表編輯。
//!
//! ```text
//! scenario<TAB>id<TAB>reference<TAB>hypothesis
//! quiet	lec001	線性代數的特徵值	線性代數的特徵值
//! noisy	mtg014	下週三開會	下週三開\u{6703}
//! ```

use crate::cer::cer;
use std::collections::BTreeMap;
use std::fmt;

/// 錄音場景。門檻依場景不同 —— 嘈雜環境本來就該放寬，混在一起算會掩蓋問題。
#[derive(Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Debug)]
pub enum Scenario {
    /// 安靜教室、近場麥克風
    Quiet,
    /// 背景噪音、多人交談、遠場
    Noisy,
    /// 中英夾雜（C9）
    CodeSwitch,
}

impl Scenario {
    pub fn parse(s: &str) -> Option<Self> {
        Some(match s {
            "quiet" => Self::Quiet,
            "noisy" => Self::Noisy,
            "codeswitch" => Self::CodeSwitch,
            _ => return None,
        })
    }

    /// M0/S2 Go 門檻（`docs/roadmap.md`）。
    pub fn cer_threshold(self) -> f64 {
        match self {
            Self::Quiet => 0.08,
            Self::Noisy => 0.18,
            Self::CodeSwitch => 0.15,
        }
    }
}

impl fmt::Display for Scenario {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let s = match self {
            Self::Quiet => "quiet",
            Self::Noisy => "noisy",
            Self::CodeSwitch => "codeswitch",
        };
        // 必須用 `pad` 而非 `write_str`，否則 `{:<12}` 的寬度指定會被忽略。
        f.pad(s)
    }
}

#[derive(Clone, Debug)]
pub struct Utterance {
    pub scenario: Scenario,
    pub id: String,
    pub reference: String,
    pub hypothesis: String,
}

/// 解析 TSV。`#` 開頭與空行為註解。格式錯誤回報行號，不靜默略過。
pub fn parse_tsv(text: &str) -> Result<Vec<Utterance>, String> {
    let mut out = Vec::new();
    for (i, line) in text.lines().enumerate() {
        let line = line.trim_end_matches('\r');
        if line.trim().is_empty() || line.starts_with('#') {
            continue;
        }
        let cols: Vec<&str> = line.split('\t').collect();
        if cols.len() != 4 {
            return Err(format!(
                "第 {} 行：預期 4 個欄位，實得 {}",
                i + 1,
                cols.len()
            ));
        }
        let scenario = Scenario::parse(cols[0])
            .ok_or_else(|| format!("第 {} 行：未知場景 {:?}", i + 1, cols[0]))?;
        out.push(Utterance {
            scenario,
            id: cols[1].to_string(),
            reference: cols[2].to_string(),
            hypothesis: cols[3].to_string(),
        });
    }
    Ok(out)
}

/// 依場景彙總的 CER 報告。
#[derive(Debug, Default)]
pub struct ScoreReport {
    /// scenario → (加權 CER, 語句數)
    pub by_scenario: BTreeMap<Scenario, (f64, usize)>,
    /// CER 最高的前幾句，供人工檢視
    pub worst: Vec<(String, f64)>,
}

impl ScoreReport {
    pub fn compute(utterances: &[Utterance]) -> Self {
        // 依字元數加權，避免短句主導平均值。
        let mut acc: BTreeMap<Scenario, (usize, usize, usize)> = BTreeMap::new();
        let mut worst: Vec<(String, f64)> = Vec::new();

        for u in utterances {
            let dist = crate::cer::edit_distance(&u.reference, &u.hypothesis);
            let len = u.reference.chars().count();
            let e = acc.entry(u.scenario).or_insert((0, 0, 0));
            e.0 += dist;
            e.1 += len;
            e.2 += 1;
            worst.push((u.id.clone(), cer(&u.reference, &u.hypothesis)));
        }

        worst.sort_by(|a, b| b.1.total_cmp(&a.1));
        worst.truncate(10);

        Self {
            by_scenario: acc
                .into_iter()
                .map(|(s, (d, l, n))| {
                    let rate = if l == 0 { 0.0 } else { d as f64 / l as f64 };
                    (s, (rate, n))
                })
                .collect(),
            worst,
        }
    }

    /// 是否全部場景通過門檻。回傳未通過的場景清單。
    pub fn failures(&self) -> Vec<(Scenario, f64, f64)> {
        self.by_scenario
            .iter()
            .filter_map(|(&s, &(rate, _))| {
                (rate > s.cer_threshold()).then_some((s, rate, s.cer_threshold()))
            })
            .collect()
    }
}

impl fmt::Display for ScoreReport {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        // 表頭用 ASCII：CJK 字元的顯示寬度是 2，用 `{:<n}` 對齊會跑掉。
        writeln!(
            f,
            "{:<12} {:>6}   {:>7}  {:>6}   {}",
            "scenario", "n", "CER", "limit", "result"
        )?;
        writeln!(f, "{}", "-".repeat(46))?;
        for (&s, &(rate, n)) in &self.by_scenario {
            let t = s.cer_threshold();
            let mark = if rate <= t { "PASS" } else { "FAIL" };
            writeln!(
                f,
                "{s:<12} {n:>6}   {:>6.2}%  {:>5.1}%   {mark}",
                rate * 100.0,
                t * 100.0
            )?;
        }
        if !self.worst.is_empty() {
            writeln!(f, "\nworst utterances:")?;
            for (id, rate) in &self.worst {
                writeln!(f, "  {id:<16} {:>6.2}%", rate * 100.0)?;
            }
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_valid_tsv() {
        let t = "# 註解\n\nquiet\tl1\t線性代數\t線性代數\nnoisy\tm1\t開會\t開回\n";
        let u = parse_tsv(t).unwrap();
        assert_eq!(u.len(), 2);
        assert_eq!(u[0].scenario, Scenario::Quiet);
        assert_eq!(u[1].id, "m1");
    }

    #[test]
    fn reports_malformed_line_number() {
        let err = parse_tsv("quiet\tonly\tthree").unwrap_err();
        assert!(err.contains("第 1 行"), "{err}");
    }

    #[test]
    fn rejects_unknown_scenario() {
        assert!(parse_tsv("unknown\ta\tb\tc").is_err());
    }

    #[test]
    fn cer_is_weighted_by_reference_length() {
        // 長句全對 + 短句全錯：加權後應接近 短句長度/總長度，而非 50%
        let u = parse_tsv(
            "quiet\tlong\t這是一個很長的參考句子總共十五字\t這是一個很長的參考句子總共十五字\n\
             quiet\tshort\t錯\t對\n",
        )
        .unwrap();
        let r = ScoreReport::compute(&u);
        let (rate, n) = r.by_scenario[&Scenario::Quiet];
        assert_eq!(n, 2);
        assert!(rate < 0.1, "加權後應遠低於 50%，得到 {rate}");
    }

    #[test]
    fn failures_respect_per_scenario_thresholds() {
        // 12% CER：安靜場景該當掉，嘈雜場景該通過
        let quiet = parse_tsv("quiet\ta\t一二三四五六七八\t一二三四五六七X\n").unwrap();
        assert!(
            !ScoreReport::compute(&quiet).failures().is_empty(),
            "12.5% > 8% 門檻，安靜場景應失敗"
        );

        let noisy = parse_tsv("noisy\ta\t一二三四五六七八\t一二三四五六七X\n").unwrap();
        assert!(
            ScoreReport::compute(&noisy).failures().is_empty(),
            "12.5% < 18% 門檻，嘈雜場景應通過"
        );
    }

    #[test]
    fn perfect_transcription_passes_everything() {
        let u = parse_tsv("quiet\ta\t完全正確\t完全正確\n").unwrap();
        let r = ScoreReport::compute(&u);
        assert!(r.failures().is_empty());
        assert_eq!(r.by_scenario[&Scenario::Quiet].0, 0.0);
    }
}
