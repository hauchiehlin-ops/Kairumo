//! 套件加密的平台介面（H-CRYPTO）。
//!
//! # 五個決策
//!
//! 這些不是工程可以自己決定的，記在這裡免得下一個人重新推導一次：
//!
//! 1. **全域一個密碼**，不是每本一個。每本一個會讓使用者管十幾組密碼，
//!    實務上等於全部設成同一個，而介面複雜度是真的。
//! 2. **復原碼強制抄寫並回填驗證**才算啟用完成。無後端就沒有「忘記密碼」
//!    信件，也沒有客服能救 —— 不擋的話，第一個忘記密碼的使用者
//!    會失去全部筆記。
//! 3. **只加密新的筆記本，既有的原地不動**，並在介面上標明哪些已加密。
//!    一次性全庫重新加密是不可逆的大規模遷移，風險與收益不成比例。
//! 4. **同步不需要密碼。** 搬的是密文、壓實只是把框架接起來，
//!    兩者都不必解密。需要密碼的只有「把內容顯示給使用者看」。
//! 5. **房間金鑰與套件金鑰維持兩套。** 生命週期完全不同：
//!    一個短命、放在邀請連結裡，一個長期、由密碼包住。
//!
//! # 涵蓋範圍（要誠實講給使用者聽）
//!
//! 加密涵蓋 **`doc/ops/*.oplog`（筆記內容）與 `media/blobs`（圖片）**。
//!
//! **錄音還沒有加密。** 錄音是邊錄邊寫的 Ogg 串流，包成框架之後就不再是
//! 一個播放器打得開的檔案 —— 而「使用者可以用 VLC 打開自己的錄音」是
//! 這個專案明講過的承諾（H4）。那個取捨要單獨決定，不能順手做掉。
//! 介面上必須寫清楚，不能讓使用者以為錄音也加密了。

use std::sync::Arc;

/// 加密相關的失敗。
#[derive(Clone, Debug, thiserror::Error, uniffi::Error)]
pub enum FfiCryptoError {
    /// 密碼不對，或資料被竄改過。**這兩種分不開，也不該分開** ——
    /// 分得開就等於給攻擊者一個判斷密碼對錯的預言機。
    #[error("密碼錯誤或資料已被竄改")]
    WrongPassphrase,
    #[error("復原碼不正確：{detail}")]
    BadRecoveryCode { detail: String },
    #[error("{detail}")]
    Failed { detail: String },
}

/// 新建的加密套件。
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiEncryptedNotebook {
    pub notebook_id: String,
    /// 復原碼（BIP39 英文，**24 個詞**）。
    ///
    /// **只在這一刻存在** —— 之後任何人（包括我們）都算不回來。
    /// 呼叫端必須讓使用者抄下來並回填驗證過，才算完成啟用。
    ///
    /// 24 個詞是 256 位元的熵，與 DEK 同強度。12 個詞抄起來輕鬆得多，
    /// 但那會讓復原碼變成整條鏈上最弱的一環。
    pub recovery_phrase: String,
}

/// 建立一本加密的筆記本。
///
/// 回傳的復原碼**只出現這一次**。沒有讓使用者抄下來就繼續的話，
/// 忘記密碼等於資料永久遺失 —— 這不是誇飾，是這個架構的直接後果。
#[uniffi::export]
pub fn crypto_create_encrypted_notebook(
    package_path: String,
    title: String,
    now_unix_ms: u64,
    passphrase: String,
) -> Result<FfiEncryptedNotebook, FfiCryptoError> {
    let (pkg, phrase) = padnote_storage::NotebookPackage::create_encrypted(
        std::path::Path::new(&package_path),
        &title,
        now_unix_ms,
        &passphrase,
    )
    .map_err(|e| FfiCryptoError::Failed {
        detail: e.to_string(),
    })?;
    Ok(FfiEncryptedNotebook {
        notebook_id: pkg.manifest().notebook_id.clone(),
        recovery_phrase: phrase,
    })
}

/// 這個套件加密了嗎。**不需要密碼**（只看 manifest）。
///
/// 介面用它決定要不要顯示鎖頭，以及要不要在開啟前先問密碼。
#[uniffi::export]
pub fn crypto_is_encrypted(package_path: String) -> bool {
    padnote_storage::NotebookPackage::open(std::path::Path::new(&package_path))
        .map(|p| p.is_encrypted())
        .unwrap_or(false)
}

