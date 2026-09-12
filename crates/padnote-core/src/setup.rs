//! 引擎與權限中心（功能 I1）。
//!
//! 一頁列出所有引擎、模型與權限的即時狀態，需要動作時給一個按鈕。
//!
//! ## 為什麼不是「一鍵申請 API key」
//! Apple Vision 與 ML Kit Digital Ink 都是**純裝置端、免費、免註冊**的系統框架，
//! 不需要任何 API key。真正需要使用者動作的是：麥克風／語音辨識權限、
//! iCloud 容器、Google Drive 授權、同步資料夾選擇、以及模型下載。
//! 因此這裡建模的是**權限與資源**，不是金鑰申請。
//!
//! ## 為什麼放在 core 而不是各平台 UI
//! 「錄音要不要麥克風權限」「轉錄缺哪個模型」這類判斷邏輯若寫在 Swift，
//! Android 版就要重寫一遍，兩邊必然長歪。狀態機在 core，UI 只負責畫。

use std::collections::BTreeMap;
use std::fmt;

/// 一項需要就緒才能用的能力。
#[derive(Clone, PartialEq, Eq, PartialOrd, Ord, Debug)]
pub enum Capability {
    Microphone,
    /// 平台的語音辨識權限（iOS 的 Speech framework）
    SpeechPermission,
    /// 手寫辨識引擎
    Handwriting,
    /// 本機 ASR 模型
    AsrModel(String),
    /// 本機 LLM 模型（摘要、待辦抽取）
    LlmModel(String),
    /// 本機同步資料夾（決策 D3 首選）
    LocalSyncFolder,
    ICloudDrive,
    GoogleDrive,
}

impl fmt::Display for Capability {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Microphone => f.write_str("麥克風"),
            Self::SpeechPermission => f.write_str("語音辨識權限"),
            Self::Handwriting => f.write_str("手寫辨識"),
            Self::AsrModel(id) => write!(f, "語音模型（{id}）"),
            Self::LlmModel(id) => write!(f, "AI 模型（{id}）"),
            Self::LocalSyncFolder => f.write_str("本機同步資料夾"),
            Self::ICloudDrive => f.write_str("iCloud Drive"),
            Self::GoogleDrive => f.write_str("Google Drive"),
        }
    }
}

/// 使用者可以做的一個動作。UI 把它畫成按鈕。
#[derive(Clone, PartialEq, Eq, Debug)]
pub enum SetupAction {
    /// 跳出系統權限請求
    RequestPermission,
    /// 權限被拒 ⇒ 只能引導去系統設定，App 內無法再次請求
    OpenSystemSettings,
    /// 下載模型
    Download { size_bytes: u64 },
    /// 選擇本機資料夾
    ChooseFolder,
    /// 走 OAuth 授權
    Authorize,
}

#[derive(Clone, PartialEq, Eq, Debug)]
pub enum Status {
    Ready,
    /// 尚未詢問過使用者
    NeedsPermission,
    /// 使用者拒絕過。**不能再彈系統對話框**，只能引導到設定。
    PermissionDenied,
    NeedsDownload {
        size_bytes: u64,
    },
    Downloading {
        progress_percent: u8,
    },
    /// 尚未設定（例如還沒選同步資料夾）
    NotConfigured,
    /// 此平台不支援
    Unsupported,
    Failed(String),
}

impl Status {
    pub fn is_ready(&self) -> bool {
        matches!(self, Self::Ready)
    }

    /// 對應的使用者動作。`None` 表示沒事可做（已就緒、進行中、或平台不支援）。
    pub fn action(&self) -> Option<SetupAction> {
        match self {
            Self::NeedsPermission => Some(SetupAction::RequestPermission),
            // 被拒絕後再彈對話框系統會直接忽略，只能送去設定。
            Self::PermissionDenied => Some(SetupAction::OpenSystemSettings),
            Self::NeedsDownload { size_bytes } => Some(SetupAction::Download {
                size_bytes: *size_bytes,
            }),
            Self::NotConfigured => Some(SetupAction::ChooseFolder),
            Self::Failed(_) => Some(SetupAction::RequestPermission),
            Self::Ready | Self::Downloading { .. } | Self::Unsupported => None,
        }
    }
}

/// 產品功能。用來回答「這個功能現在能不能用、不能的話缺什麼」。
#[derive(Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Debug)]
pub enum Feature {
    /// 手寫、打字 —— **永遠可用**，不依賴任何權限或模型
    CoreNotes,
    /// 錄音（C6）
    Recording,
    /// 即時轉錄（C2）
    LiveTranscription,
    /// 手寫轉文字（D1）
    HandwritingToText,
    /// AI 摘要（D5）
    AiSummary,
    /// 跨裝置同步（G2/G3/G4）
    Sync,
}

