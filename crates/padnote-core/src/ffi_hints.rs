//! 功能的操作提示（首次使用時出現一次）。
//!
//! # 為什麼需要這個
//!
//! 使用者的回報是「這幾個功能無法實際操作，或者說不知道該怎麼操作」——
//! 草圖修飾、新增討論圖釘、辨識手寫、立起懸停模式。
//!
//! 查下去，**四個都有實作，而且都能用**。它們共同的問題是：按下去之後
//! 進入某種「模式」，而真正要做的事是**下一個動作** ——
//!
//!   * 討論圖釘：進入放置模式後要**再點畫面**才會放下圖釘
//!   * 草圖修飾：要**先有筆跡**，修飾條才有東西可以修
//!   * 辨識手寫：對**這一頁**的筆跡做，空頁不會有結果
//!   * 立起懸停：整個版面會變成上下兩半，那是刻意的不是壞掉
//!
//! 畫面上沒有任何地方講這件事，所以看起來就是「按了沒反應」。
//!
//! # 為什麼表在核心
//!
//! 兩端各寫一份文案的話，改了一邊忘了另一邊是遲早的事，而症狀是
//! 「同一個功能在 iPad 上有說明、在手機上沒有」。id 也一起定在這裡 ——
//! 平台端用它當「不再顯示」的儲存鍵，兩邊的鍵不一樣的話，使用者在一台
//! 裝置上關掉的提示會在另一台冒出來。

/// 一則操作提示。文字本身在兩端共用的 `i18n/ui-strings.json` 裡，
/// 這裡只給鍵 —— 核心的字串表沒有這些句子，而介面文案本來就住在那一份。
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiFeatureHint {
    /// 穩定 id。平台端拿它當「不再顯示」的儲存鍵。
    pub id: String,
    /// 標題的語系鍵。
    pub title_key: String,
    /// 內文的語系鍵 —— **講「接下來要做什麼」**，不是講這個功能是什麼。
    pub body_key: String,
}

/// 哪些功能有提示。順序與「更多」選單一致。
///
/// 只收「按下去之後還要再做一個動作」的那幾個。每個按鈕都跳提示的話，
/// 使用者會學會直接關掉它們 —— 那時候真正需要提示的那個也一起沒了。
#[uniffi::export]
pub fn feature_hints() -> Vec<FfiFeatureHint> {
    ["refine_sketch", "comment_pin", "recognize", "tabletop"]
        .into_iter()
        .map(|id| FfiFeatureHint {
            id: format!("hint.{id}"),
            title_key: format!("hint_{id}_title"),
            body_key: format!("hint_{id}_body"),
        })
        .collect()
}

/// 某個功能的提示。認不得的 id 回 `None` —— 沒有提示不是錯誤。
#[uniffi::export]
pub fn feature_hint(id: String) -> Option<FfiFeatureHint> {
    feature_hints().into_iter().find(|h| h.id == id)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn every_hint_has_a_stable_id_and_two_keys() {
        for h in feature_hints() {
            assert!(h.id.starts_with("hint."), "{}", h.id);
            assert!(h.title_key.starts_with("hint_"), "{}", h.title_key);
            assert!(h.body_key.ends_with("_body"), "{}", h.body_key);
        }
    }

    #[test]
    fn ids_are_unique() {
        // id 是「不再顯示」的儲存鍵 —— 重複的話，關掉一個會連帶關掉另一個。
        let mut ids: Vec<String> = feature_hints().into_iter().map(|h| h.id).collect();
        let before = ids.len();
        ids.sort();
        ids.dedup();
        assert_eq!(before, ids.len());
    }

    #[test]
    fn an_unknown_id_is_none_not_a_panic() {
        assert!(feature_hint("hint.nope".into()).is_none());
    }

    #[test]
    fn the_list_stays_short() {
        // 每個按鈕都跳提示的話，使用者會學會直接關掉它們 ——
        // 那時候真正需要提示的那個也一起沒了。
        assert!(feature_hints().len() <= 8, "提示太多就沒有人看了");
    }
}