/// 試一次密碼。對的話回 true。
///
/// 用來在開啟筆記本之前先驗一次 —— 直接拿錯的密碼去讀內容的話，
/// 錯誤會從解碼那一層冒出來，訊息對使用者沒有意義。
///
/// **這一步很慢（Argon2id 刻意如此），不要在主執行緒呼叫。**
#[uniffi::export]
pub fn crypto_verify_passphrase(package_path: String, passphrase: String) -> bool {
    padnote_storage::NotebookPackage::open(std::path::Path::new(&package_path))
        .and_then(|p| p.unlock(&passphrase))
        .is_ok()
}

/// 檢查使用者抄下來的復原碼對不對。
///
/// # 為什麼要有這一步
///
/// 校驗和讓抄錯字**當場**被抓到，而不是等到真的要救資料時才發現。
/// 啟用流程一定要把這一關放進去 —— 「我等一下再抄」的使用者，
/// 就是後來會失去全部筆記的那一個。
#[uniffi::export]
pub fn crypto_check_recovery_phrase(phrase: String) -> bool {
    let words = padnote_crypto::recovery::english_wordlist();
    padnote_crypto::recovery::RecoveryCode::parse(&phrase, &words).is_ok()
}

/// 產生一組新的復原碼（給「重新產生」用）。
#[uniffi::export]
pub fn crypto_generate_recovery_phrase() -> Result<String, FfiCryptoError> {
    let words = padnote_crypto::recovery::english_wordlist();
    padnote_crypto::recovery::RecoveryCode::generate(&words)
        .map(|c| c.phrase())
        .map_err(|e| FfiCryptoError::BadRecoveryCode {
            detail: e.to_string(),
        })
}

/// 加密涵蓋哪些東西。**給介面直接顯示用**，不要在平台層另外寫一份文案 ——
/// 寫兩份的話，總有一邊會在範圍變了之後沒跟上，而那一邊在騙使用者。
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiEncryptionScope {
    /// 筆記內容（文字、筆跡、表格、形狀…）。
    pub covers_notes: bool,
    /// 圖片。
    pub covers_images: bool,
    /// 錄音。**目前是 false**，理由見模組說明。
    pub covers_recordings: bool,
}

#[uniffi::export]
pub fn crypto_encryption_scope() -> FfiEncryptionScope {
    FfiEncryptionScope {
        covers_notes: true,
        covers_images: true,
        // 錄音是邊錄邊寫的 Ogg 串流，包成框架就不再是播放器打得開的檔案。
        // 那個取捨要單獨決定 —— 在決定之前，介面必須誠實說「錄音沒有加密」。
        covers_recordings: false,
    }
}

/// 解鎖之後的筆記本把手。
///
/// 持有它就等於持有解開內容的金鑰，所以**不要存起來**、也不要跨畫面傳。
/// 使用者鎖上或 App 進背景時就丟掉它。
#[derive(uniffi::Object)]
pub struct FfiUnlockedNotebook {
    package_path: String,
    passphrase: String,
}

impl std::fmt::Debug for FfiUnlockedNotebook {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        // **不要印密碼。** Debug 輸出會進 log，而 log 會被使用者貼給我們。
        f.debug_struct("FfiUnlockedNotebook")
            .field("package_path", &self.package_path)
            .finish_non_exhaustive()
    }
}

#[uniffi::export]
impl FfiUnlockedNotebook {
    /// 換密碼。
    ///
    /// **內容不會重新加密** —— 換的只有包住 DEK 的那一層。
    /// 所以這一步很快，而且不會動到任何一個 oplog 檔。
    pub fn change_passphrase(&self, new_passphrase: String) -> Result<(), FfiCryptoError> {
        let pkg = padnote_storage::NotebookPackage::open(std::path::Path::new(&self.package_path))
            .map_err(|e| FfiCryptoError::Failed {
                detail: e.to_string(),
            })?;
        pkg.rewrap_passphrase(&self.passphrase, &new_passphrase)
            .map_err(|_| FfiCryptoError::WrongPassphrase)
    }
}

