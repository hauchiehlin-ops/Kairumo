//! 點對點通道上傳的東西：事件檔與在場資訊。
//!
//! 與傳輸無關（WebRTC 資料通道、區網中繼都能載），所以不在 `p2p` feature 後面：
//! 訊框格式、套件讀寫兩端共用一份（I6）。
//!
//! # 為什麼傳「事件檔」而不是另一套協定
//!
//! 雲端協作的同步單位本來就是 `doc/ops/<lamport>-<device>.oplog`：唯一、不可變（只會變長）、
//! 冪等。點對點只是**捷徑** —— 把剛寫出的檔直接推給對方，對方用同一個檔名寫進套件，
//! 結果與幾秒後從雲端下載的一模一樣。雲端仍是唯一的資料來源；通道斷了什麼都不會壞。

/// 事件檔訊框的開頭。
const OP_MAGIC: &[u8; 4] = b"KOP1";
/// 在場資訊訊框的開頭（內容是 [`crate::ffi_cloud_collab::collab_presence_encode`] 的 JSON）。
const PRESENCE_MAGIC: &[u8; 4] = b"KPR1";

/// 單一訊框的上限。資料通道（SCTP）的安全訊息大小約 64 KB；更大的事件檔交給雲端。
pub const P2P_MAX_FRAME: usize = 60 * 1024;

#[derive(Clone, Debug, PartialEq, Eq, uniffi::Enum)]
pub enum FfiP2pFrame {
    OpFile {
        notebook_id: String,
        name: String,
        data: Vec<u8>,
    },
    Presence {
        json: String,
    },
    Unknown,
}

fn put_str(out: &mut Vec<u8>, s: &str) {
    let b = s.as_bytes();
    out.extend_from_slice(&(b.len().min(u16::MAX as usize) as u16).to_be_bytes());
    out.extend_from_slice(&b[..b.len().min(u16::MAX as usize)]);
}

fn take_str(buf: &[u8], at: &mut usize) -> Option<String> {
    let len = u16::from_be_bytes(buf.get(*at..*at + 2)?.try_into().ok()?) as usize;
    *at += 2;
    let s = std::str::from_utf8(buf.get(*at..*at + len)?)
        .ok()?
        .to_string();
    *at += len;
    Some(s)
}

/// 事件檔 → 訊框。太大（超過 [`P2P_MAX_FRAME`]）回空陣列：交給雲端。
#[uniffi::export]
pub fn p2p_encode_op_file(notebook_id: String, name: String, data: Vec<u8>) -> Vec<u8> {
    let mut out = Vec::with_capacity(data.len() + name.len() + notebook_id.len() + 8);
    out.extend_from_slice(OP_MAGIC);
    put_str(&mut out, &notebook_id);
    put_str(&mut out, &name);
    out.extend_from_slice(&data);
    if out.len() > P2P_MAX_FRAME {
        Vec::new()
    } else {
        out
    }
}

#[uniffi::export]
pub fn p2p_encode_presence(json: String) -> Vec<u8> {
    let mut out = PRESENCE_MAGIC.to_vec();
    out.extend_from_slice(json.as_bytes());
    out
}

#[uniffi::export]
pub fn p2p_decode_frame(frame: Vec<u8>) -> FfiP2pFrame {
    if frame.len() >= 4 && &frame[..4] == OP_MAGIC {
        let mut at = 4;
        let (Some(notebook_id), Some(name)) =
            (take_str(&frame, &mut at), take_str(&frame, &mut at))
        else {
            return FfiP2pFrame::Unknown;
        };
        return FfiP2pFrame::OpFile {
            notebook_id,
            name,
            data: frame[at..].to_vec(),
        };
    }
    if frame.len() >= 4 && &frame[..4] == PRESENCE_MAGIC {
        return match String::from_utf8(frame[4..].to_vec()) {
            Ok(json) => FfiP2pFrame::Presence { json },
            Err(_) => FfiP2pFrame::Unknown,
        };
    }
    FfiP2pFrame::Unknown
}

