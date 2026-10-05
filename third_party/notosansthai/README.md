# Noto Sans Thai（SIL Open Font License 1.1）

| | |
|---|---|
| 檔案 | `NotoSansThai-Regular.ttf`（72,812 位元組） |
| 來源 | https://github.com/notofonts/notofonts.github.io/tree/main/fonts/NotoSansThai/full/ttf （Noto 專案的發行庫；原始碼庫 https://github.com/notofonts/thai） |
| 取得日期 | 2026-10-06（發行庫 commit `86eb2ddc3a2e97cb9747fd9069ee5d47880e3305`） |
| SHA-256 | `2101faa471942570d506a394df7da555d15246c7814c7522c63d4fa85b0d8d88` |
| 授權 | SIL Open Font License 1.1；全文 `OFL.txt`（取自 https://github.com/notofonts/thai/blob/main/OFL.txt） |
| 著作權 | Copyright 2022 The Noto Project Authors |

## 用在哪裡、為什麼

匯出 PDF 時，PDF 沒有「不必嵌入就能畫泰文」的標準字型（中日韓有 Adobe 的標準 CID 字型，泰文沒有），
所以泰文只能把字型嵌進檔案。`crates/padnote-export` 用 `include_bytes!` 把它編進核心，**只有文件裡真的有泰文時**才嵌進該份 PDF。

泰文要靠字型自己的 GSUB／GPOS 表排版（聲調符號疊在子音與上母音之上、ำ 拆成兩個字形），
`crates/padnote-export/src/otl.rs` 照表執行，沒有把泰文規則寫死在程式裡。

## OFL 的條件

- 可自由使用、研究、修改、散布與搭配軟體販售；**字型本身不能單獨販售**；衍生版本不能用保留字型名稱。
- 散布時要附著作權聲明與授權全文：字型檔本身的 name 表已含著作權與授權資訊，另外 `OFL.txt` 隨 App 一起打包
  （`assets/seed/OFL-NotoSansThai.txt`）。
- **沒有修改字型**：嵌進 PDF 的是原檔（未子集化、未改名）。