impl Feature {
    /// 此功能所需的能力。
    pub fn requirements(&self, asr_model: &str, llm_model: &str) -> Vec<Capability> {
        match self {
            // 三大核心需求中的兩項不依賴任何外部資源 —— 這是刻意的設計。
            Self::CoreNotes => vec![],
            Self::Recording => vec![Capability::Microphone],
            Self::LiveTranscription => vec![
                Capability::Microphone,
                Capability::SpeechPermission,
                Capability::AsrModel(asr_model.into()),
            ],
            Self::HandwritingToText => vec![Capability::Handwriting],
            Self::AiSummary => vec![Capability::LlmModel(llm_model.into())],
            Self::Sync => vec![Capability::LocalSyncFolder],
        }
    }
}

/// 某功能的就緒狀況。
#[derive(Clone, Debug)]
pub struct FeatureReadiness {
    pub feature: Feature,
    pub ready: bool,
    /// 尚未就緒的能力與其狀態。
    pub blocking: Vec<(Capability, Status)>,
}

impl FeatureReadiness {
    /// 給使用者看的一句話說明。
    pub fn explanation(&self) -> String {
        if self.ready {
            return "可以使用".into();
        }
        let names: Vec<String> = self.blocking.iter().map(|(c, _)| c.to_string()).collect();
        format!("需要：{}", names.join("、"))
    }
}

/// 引擎與權限中心。
#[derive(Debug, Default)]
pub struct SetupCenter {
    statuses: BTreeMap<Capability, Status>,
    asr_model: String,
    llm_model: String,
}

impl SetupCenter {
    pub fn new(asr_model: impl Into<String>, llm_model: impl Into<String>) -> Self {
        Self {
            statuses: BTreeMap::new(),
            asr_model: asr_model.into(),
            llm_model: llm_model.into(),
        }
    }

    /// 平台層回報狀態變化。
    pub fn set(&mut self, cap: Capability, status: Status) {
        self.statuses.insert(cap, status);
    }

    /// 未回報過的能力視為 `Unsupported`，而不是樂觀地當成 Ready ——
    /// 樂觀假設會讓功能在執行期才爆炸。
    pub fn status(&self, cap: &Capability) -> Status {
        self.statuses
            .get(cap)
            .cloned()
            .unwrap_or(Status::Unsupported)
    }

    /// 所有項目與其狀態，供設定頁列表。
    pub fn entries(&self) -> Vec<(&Capability, &Status)> {
        self.statuses.iter().collect()
    }

    /// 需要使用者處理的項目 —— UI 在這些項目旁顯示按鈕。
    pub fn pending_actions(&self) -> Vec<(Capability, SetupAction)> {
        self.statuses
            .iter()
            .filter_map(|(c, s)| s.action().map(|a| (c.clone(), a)))
            .collect()
    }

    pub fn readiness(&self, feature: Feature) -> FeatureReadiness {
        let blocking: Vec<(Capability, Status)> = feature
            .requirements(&self.asr_model, &self.llm_model)
            .into_iter()
            .filter_map(|c| {
                let s = self.status(&c);
                (!s.is_ready()).then_some((c, s))
            })
            .collect();

        FeatureReadiness {
            feature,
            ready: blocking.is_empty(),
            blocking,
        }
    }

    /// 全部功能的就緒狀況。
    pub fn all_readiness(&self) -> Vec<FeatureReadiness> {
        [
            Feature::CoreNotes,
            Feature::Recording,
            Feature::LiveTranscription,
            Feature::HandwritingToText,
            Feature::AiSummary,
            Feature::Sync,
        ]
        .into_iter()
        .map(|f| self.readiness(f))
        .collect()
    }