/// 用密碼開一個已加密的套件。密碼錯誤回 `WrongPassphrase`。
///
/// **這一步很慢（Argon2id 刻意如此），不要在主執行緒呼叫。**
#[uniffi::export]
pub fn crypto_unlock(
    package_path: String,
    passphrase: String,
) -> Result<Arc<FfiUnlockedNotebook>, FfiCryptoError> {
    padnote_storage::NotebookPackage::open(std::path::Path::new(&package_path))
        .and_then(|p| p.unlock(&passphrase))
        .map_err(|_| FfiCryptoError::WrongPassphrase)?;
    Ok(Arc::new(FfiUnlockedNotebook {
        package_path,
        passphrase,
    }))
}

#[cfg(test)]
mod tests {
    use super::*;

    fn tmp(name: &str) -> std::path::PathBuf {
        let d =
            std::env::temp_dir().join(format!("padnote-ffi-crypto-{name}-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&d);
        d
    }

    #[test]
    fn creating_an_encrypted_notebook_hands_back_a_recovery_phrase() {
        let root = tmp("create");
        let made = crypto_create_encrypted_notebook(
            root.to_string_lossy().into(),
            "秘密".into(),
            1,
            "correct horse battery".into(),
        )
        .expect("建立");
        assert!(!made.notebook_id.is_empty());
        // **24 個詞，不是 12。** 核心用 256 位元的熵，與 DEK 同強度 ——
        // 12 個詞（128 位元）會讓復原碼變成整條鏈上最弱的一環，
        // 而攻擊者當然會打最弱的那一環。
        assert_eq!(made.recovery_phrase.split_whitespace().count(), 24);
        assert!(crypto_check_recovery_phrase(made.recovery_phrase));
    }

    #[test]
    fn a_wrong_passphrase_is_rejected_without_saying_why() {
        // 「密碼錯」與「資料被竄改」分得開的話，等於給攻擊者一個
        // 判斷密碼對錯的預言機。
        let root = tmp("wrongpw");
        crypto_create_encrypted_notebook(
            root.to_string_lossy().into(),
            "t".into(),
            1,
            "right".into(),
        )
        .unwrap();
        assert!(crypto_verify_passphrase(
            root.to_string_lossy().into(),
            "right".into()
        ));
        assert!(!crypto_verify_passphrase(
            root.to_string_lossy().into(),
            "wrong".into()
        ));
        assert!(matches!(
            crypto_unlock(root.to_string_lossy().into(), "wrong".into()),
            Err(FfiCryptoError::WrongPassphrase)
        ));
    }

    #[test]
    fn a_typo_in_the_recovery_phrase_is_caught() {
        let phrase = crypto_generate_recovery_phrase().unwrap();
        assert!(crypto_check_recovery_phrase(phrase.clone()));
        let mut words: Vec<&str> = phrase.split_whitespace().collect();
        words[0] = if words[0] == "abandon" {
            "ability"
        } else {
            "abandon"
        };
        assert!(!crypto_check_recovery_phrase(words.join(" ")));
    }

    #[test]
    fn changing_the_passphrase_does_not_touch_the_content() {
        let root = tmp("rewrap");
        crypto_create_encrypted_notebook(
            root.to_string_lossy().into(),
            "t".into(),
            1,
            "old".into(),
        )
        .unwrap();
        let handle = crypto_unlock(root.to_string_lossy().into(), "old".into()).unwrap();
        handle.change_passphrase("new".into()).unwrap();

        assert!(crypto_verify_passphrase(
            root.to_string_lossy().into(),
            "new".into()
        ));
        assert!(!crypto_verify_passphrase(
            root.to_string_lossy().into(),
            "old".into()
        ));
    }

    #[test]
    fn a_plain_notebook_reports_itself_as_unencrypted() {
        let root = tmp("plain");
        padnote_storage::NotebookPackage::create(&root, "t", 1).unwrap();
        assert!(!crypto_is_encrypted(root.to_string_lossy().into()));
    }

    #[test]
    fn the_scope_says_recordings_are_not_covered() {
        // 介面必須照著這個講。說「全部加密」而錄音其實是明文的話，
        // 使用者會據此把敏感的東西錄進去。
        let scope = crypto_encryption_scope();
        assert!(scope.covers_notes);
        assert!(scope.covers_images);
        assert!(!scope.covers_recordings, "範圍變了就要同步改介面文案");
    }
}
