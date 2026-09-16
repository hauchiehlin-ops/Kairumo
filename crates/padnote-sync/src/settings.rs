//! 跨裝置設定（G-04，ADR-0011）。
//!
//! # 這個模組真正的工作是「劃一條線」
//!
//! 同步設定聽起來只是把一個 JSON 上傳下載，難的是**哪些該同步**。
//! 分錯邊的兩種後果都很糟，而且都不會有錯誤訊息：
//!
//! - 該同步的沒同步 → 換一台裝置介面就變回英文、工具列回到預設，
//!   使用者以為設定沒存到。
//! - 不該同步的同步了 → iPad 上開著低延遲前緩衝，設定被推到一台
//!   舊 Android 上，那台機器根本沒有那個能力；或者把 iPad 的掌拒門檻
//!   套到手機上，握筆姿勢完全不同。更慘的是平台權限（SAF URI、
//!   security-scoped bookmark）—— 那些權杖換一台裝置就是無效的字串。
//!
//! 所以這裡不是「一個設定包」，而是**兩個**：[`SyncedSettings`] 會上雲，
//! [`DeviceSettings`] 永遠留在本機。型別分開，就不會有人手滑把它們寫進
//! 同一份 JSON。
//!
//! # 合併規則
//!
//! 每個欄位各自帶一個 Lamport 時戳（見 [`Stamped`]）。合併時逐欄位取較新的，
//! 平手時比裝置 id —— 兩台裝置同時改**不同**欄位，兩邊的改動都會留下來。
//! 整包用「最後寫入者勝」的話，A 改語言、B 改工具列，後上傳的那個會把
//! 另一個蓋掉。

use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;

/// 帶時戳的欄位值。
///
/// `lamport` 用同步引擎既有的邏輯時鐘，不是牆上時間 —— 裝置時鐘不同步是
/// 常態，用牆上時間會讓「時鐘快五分鐘的那台」永遠贏。
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct Stamped<T> {
    pub value: T,
    pub lamport: u64,
    /// 寫入者。時戳平手時用它決定勝負，讓結果與套用順序無關。
    pub device: String,
}

impl<T> Stamped<T> {
    pub fn new(value: T, lamport: u64, device: impl Into<String>) -> Self {
        Self {
            value,
            lamport,
            device: device.into(),
        }
    }

    /// 這一份是不是比 `other` 新。時戳相同時比裝置 id（字典序大的勝）。
    ///
    /// 一定要有一個**全序**的決勝規則：沒有的話，同一組輸入在兩台裝置上
    /// 可能收斂到不同結果，而那正是「同步看起來好了、其實沒有」的來源。
    fn wins_over<U>(&self, other: &Stamped<U>) -> bool {
        (self.lamport, &self.device) > (other.lamport, &other.device)
    }
}

