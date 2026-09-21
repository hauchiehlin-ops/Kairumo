//! 雲端物件名稱的**單一來源**（P0 共通基準）。
//!
//! # 為什麼一定要集中在這裡
//!
//! Apple 的 APFS 預設**不分大小寫**，Android 的 ext4/f2fs **分大小寫**，
//! 而 Google Drive 的檔名是分大小寫的。三者湊在一起的後果已經發生過一次：
//! 同一個錄音在 iPad 上叫 `A1B2….opus`、在 Android 上叫 `a1b2….opus`，
//! 兩台裝置各自上傳一份，然後**誰也看不到對方的**（`uuid case mismatch`）。
//!
//! 再加上 Unicode 正規化：Apple 歷史上用 NFD、Android 用 NFC，
//! 只要有一個中文字進到雲端路徑，兩邊的位元組就永遠對不上。
//!
//! 所以基準只有一條：
//!
//! > **雲端物件名一律是 ASCII 小寫，字元集限定 `[0-9a-z._/-]`；
//! > 任何人類可讀的字串（標題、資料夾名）只准放在 JSON 的內容裡，不進檔名。**
//!
//! 平台層**不要自己拼字串** —— 拼錯不會有任何錯誤，只是兩台裝置寫到不同的
//! 檔案，然後永遠同步不到。
//!
//! # 與既有雲端資料的相容性
//!
//! 舊版可能已經上傳過含大寫的名字。**不要為了改名而重傳**：
//! 比對時兩邊都先過 [`canonical_name`]，實際存取則用遠端回報的原始路徑
//! （見 `RemoteIndex`）。新寫入的一律是正規化後的名字，舊的會隨著壓實自然汰換。

/// 雲端路徑允許的字元。
fn is_allowed(c: char) -> bool {
    c.is_ascii_lowercase() || c.is_ascii_digit() || matches!(c, '.' | '_' | '-' | '/')
}

/// 這個字串可不可以直接當雲端路徑用。
///
/// 測試用它把「路徑一律小寫 ASCII」這條規則釘死 —— 註解攔不住任何東西。
pub fn is_canonical(path: &str) -> bool {
    !path.is_empty()
        && path.chars().all(is_allowed)
        && !path.contains("..")
        && !path.starts_with('/')
        && !path.ends_with('/')
}

/// 把一個名稱正規化成雲端可用的形式。
///
/// 大寫轉小寫，不在允許集合裡的字元一律換成 `-`。
/// **這個函式是冪等的**：`canonical_name(canonical_name(x)) == canonical_name(x)`。
pub fn canonical_name(raw: &str) -> String {
    raw.chars()
        .map(|c| {
            let lower = c.to_ascii_lowercase();
            if is_allowed(lower) && lower != '/' {
                lower
            } else {
                '-'
            }
        })
        .collect()
}

/// 把一條**完整路徑**正規化（保留 `/`）。
///
/// 與 [`canonical_name`] 的差別只在斜線：名稱裡的斜線是非法字元（會把一段
/// 切成兩段），路徑裡的斜線是結構。兩者混用過一次，症狀是
/// `notebooks/nb1/doc/ops` 被折成 `notebooks-nb1-doc-ops`，
/// 於是索引裡什麼都查不到。
pub fn canonical_path(raw: &str) -> String {
    raw.split('/').map(canonical_name).collect::<Vec<_>>().join("/")
}

/// 筆記本 id 的正規化形式。與 [`canonical_name`] 相同規則，
/// 另外擋掉空字串（空 id 會讓路徑塌成 `notebooks//doc/ops`）。
pub fn canonical_id(raw: &str) -> String {
    let out = canonical_name(raw);
    if out.is_empty() {
        "unknown".to_string()
    } else {
        out
    }
}

/// 一本筆記本在雲端的根。
pub fn notebook_root(notebook_id: &str) -> String {
    format!("notebooks/{}", canonical_id(notebook_id))
}

/// 一本筆記本的 oplog 目錄前綴。
pub fn notebook_ops_prefix(notebook_id: &str) -> String {
    format!("{}/doc/ops", notebook_root(notebook_id))
}

/// 一個 oplog 檔的完整雲端路徑。
pub fn notebook_op_file(notebook_id: &str, file_name: &str) -> String {
    format!(
        "{}/{}",
        notebook_ops_prefix(notebook_id),
        canonical_name(file_name)
    )
}

/// 圖片 blob 目錄前綴。
pub fn notebook_blobs_prefix(notebook_id: &str) -> String {
    format!("{}/media/blobs", notebook_root(notebook_id))
}

pub fn notebook_blob_file(notebook_id: &str, file_name: &str) -> String {
    format!(
        "{}/{}",
        notebook_blobs_prefix(notebook_id),
        canonical_name(file_name)
    )
}

/// 錄音目錄前綴。
pub fn notebook_audio_prefix(notebook_id: &str) -> String {
    format!("{}/media/audio", notebook_root(notebook_id))
}

pub fn notebook_audio_file(notebook_id: &str, file_name: &str) -> String {
    format!(
        "{}/{}",
        notebook_audio_prefix(notebook_id),
        canonical_name(file_name)
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn every_generated_path_is_canonical() {
        // 這條測試就是那個基準本身。任何新的路徑產生器都要加進來。
        let messy = "A1B2-C3D4";
        let paths = [
            notebook_root(messy),
            notebook_ops_prefix(messy),
            notebook_op_file(messy, "0000000000000001-000000AA.oplog"),
            notebook_blobs_prefix(messy),
            notebook_blob_file(messy, "DEADBEEF"),
            notebook_audio_prefix(messy),
            notebook_audio_file(messy, "5F2A-BB.OPUS"),
            crate::settings::SETTINGS_PATH.to_string(),
            crate::library::INDEX_PATH.to_string(),
        ];
        for p in paths {
            assert!(is_canonical(&p), "不是正規路徑：{p}");
        }
    }

    #[test]
    fn case_differences_collapse_to_one_name() {
        // 這是真的爆過的 bug：同一個錄音在兩台裝置上大小寫不同，
        // 於是各自上傳一份，誰也看不到對方的。
        assert_eq!(
            notebook_audio_file("NB1", "A1B2.opus"),
            notebook_audio_file("nb1", "a1b2.opus")
        );
    }

    #[test]
    fn non_ascii_never_reaches_a_path() {
        // 標題進檔名就會踩到 NFD/NFC。這裡保證它進不去。
        let p = notebook_op_file("會議紀錄", "筆記.oplog");
        assert!(is_canonical(&p), "{p}");
        assert!(!p.contains('會'));
    }

    #[test]
    fn a_path_keeps_its_slashes_but_a_name_does_not() {
        // 混用過一次：`notebooks/nb1/doc/ops` 被折成
        // `notebooks-nb1-doc-ops`，索引裡於是什麼都查不到。
        assert_eq!(canonical_path("Notebooks/NB1/doc/ops"), "notebooks/nb1/doc/ops");
        assert_eq!(canonical_name("a/b"), "a-b");
    }

    #[test]
    fn canonicalisation_is_idempotent() {
        let once = canonical_name("Ab/C..D");
        assert_eq!(canonical_name(&once), once);
    }

    #[test]
    fn an_empty_id_does_not_collapse_the_path() {
        // 空 id 會讓路徑塌成 `notebooks//doc/ops`，而那是一個
        // 所有裝置都會寫進去的共用桶。
        assert_eq!(notebook_ops_prefix(""), "notebooks/unknown/doc/ops");
    }

    #[test]
    fn traversal_is_not_canonical() {
        assert!(!is_canonical("notebooks/../../etc/passwd"));
    }
}
