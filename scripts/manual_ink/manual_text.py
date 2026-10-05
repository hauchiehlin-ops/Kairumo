"""《Kairumo手冊》要手寫進筆記本的文字。

內容對照 `docs/manual/manual.js` 的實際做法（目錄點選跳段、依操作順序排列、步驟編號、
「小提醒」、實機截圖、按鈕清單、六個語系、圖說註明截圖語言），不寫手冊做不到的事。
只放繁體中文；筆順資料見 `third_party/makemeahanzi/`。
"""

HEADINGS = {
    "s1": "一、結構化的資訊呈現",
    "s2": "二、視覺化的直觀設計",
    "s3": "三、多語言的友善支援",
    "s4": "總結",
}
TITLE_CJK = "優勢"
SUBTITLE = "三大特色，一本手冊說清楚。"

SECTIONS = {
    "s1": {
        "lead": "先立好路標，再上路。",
        "points": [
            "目錄一點即達，想看哪一段，點一下就到，不必從頭翻起。",
            "章節依實際操作的順序排列，一步接著一步，跟著做就會。",
            "每個步驟都編上號碼，重點另用「小提醒」標出，不怕漏看。",
        ],
    },
    "s2": {
        "lead": "看圖，比讀字更快。",
        "points": [
            "每一章附上實機截圖，看圖就知道要按哪裡。",
            "會用到的按鈕逐一列出名稱，畫面上找得到，手冊裡也對得上。",
            "以色彩區分段落，再配上圖示與提示，一眼就能分清層次。",
        ],
    },
    "s3": {
        "lead": "一份手冊，六種語言。",
        "points": [
            "繁體中文、簡體中文、英文、日文、韓文、泰文，六種語言同步更新。",
            "各語系結構一致，切換語言不會迷路，內容也不會缺漏。",
            "圖說註明截圖的語言，讓不同語言的使用者都能順利對照。",
        ],
    },
    "s4": {
        "lead": "結構清楚、圖文直觀、語言友善。",
        "points": [
            "結構化：路標清楚，上手不繞路。",
            "視覺化：圖文並陳，一看就懂。",
            "多語言：六種語言，人人都能讀。",
        ],
        "closing": "讓每個人，都能輕鬆上手 Kairumo。",
        "seal": "手冊",
    },
}

FOOTER_BRAND = "Kairumo"
FOOTER_PAGE = ["第一頁", "第二頁", "第三頁", "第四頁"]

# 全形標點：筆順資料集沒有，由 hanzi.py 手繪。
PUNCT = set("，。、：；「」（）")


def all_text() -> str:
    parts = list(HEADINGS.values()) + [TITLE_CJK, SUBTITLE] + FOOTER_PAGE
    for s in SECTIONS.values():
        parts.append(s["lead"])
        parts += s["points"]
        parts.append(s.get("closing", ""))
        parts.append(s.get("seal", ""))
    return "".join(parts)


def cjk_chars() -> list:
    seen = []
    for ch in all_text():
        if ch in PUNCT or ch.isascii() or ch == " ":
            continue
        if ch not in seen:
            seen.append(ch)
    return seen