/// 會跟著 Google 帳號走的設定。
#[derive(Clone, Debug, Default, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SyncedSettings {
    /// 介面語言（`padnote_i18n::Locale` 的字串形式）。
    pub locale: Option<Stamped<String>>,
    /// 工具列配置（`ToolbarConfig::to_json`）。
    pub toolbar_json: Option<Stamped<String>>,
    /// 預設筆刷：工具 id、顏色、粗細。
    pub default_pen: Option<Stamped<DefaultPen>>,
    /// 協同身分：顯示名稱與辨識色。
    pub identity: Option<Stamped<Identity>>,
    /// 尚未認得的欄位原樣保留。
    ///
    /// 新版新增一個設定之後，舊版**不可以在同步時把它吃掉** ——
    /// 否則使用者的兩台裝置只要版本不同，新設定就會一直被抹掉又寫回來。
    #[serde(flatten)]
    pub unknown: BTreeMap<String, serde_json::Value>,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct DefaultPen {
    pub tool_id: u16,
    /// `#RRGGBB`。
    pub color_hex: String,
    /// 存成千分之一，避免浮點數在 JSON 來回之後不相等
    /// —— 那會讓兩台裝置每次同步都以為對方改了設定。
    pub width_milli: u32,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Identity {
    pub display_name: String,
    pub color_hex: String,
}

impl SyncedSettings {
    /// 合併另一台裝置的設定，逐欄位取新的。
    ///
    /// 這個運算必須是**可交換且冪等**的：套用順序不影響結果，重複套用也不會
    /// 改變結果。同步引擎不保證誰先到，也不保證只送一次。
    pub fn merge(&mut self, other: &SyncedSettings) {
        merge_field(&mut self.locale, &other.locale);
        merge_field(&mut self.toolbar_json, &other.toolbar_json);
        merge_field(&mut self.default_pen, &other.default_pen);
        merge_field(&mut self.identity, &other.identity);
        for (k, v) in &other.unknown {
            self.unknown.entry(k.clone()).or_insert_with(|| v.clone());
        }
    }

    pub fn to_json(&self) -> String {
        serde_json::to_string_pretty(self).unwrap_or_else(|_| "{}".into())
    }

    /// 解析。壞掉的 JSON 回預設值而不是錯誤 —— 雲端上的一份壞檔案
    /// 不該讓使用者整個 App 進不去設定。
    pub fn from_json(text: &str) -> Self {
        serde_json::from_str(text).unwrap_or_default()
    }
}

fn merge_field<T: Clone>(mine: &mut Option<Stamped<T>>, theirs: &Option<Stamped<T>>) {
    let Some(theirs) = theirs else { return };
    match mine {
        Some(current) if current.wins_over(theirs) => {}
        _ => *mine = Some(theirs.clone()),
    }
}

/// **永遠不上雲**的設定。
///
/// 這個型別存在的意義就是讓「不要同步」這件事寫在型別上，而不是寫在註解裡。
/// 它刻意沒有 `merge()`，也刻意不放進 [`SyncedSettings`]。
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct DeviceSettings {
    /// 低延遲前緩衝。不是每台裝置都做得到，也不是每台都該開。
    pub low_latency: bool,
    /// 僅限觸控筆。
    pub pen_only: bool,
    /// 掌拒的手掌半徑門檻（dp）。握筆姿勢與螢幕大小因裝置而異。
    pub palm_radius_dp: f32,
    /// 掌拒的收回時間窗（毫秒）。
    pub palm_retract_window_ms: u32,
    /// 手動同步資料夾的平台權限權杖（Android SAF URI / Apple bookmark）。
    ///
    /// **換一台裝置就是一串無效字串。** 同步它不只是沒用，還會讓另一台
    /// 裝置以為自己有權限，然後在存檔時才失敗。
    pub folder_permission_token: Option<String>,
    /// 這台裝置的 id。每次安裝一個，重裝就是新裝置（ADR-0011）。
    pub device_id: String,
}

impl DeviceSettings {
    pub fn new(device_id: impl Into<String>) -> Self {
        Self {
            low_latency: true,
            pen_only: false,
            palm_radius_dp: 22.0,
            palm_retract_window_ms: 500,
            folder_permission_token: None,
            device_id: device_id.into(),
        }
    }
}

/// 雲端上放全域設定的路徑（`format-spec.md` §7.0）。
pub const SETTINGS_PATH: &str = "settings/global.json";

#[cfg(test)]
mod tests {
    use super::*;

    fn pen(width: u32) -> DefaultPen {
        DefaultPen {
            tool_id: 1,
            color_hex: "#000000".into(),
            width_milli: width,
        }
    }

    #[test]
    fn newer_stamp_wins() {
        let mut a = SyncedSettings {
            locale: Some(Stamped::new("zh-Hant".into(), 1, "dev-a")),
            ..Default::default()
        };
        let b = SyncedSettings {
            locale: Some(Stamped::new("ja".into(), 2, "dev-b")),
            ..Default::default()
        };
        a.merge(&b);
        assert_eq!(a.locale.unwrap().value, "ja");
    }

    #[test]
    fn older_stamp_does_not_overwrite() {
        let mut a = SyncedSettings {
            locale: Some(Stamped::new("ja".into(), 5, "dev-a")),
            ..Default::default()
        };
        let b = SyncedSettings {
            locale: Some(Stamped::new("zh-Hant".into(), 2, "dev-b")),
            ..Default::default()
        };
        a.merge(&b);
        assert_eq!(a.locale.unwrap().value, "ja");
    }

    #[test]
    fn edits_to_different_fields_both_survive() {
        // 整包「最後寫入者勝」的話，A 改語言、B 改工具列，
        // 後上傳的那個會把另一個蓋掉。逐欄位合併才不會。
        let mut a = SyncedSettings {
            locale: Some(Stamped::new("ja".into(), 3, "dev-a")),
            ..Default::default()
        };
        let b = SyncedSettings {
            toolbar_json: Some(Stamped::new("{\"x\":1}".into(), 4, "dev-b")),
            ..Default::default()
        };
        a.merge(&b);
        assert_eq!(a.locale.as_ref().unwrap().value, "ja");
        assert_eq!(a.toolbar_json.as_ref().unwrap().value, "{\"x\":1}");
    }

    #[test]
    fn merge_is_commutative_and_idempotent() {
        // 同步引擎不保證誰先到，也不保證只送一次。
        let a = SyncedSettings {
            locale: Some(Stamped::new("ja".into(), 3, "dev-a")),
            default_pen: Some(Stamped::new(pen(3000), 1, "dev-a")),
            ..Default::default()
        };
        let b = SyncedSettings {
            locale: Some(Stamped::new("ko".into(), 4, "dev-b")),
            default_pen: Some(Stamped::new(pen(1500), 9, "dev-b")),
            ..Default::default()
        };

        let mut ab = a.clone();
        ab.merge(&b);
        let mut ba = b.clone();
        ba.merge(&a);
        assert_eq!(ab, ba, "合併必須可交換");

        let mut twice = ab.clone();
        twice.merge(&b);
        twice.merge(&a);
        assert_eq!(ab, twice, "合併必須冪等");
    }

    #[test]
    fn a_tie_is_broken_the_same_way_on_both_devices() {
        // 時戳一樣時如果沒有全序決勝，兩台裝置會收斂到不同結果 ——
        // 「同步看起來好了、其實沒有」就是這樣來的。
        let a = SyncedSettings {
            locale: Some(Stamped::new("ja".into(), 7, "dev-a")),
            ..Default::default()
        };
        let b = SyncedSettings {
            locale: Some(Stamped::new("ko".into(), 7, "dev-b")),
            ..Default::default()
        };
        let mut ab = a.clone();
        ab.merge(&b);
        let mut ba = b.clone();
        ba.merge(&a);
        assert_eq!(ab.locale.unwrap().value, ba.locale.unwrap().value);
    }

    #[test]
    fn unknown_fields_survive_a_round_trip_through_an_older_build() {
        // 舊版不認得新設定，但**不可以把它吃掉** —— 否則兩台裝置版本不同時，
        // 新設定會一直被抹掉又寫回來。
        let json =
            r#"{"locale":{"value":"ja","lamport":1,"device":"a"},"futureThing":{"deep":42}}"#;
        let parsed = SyncedSettings::from_json(json);
        assert!(parsed.unknown.contains_key("futureThing"));
        let round = SyncedSettings::from_json(&parsed.to_json());
        assert_eq!(round.unknown["futureThing"]["deep"], 42);
    }

    #[test]
    fn broken_json_falls_back_instead_of_failing() {
        // 雲端上一份壞檔案不該讓使用者整個進不去設定。
        assert_eq!(
            SyncedSettings::from_json("not json at all"),
            SyncedSettings::default()
        );
        assert_eq!(SyncedSettings::from_json(""), SyncedSettings::default());
    }

    #[test]
    fn device_settings_are_not_part_of_the_synced_payload() {
        // 這個測試是這個模組的重點：裝置本地設定連**序列化**都不該出現在
        // 同步 JSON 裡。低延遲、掌拒門檻、SAF 權限權杖被推到另一台裝置，
        // 症狀是「另一台突然畫不出字」或「存檔權限失效」。
        let synced = SyncedSettings {
            locale: Some(Stamped::new("ja".into(), 1, "dev-a")),
            toolbar_json: Some(Stamped::new("{}".into(), 1, "dev-a")),
            default_pen: Some(Stamped::new(pen(2000), 1, "dev-a")),
            identity: Some(Stamped::new(
                Identity {
                    display_name: "Bo".into(),
                    color_hex: "#007AFF".into(),
                },
                1,
                "dev-a",
            )),
            ..Default::default()
        };
        let json = synced.to_json();
        for forbidden in [
            "lowLatency",
            "penOnly",
            "palmRadiusDp",
            "palmRetractWindowMs",
            "folderPermissionToken",
            "deviceId",
        ] {
            assert!(!json.contains(forbidden), "{forbidden} 不該被同步：{json}");
        }
    }

    #[test]
    fn pen_width_survives_a_json_round_trip_exactly() {
        // 用浮點數存粗細的話，JSON 來回之後可能不相等，
        // 兩台裝置就會每次同步都以為對方改了設定，無限互相覆蓋。
        let original = SyncedSettings {
            default_pen: Some(Stamped::new(pen(3333), 1, "dev-a")),
            ..Default::default()
        };
        let round = SyncedSettings::from_json(&original.to_json());
        assert_eq!(original, round);
    }
}