    /// 需要下載的總位元組數。裝置空間不足時要先警告使用者。
    pub fn total_download_bytes(&self) -> u64 {
        self.statuses
            .values()
            .filter_map(|s| match s {
                Status::NeedsDownload { size_bytes } => Some(*size_bytes),
                _ => None,
            })
            .sum()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn center() -> SetupCenter {
        SetupCenter::new("paraformer-zh", "qwen3-4b")
    }

    #[test]
    fn core_notes_never_need_anything() {
        // 手寫與打字不依賴任何權限或模型 —— 這是產品定位的基石。
        let c = center();
        let r = c.readiness(Feature::CoreNotes);
        assert!(r.ready, "全新安裝、零權限時核心筆記就該能用");
        assert!(r.blocking.is_empty());
    }

    #[test]
    fn unreported_capability_is_unsupported_not_ready() {
        // 樂觀假設會讓功能在執行期才爆炸。
        assert_eq!(
            center().status(&Capability::Microphone),
            Status::Unsupported
        );
        assert!(!center().readiness(Feature::Recording).ready);
    }

    #[test]
    fn recording_needs_only_the_microphone() {
        let mut c = center();
        c.set(Capability::Microphone, Status::Ready);
        assert!(c.readiness(Feature::Recording).ready);

        // 但即時轉錄還缺模型與語音權限
        assert!(!c.readiness(Feature::LiveTranscription).ready);
    }

    #[test]
    fn live_transcription_lists_everything_still_missing() {
        let mut c = center();
        c.set(Capability::Microphone, Status::Ready);

        let r = c.readiness(Feature::LiveTranscription);
        assert_eq!(r.blocking.len(), 2);
        assert!(r.explanation().contains("語音辨識權限"));
        assert!(r.explanation().contains("paraformer-zh"));
    }

    #[test]
    fn fully_configured_transcription_is_ready() {
        let mut c = center();
        c.set(Capability::Microphone, Status::Ready);
        c.set(Capability::SpeechPermission, Status::Ready);
        c.set(Capability::AsrModel("paraformer-zh".into()), Status::Ready);

        let r = c.readiness(Feature::LiveTranscription);
        assert!(r.ready);
        assert_eq!(r.explanation(), "可以使用");
    }

    #[test]
    fn denied_permission_sends_user_to_settings_not_a_dialog() {
        // 被拒絕後再彈系統對話框會被直接忽略，使用者只會覺得按鈕壞了。
        let mut c = center();
        c.set(Capability::Microphone, Status::PermissionDenied);

        assert_eq!(
            c.status(&Capability::Microphone).action(),
            Some(SetupAction::OpenSystemSettings)
        );
    }

    #[test]
    fn first_time_permission_offers_the_system_prompt() {
        let mut c = center();
        c.set(Capability::Microphone, Status::NeedsPermission);
        assert_eq!(
            c.status(&Capability::Microphone).action(),
            Some(SetupAction::RequestPermission)
        );
    }

    #[test]
    fn ready_and_in_progress_items_offer_no_action() {
        assert_eq!(Status::Ready.action(), None);
        assert_eq!(
            Status::Downloading {
                progress_percent: 40
            }
            .action(),
            None
        );
        assert_eq!(Status::Unsupported.action(), None, "平台不支援時按鈕該消失");
    }

    #[test]
    fn pending_actions_drive_the_settings_page() {
        let mut c = center();
        c.set(Capability::Microphone, Status::Ready);
        c.set(Capability::SpeechPermission, Status::NeedsPermission);
        c.set(
            Capability::AsrModel("paraformer-zh".into()),
            Status::NeedsDownload {
                size_bytes: 220_000_000,
            },
        );
        c.set(Capability::GoogleDrive, Status::Unsupported);

        let actions = c.pending_actions();
        assert_eq!(actions.len(), 2, "已就緒與不支援的不該出現");
        assert!(
            actions
                .iter()
                .any(|(_, a)| matches!(a, SetupAction::Download { .. }))
        );
    }

    #[test]
    fn total_download_size_is_reported_before_starting() {
        // 裝置空間不足時要先警告，不能下到一半才失敗。
        let mut c = center();
        c.set(
            Capability::AsrModel("paraformer-zh".into()),
            Status::NeedsDownload {
                size_bytes: 220_000_000,
            },
        );
        c.set(
            Capability::LlmModel("qwen3-4b".into()),
            Status::NeedsDownload {
                size_bytes: 2_500_000_000,
            },
        );
        assert_eq!(c.total_download_bytes(), 2_720_000_000);
    }

    #[test]
    fn sync_needs_only_a_local_folder_by_default() {
        // 決策 D3：本機資料夾優先，零成本且涵蓋 Dropbox/Syncthing/NAS。
        let mut c = center();
        assert!(!c.readiness(Feature::Sync).ready);

        c.set(Capability::LocalSyncFolder, Status::Ready);
        assert!(c.readiness(Feature::Sync).ready);
        assert_eq!(c.status(&Capability::ICloudDrive), Status::Unsupported);
    }

    #[test]
    fn unconfigured_folder_offers_a_picker() {
        let mut c = center();
        c.set(Capability::LocalSyncFolder, Status::NotConfigured);
        assert_eq!(
            c.status(&Capability::LocalSyncFolder).action(),
            Some(SetupAction::ChooseFolder)
        );
    }

    #[test]
    fn all_readiness_covers_every_feature() {
        let all = center().all_readiness();
        assert_eq!(all.len(), 6);
        // 零設定狀態下，只有核心筆記可用
        assert_eq!(all.iter().filter(|r| r.ready).count(), 1);
        assert_eq!(
            all.iter().find(|r| r.ready).unwrap().feature,
            Feature::CoreNotes
        );
    }
}
