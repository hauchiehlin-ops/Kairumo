//! 匯出重建這台裝置的 oplog 時，**把「不是從文件模型來的」操作搬過去**。
//!
//! # 問題
//!
//! Apple 端每次匯出都用 `NotebookDocument`（平台自己的模型）重建這台裝置的 oplog，再整批換掉舊的
//! （見 `NotebookPackageBridge.exportPreservingOtherDevices`）。文字、圖片、表格、筆畫都在平台模型裡，
//! 重建不會掉。但**錄音當下由核心直接寫進套件的東西不在平台模型裡**：
//!
//! - 錄音區段（`StartAudio` / `EndAudio`）—— 少了它，錄音卡片點下去沒有時間軸、**無法播放**；
//! - 轉錄詞（`AddWord`）與轉錄區塊（`AddTranscriptBlock`）—— 少了它，「語音轉文字」只會得到**空的文字方框**。
//!
//! 於是同步一輪之後，剛錄好的錄音就「短暫消失」、轉文字沒有內容；Mac 上先前能轉文字的錄音，
//! 後來也一樣被洗掉（使用者回報的現象）。
//!
//! # 做法
//!
//! 重建之後、換掉舊檔之前，把舊套件裡**這台裝置自己寫的**這幾種操作讀出來，追加到新套件。
//! 別台裝置寫的不用管（它們各自的檔案原封不動留在套件裡）。

use crate::ffi::FfiError;
use padnote_doc::DocOp;
use padnote_storage::NotebookPackage as Package;

/// 是不是「錄音當下由核心直接寫、平台文件模型不會重建」的操作。
fn is_recording_op(op: &DocOp) -> bool {
    matches!(
        op,
        DocOp::StartAudio { .. }
            | DocOp::EndAudio { .. }
            | DocOp::AddWord { .. }
            | DocOp::AddTranscriptBlock { .. }
    )
}

/// 把 `old_package_path` 裡這台裝置寫的錄音時間軸與轉錄操作，追加到 `new_package_path`。
/// 回傳搬了幾筆。舊套件不存在或沒有這類操作時回 0。
#[uniffi::export]
pub fn carry_over_recording_ops(
    old_package_path: String,
    new_package_path: String,
    device_id: u32,
) -> Result<u32, FfiError> {
    let old_root = std::path::Path::new(&old_package_path);
    if !old_root.join("manifest.json").exists() {
        return Ok(0);
    }
    let old = Package::open(old_root)
        .map_err(|e| FfiError::Failed(format!("開不了舊套件：{e}")))?
        .with_device(device_id);
    let entries = old
        .read_doc_op_entries()
        .map_err(|e| FfiError::Failed(format!("讀不到舊套件的操作：{e}")))?;
    let carried: Vec<DocOp> = entries
        .into_iter()
        .filter(|e| e.device == device_id && is_recording_op(&e.op))
        .map(|e| e.op)
        .collect();
    if carried.is_empty() {
        return Ok(0);
    }
    let mut new = Package::open(&new_package_path)
        .map_err(|e| FfiError::Failed(format!("開不了新套件：{e}")))?
        .with_device(device_id);
    // 排在新套件現有操作之後：轉錄區塊要對得到頁面，頁面是新套件的前幾筆操作建立的。
    let lamport = new.max_doc_lamport() + 1;
    new.append_doc_ops(lamport, device_id, &carried)
        .map_err(|e| FfiError::Failed(format!("寫不進新套件：{e}")))?;
    Ok(carried.len() as u32)
}

#[cfg(test)]
mod tests {
    use super::*;
    use padnote_doc::{NotebookTime, Uuid};

    fn temp(name: &str) -> std::path::PathBuf {
        static COUNTER: std::sync::atomic::AtomicU32 = std::sync::atomic::AtomicU32::new(0);
        let n = COUNTER.fetch_add(1, std::sync::atomic::Ordering::Relaxed);
        let p =
            std::env::temp_dir().join(format!("kairumo-carry-{name}-{}-{n}", std::process::id()));
        std::fs::create_dir_all(&p).unwrap();
        p
    }

    fn make(root: &std::path::Path, device: u32, ops: &[DocOp]) {
        let mut p = Package::create(root, "t", 0).unwrap().with_device(device);
        if !ops.is_empty() {
            p.append_doc_ops(1, device, ops).unwrap();
        }
    }

    #[test]
    fn only_my_recording_ops_are_carried_and_the_rest_stay_behind() {
        let old = temp("old").join("old.padnote");
        let new = temp("new").join("new.padnote");
        let session = Uuid::from_bytes([7; 16]);
        let ops = vec![
            DocOp::StartAudio {
                id: session,
                started_at: NotebookTime(0),
                media_path: "media/audio/a.opus".into(),
            },
            DocOp::AddWord {
                text: "你好".into(),
                start: NotebookTime(1_000),
                end: NotebookTime(2_000),
                confidence: 0.9,
            },
            DocOp::EndAudio {
                id: session,
                ended_at: NotebookTime(5_000_000),
            },
            DocOp::SetTitle {
                title: "不該被搬".into(),
            },
        ];
        make(&old, 7, &ops);
        make(&new, 7, &[]);

        let n = carry_over_recording_ops(old.display().to_string(), new.display().to_string(), 7)
            .unwrap();
        assert_eq!(n, 3, "錄音區段、轉錄詞、結束都要搬；標題不是");

        let carried = Package::open(&new).unwrap().read_doc_ops().unwrap();
        assert!(
            carried
                .iter()
                .any(|o| matches!(o, DocOp::StartAudio { .. }))
        );
        assert!(carried.iter().any(|o| matches!(o, DocOp::AddWord { .. })));
        assert!(carried.iter().any(|o| matches!(o, DocOp::EndAudio { .. })));
        assert!(
            !carried
                .iter()
                .any(|o| matches!(o, DocOp::SetTitle { title } if title == "不該被搬"))
        );
    }

    #[test]
    fn another_devices_recording_ops_are_not_copied_under_my_name() {
        let old = temp("old2").join("old.padnote");
        let new = temp("new2").join("new.padnote");
        let ops = vec![DocOp::AddWord {
            text: "別人的".into(),
            start: NotebookTime(0),
            end: NotebookTime(1),
            confidence: 1.0,
        }];
        make(&old, 9, &ops); // 另一台裝置（9）寫的
        make(&new, 7, &[]);
        let n = carry_over_recording_ops(old.display().to_string(), new.display().to_string(), 7)
            .unwrap();
        assert_eq!(
            n, 0,
            "別台裝置寫的不能複製一份掛在這台名下，下一次合併會變兩份"
        );
    }

    #[test]
    fn a_missing_old_package_carries_nothing() {
        let new = temp("new3").join("new.padnote");
        make(&new, 7, &[]);
        let n = carry_over_recording_ops("/no/such/package".into(), new.display().to_string(), 7)
            .unwrap();
        assert_eq!(n, 0);
    }
}
