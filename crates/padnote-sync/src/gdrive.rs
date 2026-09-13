//! Google Drive 同步 Provider (WP31)。
//! 實作 `CloudProvider`，以 Google Drive `appDataFolder` 為後端進行同步。

use crate::provider::{CloudProvider, RemoteEntry, SyncError};
use reqwest::blocking::Client;
use reqwest::header::{AUTHORIZATION, CONTENT_TYPE, RANGE};
use serde::{Deserialize, Serialize};
use serde_json::json;
use std::fmt::Debug;
use std::ops::Range;

/// Google Drive Provider。
pub struct GDriveProvider {
    client: Client,
    access_token: String,
}

impl Debug for GDriveProvider {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("GDriveProvider").finish()
    }
}

impl GDriveProvider {
    pub fn new(access_token: String) -> Self {
        Self {
            client: Client::new(),
            access_token,
        }
    }
    
    fn find_file_id(&self, name: &str) -> Result<String, SyncError> {
        let url = "https://www.googleapis.com/drive/v3/files";
        let q = format!("'appDataFolder' in parents and name = '{}'", name);
        
        let resp = self.client.get(url)
            .header(AUTHORIZATION, format!("Bearer {}", self.access_token))
            .query(&[("spaces", "appDataFolder"), ("fields", "files(id)"), ("q", &q)])
            .send()
            .map_err(|e| SyncError::Backend(e.to_string()))?;
            
        if !resp.status().is_success() {
            return Err(SyncError::Backend(format!("Drive API Error: {}", resp.status())));
        }
        
        #[derive(Deserialize)]
        struct FileList {
            files: Vec<DriveFile>,
        }
        #[derive(Deserialize)]
        struct DriveFile {
            id: String,
        }
        
        let list: FileList = resp.json().map_err(|e| SyncError::Backend(e.to_string()))?;
        list.files.into_iter().next().map(|f| f.id).ok_or_else(|| SyncError::NotFound(name.to_string()))
    }
}

impl CloudProvider for GDriveProvider {
    fn list(&self, prefix: &str) -> Result<Vec<RemoteEntry>, SyncError> {
        let url = "https://www.googleapis.com/drive/v3/files";
        let q = format!("'appDataFolder' in parents and name contains '{}'", prefix);
        
        let resp = self.client.get(url)
            .header(AUTHORIZATION, format!("Bearer {}", self.access_token))
            .query(&[("spaces", "appDataFolder"), ("fields", "files(id, name, size)"), ("q", &q)])
            .send()
            .map_err(|e| SyncError::Backend(e.to_string()))?;
            
        if !resp.status().is_success() {
            return Err(SyncError::Backend(format!("Drive API Error: {}", resp.status())));
        }
        
        #[derive(Deserialize)]
        struct FileList {
            files: Vec<DriveFile>,
        }
        #[derive(Deserialize)]
        struct DriveFile {
            name: String,
            size: Option<String>,
        }
        
        let list: FileList = resp.json().map_err(|e| SyncError::Backend(e.to_string()))?;
        
        Ok(list.files.into_iter()
            .filter(|f| f.name.starts_with(prefix))
            .map(|f| RemoteEntry {
                path: f.name,
                size: f.size.unwrap_or_else(|| "0".to_string()).parse().unwrap_or(0),
            })
            .collect())
    }

    fn get_range(&self, path: &str, range: Range<u64>) -> Result<Vec<u8>, SyncError> {
        let file_id = self.find_file_id(path)?;
        
        let url = format!("https://www.googleapis.com/drive/v3/files/{}?alt=media", file_id);
        let range_header = format!("bytes={}-{}", range.start, range.end.saturating_sub(1));
        
        let resp = self.client.get(&url)
            .header(AUTHORIZATION, format!("Bearer {}", self.access_token))
            .header(RANGE, range_header)
            .send()
            .map_err(|e| SyncError::Backend(e.to_string()))?;
            
        if !resp.status().is_success() {
            return Err(SyncError::Backend(format!("Drive API Error: {}", resp.status())));
        }
        
        resp.bytes().map(|b| b.to_vec()).map_err(|e| SyncError::Backend(e.to_string()))
    }

    fn append(&self, _path: &str, _data: &[u8]) -> Result<(), SyncError> {
        unimplemented!()
    }

    fn put(&self, path: &str, data: &[u8]) -> Result<(), SyncError> {
        let mut file_id_opt = self.find_file_id(path).ok();
        
        if file_id_opt.is_none() {
            // 建立檔案 metadata
            let url = "https://www.googleapis.com/drive/v3/files";
            let metadata = json!({
                "name": path,
                "parents": ["appDataFolder"]
            });
            
            let resp = self.client.post(url)
                .header(AUTHORIZATION, format!("Bearer {}", self.access_token))
                .json(&metadata)
                .send()
                .map_err(|e| SyncError::Backend(e.to_string()))?;
                
            if !resp.status().is_success() {
                return Err(SyncError::Backend(format!("Drive API Error (Create metadata): {}", resp.status())));
            }
            
            #[derive(Deserialize)]
            struct CreateRes {
                id: String,
            }
            let res: CreateRes = resp.json().map_err(|e| SyncError::Backend(e.to_string()))?;
            file_id_opt = Some(res.id);
        }
        
        // 上傳檔案內容
        let file_id = file_id_opt.unwrap();
        let url = format!("https://www.googleapis.com/upload/drive/v3/files/{}?uploadType=media", file_id);
        
        let resp = self.client.patch(&url)
            .header(AUTHORIZATION, format!("Bearer {}", self.access_token))
            .header(CONTENT_TYPE, "application/octet-stream")
            .body(data.to_vec())
            .send()
            .map_err(|e| SyncError::Backend(e.to_string()))?;
            
        if !resp.status().is_success() {
            return Err(SyncError::Backend(format!("Drive API Error (Upload media): {}", resp.status())));
        }
        
        Ok(())
    }

    fn supports_native_append(&self) -> bool {
        false
    }
}