#[derive(Clone, Debug, PartialEq, Eq, uniffi::Record)]
pub struct FfiOpFileSize {
    pub name: String,
    pub size: u64,
}

/// 套件裡的事件檔與長度。平台記住上次推過的長度，只推新的或變長的。
#[uniffi::export]
pub fn package_op_file_sizes(package_path: String) -> Vec<FfiOpFileSize> {
    padnote_storage::NotebookPackage::open(std::path::Path::new(&package_path))
        .and_then(|p| p.doc_op_files())
        .map(|files| {
            files
                .into_iter()
                .map(|(name, size)| FfiOpFileSize { name, size })
                .collect()
        })
        .unwrap_or_default()
}

/// 讀一個事件檔。讀不到回空陣列。
#[uniffi::export]
pub fn package_read_op_file(package_path: String, name: String) -> Vec<u8> {
    padnote_storage::NotebookPackage::open(std::path::Path::new(&package_path))
        .and_then(|p| p.read_doc_op_file(&name))
        .unwrap_or_default()
}

/// 收下對方推來的事件檔。**只在比本機的長時寫入**（事件檔只會變長；較短的是舊版本）。
/// 檔名是不可信輸入，交給套件檢查（擋 `../` 等）。回傳有沒有寫入 —— 有的話平台要重新載入筆記。
#[uniffi::export]
pub fn package_ingest_op_file(package_path: String, name: String, data: Vec<u8>) -> bool {
    let Ok(package) = padnote_storage::NotebookPackage::open(std::path::Path::new(&package_path))
    else {
        return false;
    };
    let local = package
        .doc_op_files()
        .ok()
        .and_then(|files| files.into_iter().find(|(n, _)| *n == name).map(|(_, s)| s))
        .unwrap_or(0);
    if (data.len() as u64) <= local {
        return false;
    }
    package.write_doc_op_file(&name, &data).is_ok()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn frames_round_trip() {
        let f = p2p_encode_op_file(
            "NB".into(),
            "0000000000000001-0000abcd.oplog".into(),
            vec![1, 2, 3],
        );
        assert_eq!(
            p2p_decode_frame(f),
            FfiP2pFrame::OpFile {
                notebook_id: "NB".into(),
                name: "0000000000000001-0000abcd.oplog".into(),
                data: vec![1, 2, 3]
            }
        );
        assert_eq!(
            p2p_decode_frame(p2p_encode_presence("{}".into())),
            FfiP2pFrame::Presence { json: "{}".into() }
        );
        assert_eq!(p2p_decode_frame(vec![0, 1]), FfiP2pFrame::Unknown);
        assert!(
            p2p_encode_op_file("N".into(), "x.oplog".into(), vec![0; P2P_MAX_FRAME]).is_empty()
        );
    }

    #[test]
    fn ingest_only_grows_and_rejects_escapes() {
        let dir = std::env::temp_dir().join(format!("kairumo-p2p-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&dir);
        padnote_storage::NotebookPackage::create(&dir, "t", 0).unwrap();
        let path = dir.to_string_lossy().to_string();
        let name = "0000000000000001-0000abcd.oplog".to_string();
        assert!(package_ingest_op_file(
            path.clone(),
            name.clone(),
            vec![1, 2, 3]
        ));
        assert!(!package_ingest_op_file(
            path.clone(),
            name.clone(),
            vec![9, 9]
        ));
        assert_eq!(
            package_read_op_file(path.clone(), name.clone()),
            vec![1, 2, 3]
        );
        assert!(!package_ingest_op_file(
            path.clone(),
            "../evil.oplog".into(),
            vec![1; 9]
        ));
        assert!(
            package_op_file_sizes(path)
                .iter()
                .any(|f| f.name == name && f.size == 3)
        );
        let _ = std::fs::remove_dir_all(&dir);
    }
}
