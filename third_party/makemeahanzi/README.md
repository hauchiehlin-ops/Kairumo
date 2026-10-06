# makemeahanzi 筆順資料（Arphic Public License）

| | |
|---|---|
| 來源 | https://github.com/skishore/makemeahanzi （`graphics.txt`） |
| 取得日期 | 2026-10-06 |
| 版本 | commit `bddc96d41bef78427ed0e034e9f7e31d71fd1b92`（2026-03-08） |
| `graphics.txt` SHA-256 | `a28c478b5178e98f67f510b2d52fde08a69dc664654ef43498253b9b764d46ee` |
| 授權 | Arphic Public License（1999，文泰科技 Arphic Technology Co., Ltd.）；全文見 `ARPHICPL.TXT`（未改動，SHA-256 `ba74a961aaa5fa7e73dc67276df2781ba405da2cb30c52c9d9eee9c200d4d11e`，取自 https://ftp.gnu.org/non-gnu/chinese-fonts-truetype/LICENSE） |
| 本專案裡的檔案 | `strokes-subset.json`（229 個字的筆畫中線：繁體與簡體手冊用到的字）、`ARPHICPL.TXT`、`NOTICE.txt` |

## 授權評估（2026-10-06）

`graphics.txt` 由 Arphic PL KaitiM GB／UKai 兩套字型推導，屬於字型的衍生物（APL 第 0 條把「轉換格式、增減字」也算修改）。
APL 允許複製、修改與散布，條件是：

1. **附上未改動的授權全文**（第 1 條）→ `ARPHICPL.TXT`，且隨 App 一起打包（見下）。
2. **每個修改過的檔案要註明怎麼改、何時改**（第 2 條 a）→ `strokes-subset.json` 檔頭與 `NOTICE.txt`。
3. **修改後的成果要在同一授權下免費公開**（第 2 條 b）→ 本 repo 是公開的，`strokes-subset.json` 就在裡面。
4. **只是放在一起的其他作品不受 APL 約束**（第 2 條最後一段）→ Kairumo 的程式碼授權不變；筆順資料是獨立元件，不混進程式碼。

與專案硬約束（完全免費、技術來源必須開源）相容。不取用 `dictionary.txt`（LGPL-3.0，另一套條件，本專案用不到）。

## 怎麼重建

```bash
curl -L https://raw.githubusercontent.com/skishore/makemeahanzi/master/graphics.txt -o /tmp/graphics.txt
python3 scripts/manual_ink/build_hanzi_subset.py /tmp/graphics.txt   # 產生 strokes-subset.json
python3 scripts/manual_ink/manual.py                                 # 產生手冊筆畫（含 App 內的授權檔）
```

改了手冊文字（`scripts/manual_ink/manual_text.py`）要先重跑第一步，字才會在子集裡。
