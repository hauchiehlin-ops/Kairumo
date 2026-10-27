# Kairumo 跨平台專有名詞規範手冊 (Glossary)

本規範手冊對齊 `i18n/glossary.json` 與 `i18n/ui-strings.json`，旨在確保 Apple (iOS / macOS) 與 Android 雙端介面、手冊文件與多國語言字串的名詞一致性，徹底消除過往同義詞分岔與歧義。

---

## 1. 飛梭工具盤 (Radial Menu)

- **標準名稱**：
  - 繁體中文（zh-Hant）：**飛梭工具盤**
  - 簡體中文（zh-Hans）：**飞梭工具盘**
  - 英文（en）：**Radial Menu**（或 **Radial tool menu**）
  - 日文（ja）：**ラジアルメニュー**
  - 韓文（ko）：**래디얼 메뉴**
  - 泰文（th）：**เมนูวงกลม**
- **禁止 / 淘汰之舊稱**：
  - ❌ `徑向飛輪快捷盤`
  - ❌ `環形快捷工具盤`
  - ❌ `徑向快捷盤`
  - ❌ `Radial Mark Menu`
  - ❌ `Radial Pie Menu`
- **功能定義**：
  - 在畫布上用筆尖或手指按住不動約 0.55 秒，或點擊工具列飛梭按鈕彈出的圓形快捷工具盤（2–8 格槽位）。支援使用者在自訂工具列中客製化排列。

---

## 2. 匯入體系名詞區隔 (Import Taxonomy)

為避免使用者在選單中看到「匯入」而混淆操作目的，嚴格區隔以下四種情境：

| 功能識別 ID | 推薦標準名稱 (zh-Hant) | 英文名稱 (en) | 適用範圍與定義 | 淘汰舊稱 |
| :--- | :--- | :--- | :--- | :--- |
| `import_pdf` | **匯入 PDF** | Import PDF | 將 PDF 各頁作為**鎖定底稿**載入筆記，手寫筆跡繪於上方，匯出可帶註記。 | 無 |
| `import_document` | **匯入 Word／Excel／Markdown** | Import Word / Excel / Markdown | 將 office 與 markdown 解析為筆記內的**原生物件**（文字框、表格、圖形）。 | ❌ 匯入文件、导入文档、Import Document |
| `import_notebook` | **匯入筆記本** | Import Notebook | 從外部匯入一整本完整的 `.padnote` / `.kairumo` 筆記套件至書架。 | ❌ 匯入筆記、导入笔记 |
| `import_snapshot` | **匯入筆記本快照** | Import Notebook Snapshot | 從備份快照檔案還原歷史版本筆記本，不會覆蓋現有筆記。 | 無 |

---

## 3. 自動化檢查

維護規則與 CI 稽核可透過 `scripts/check-glossary.py` 執行，確認 `ui-strings.json` 與各端程式碼無殘留淘汰關鍵字。
