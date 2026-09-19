# Kairumo App Store Connect (ASC) 審核過審全指南與審核備註

本文件針對 Apple App Store Review Guidelines（特別是 Guideline 2.1、2.3、3.1.1、4.3、4.8 與 5.1）提供完整的**審核備註（App Review Notes）複製文字**與**送審前自我稽查清單**，以確保送審零退件、快速過審。

---

## 1. ASC 審核備註欄（App Review Information）建議填寫內容

> [!TIP]
> 請直接將以下內容（建議附上英文或中英雙語）複製貼入 App Store Connect 的 **「審核資訊」→「備註（Review Notes）」** 欄位中。審核員閱讀後可在數分鐘內完成快速查驗。

```markdown
Dear Apple App Review Team,

Thank you for reviewing Kairumo! Below is key operational information to assist your review process:

1. NO LOGIN OR ACCOUNT REQUIRED (Guideline 2.1)
- Kairumo is a 100% local-first note-taking application.
- All core functionalities—including handwriting, typing, audio recording, on-device transcription, canvas editing, templates, and export—are fully accessible immediately upon launch without requiring any account, sign-up, or login.

2. CLOUD SYNC & THIRD-PARTY SERVICE (Guideline 4.8 Exemption)
- Kairumo does not use third-party accounts to authenticate users for the app itself.
- Under “Cloud Sync” on the home screen, users can optionally connect their Google Drive to store note files in their private Google Drive `appDataFolder`.
- This falls strictly under the Guideline 4.8 exception: "Your app is a client for a specific third-party service and users are required to sign in to their third-party account directly to access their content."
- The app remains 100% functional even if the user never connects any cloud storage.

3. LOCAL NETWORK COLLABORATION (Guideline 5.1.1)
- The app offers peer-to-peer real-time collaboration between devices on the same local Wi-Fi network.
- Connections are established directly via local network sockets with end-to-end AES-256-GCM encryption. No external relay or centralized backend server is operated.
- The NSLocalNetworkUsageDescription purpose string is declared in Info.plist.

4. STEP-BY-STEP REVIEW GUIDE
- Create Note: On the Home Workbench, tap “+ New Notebook” or choose any paper template from the gallery.
- Handwriting & Radial Menu: In the editor, draw with pens, or tap the canvas to evoke the 360° Radial Mark Menu for instant tool switching. Try drawing a straight line or angle—Smart Magnetic Snap aligns lines to 0°/45°/90° with haptic and laser guidelines.
- Fluid Sticky Annotations: Switch to Type mode, add a text box next to your handwriting, and tap “Anchor to Text”. Move the text box to see the ink annotations follow dynamically.
- Audio & Karaoke Sync: Tap the Microphone icon to record audio. Play back the recording to observe audio-ink karaoke highlighting, or tap any stroke to jump the audio timeline directly to that point.
- Offline & Privacy: Tap “Privacy Policy” on the home screen to review the offline privacy policy.

5. BUSINESS MODEL & PAYMENTS (Guideline 3.1.1)
- Kairumo is completely free and open-source.
- There are NO In-App Purchases (IAP), NO subscriptions, NO paid features, and NO third-party payment gateways.

6. METADATA & SUPPORT URLS
- Privacy Policy URL: https://hauchiehlin-ops.github.io/Kairumo/legal/privacy.html
- Support URL: https://hauchiehlin-ops.github.io/Kairumo/support.html
- Contact Email: dr.cobra.lin@gmail.com

If you have any questions during review, please feel free to reach out. Thank you for your time and dedication!
```

---

## 2. ASC 送審前六大關鍵重點稽核表

### 檢查項 1：核心功能完整性（Guideline 2.1）
- [x] **免帳號直接使用**：核心畫布、手寫、錄音、轉錄、排版、樣板、匯出無需登入。
- [x] **無任何 "Beta" / "Test" / "Demo" 殘留**：全應用程式 UI、字串庫及打包手冊中已全面清查，0 處測試版字樣。
- [x] **IPv6-only 網路相容**：本地中繼服務與網路連線採用 Apple `Network` 框架標準 `NWParameters.tcp`，支援原生 IPv6 / NAT64。

### 檢查項 2：隱私與權限描述（Guideline 5.1）
- [x] **權限用途字串（Purpose Strings）具體明確**：
  - `NSMicrophoneUsageDescription`：說明用於課堂/會議錄音與聲筆時間軸同步。
  - `NSSpeechRecognitionUsageDescription`：說明用於裝置端本機錄音轉錄文字。
  - `NSLocalNetworkUsageDescription`：說明用於同 Wi-Fi 網路端對端加密協同編輯。
  - `NSPhotoLibraryUsageDescription`：說明用於選取相片插入筆記頁面進行批註。
  - `NSPhotoLibraryAddUsageDescription`：說明用於將導出的筆記或手繪圖片存入相簿。
- [x] **隱私權政策雙通道可達**：
  - App 內點擊即可本機離線瀏覽（支援六國語言）。
  - 工具列提供 Safari 圖示直接開啟公網公開網址：`https://hauchiehlin-ops.github.io/Kairumo/legal/privacy.html`。

### 檢查項 3：第三方登入與帳號註銷（Guideline 4.8 & 5.1.1(v)）
- [x] **非身分登入，改以「連結雲端硬碟」明確表達**：
  - 按鈕字串對齊為「連結 Google 雲端硬碟 / Connect Google Drive」，杜絕審核員誤判為第三方社交登入而誤駁。
  - 明確符合 Guideline 4.8 專屬服務用戶端豁免條款。
- [x] **無帳號註冊系統**：App 完全不收集任何使用者帳號、信箱或密碼，不存在「刪除帳號」之退件風險。

### 檢查項 4：商業模式與金流（Guideline 3.1.1）
- [x] **零第三方支付**：無任何外部金流 SDK、刷卡、支付寶、Line Pay、Stripe 或贊助連結。
- [x] **零付費解鎖**：全功能免費開源。

### 檢查項 5：元數據與螢幕截圖（Guideline 2.3）
- [x] **截圖規範**：上傳至 ASC 的截圖頂部狀態列需符合 iOS/iPadOS 規範，不得包含 Android 圖示或虛假外框。
- [x] **關鍵字去競品化**：ASC 後台關鍵字欄位**絕不**包含 Goodnotes、Notability、OneNote 等競品商標，避免被判定為不正當誘導。

### 檢查項 6：版本號與多國語系一致性
- [x] 版本號一致性閘門通過：`Cargo.toml`、`apple/project.yml`、`project.pbxproj`、`build.gradle.kts`、`manual.js`、`privacy.html` 六處一致（v4.2.1 build 40）。
- [x] i18n 完整性閘門通過：1175 條翻譯六國語系 100% 齊備。
