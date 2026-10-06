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


# 結語的前半（手寫版是「結語＋手繪 Kairumo＋句號」三段拼起來）。
CLOSING = "讓每個人，都能輕鬆上手"


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


# ---- 其他語言：排版文字（不是手寫） ------------------------------------------------
#
# 手寫只有繁體中文：筆順資料集（makemeahanzi）只有漢字，沒有假名、諺文、泰文，也沒有簡體字的
# 逐字下載授權。所以其他語言的手冊用**同一套手繪插圖**，文字用該語言的字型排進文字方塊
# （位置與繁中版的手寫字完全對應）。簡體中文由繁體逐字＋詞彙轉換產生（見 `manual.py` 的 `zh_hans`），
# 需要人工校對時直接改這裡。

TYPED = {
    "zhHans": {
        "headings": {
            "s1": "一、结构化的信息呈现",
            "s2": "二、视觉化的直观设计",
            "s3": "三、多语言的友好支持",
            "s4": "总结"
        },
        "title": "优势",
        "subtitle": "三大特色，一本手册说清楚。",
        "sections": {
            "s1": {
                "lead": "先立好路标，再上路。",
                "points": [
                    "目录一点即达，想看哪一段，点一下就到，不必从头翻起。",
                    "章节依实际操作的顺序排列，一步接着一步，跟着做就会。",
                    "每个步骤都编上号码，重点另用「小提醒」标出，不怕漏看。"
                ]
            },
            "s2": {
                "lead": "看图，比读字更快。",
                "points": [
                    "每一章附上实机截图，看图就知道要按哪里。",
                    "会用到的按钮逐一列出名称，画面上找得到，手册里也对得上。",
                    "以色彩区分段落，再配上图标与提示，一眼就能分清层次。"
                ]
            },
            "s3": {
                "lead": "一份手册，六种语言。",
                "points": [
                    "繁体中文、简体中文、英文、日文、韩文、泰文，六种语言同步更新。",
                    "各语言结构一致，切换语言不会迷路，内容也不会缺漏。",
                    "图说注明截图的语言，让不同语言的使用者都能顺利对照。"
                ]
            },
            "s4": {
                "lead": "结构清楚、图文直观、语言友善。",
                "points": [
                    "结构化：路标清楚，上手不绕路。",
                    "视觉化：图文并陈，一看就懂。",
                    "多语言：六种语言，人人都能读。"
                ],
                "closing": "让每个人，都能轻松上手 Kairumo。",
                "seal": "手册"
            }
        },
        "footer": [
            "第一页",
            "第二页",
            "第三页",
            "第四页"
        ]
    },
    "en": {
        "headings": {"s1": "1. Structured information", "s2": "2. Visual, intuitive design",
                     "s3": "3. Friendly multilingual support", "s4": "Summary"},
        "title": "Advantages",
        "subtitle": "Three highlights, one manual.",
        "sections": {
            "s1": {"lead": "Put up the signposts, then set off.", "points": [
                "The table of contents takes you straight there: tap a section and you are on it, with no need to flip from the start.",
                "Chapters follow the order you actually work in, one step after another, so you can simply follow along.",
                "Every step is numbered and key points are called out as tips, so nothing gets missed."]},
            "s2": {"lead": "A picture beats a paragraph.", "points": [
                "Each chapter has real screenshots, so you can see exactly where to tap.",
                "Every button you will use is listed by name, so you can find it on screen and match it in the manual.",
                "Colour separates the sections, and icons and hints bring out the layers at a glance."]},
            "s3": {"lead": "One manual, six languages.", "points": [
                "Traditional Chinese, Simplified Chinese, English, Japanese, Korean and Thai are updated together.",
                "Every language has the same structure, so switching languages never loses you and nothing is missing.",
                "Captions state the language of each screenshot, so users of any language can follow along."]},
            "s4": {"lead": "Clear structure, intuitive visuals, friendly languages.", "points": [
                "Structured: clear signposts, no detours.",
                "Visual: pictures and words together, understood at a glance.",
                "Multilingual: six languages, readable by everyone."],
                "closing": "Let everyone get started with Kairumo with ease.", "seal": "MANUAL"},
        },
        "footer": ["Page 1", "Page 2", "Page 3", "Page 4"],
    },
    "ja": {
        "headings": {"s1": "1. 構造化された情報", "s2": "2. 見て分かる直感的なデザイン",
                     "s3": "3. 多言語への親切な対応", "s4": "まとめ"},
        "title": "の強み",
        "subtitle": "3 つの特長を、1 冊のマニュアルで。",
        "sections": {
            "s1": {"lead": "まず道しるべを立ててから、出発しましょう。", "points": [
                "目次からワンタップで移動できます。読みたい箇所をタップするだけで、最初から読み返す必要はありません。",
                "章は実際の操作の順番に並んでいます。手順を追って進めれば、自然に使いこなせます。",
                "すべての手順に番号を付け、重要な点は「ヒント」として目立たせているので、見落としません。"]},
            "s2": {"lead": "文章よりも、図のほうが早く伝わります。", "points": [
                "各章に実機のスクリーンショットを載せています。どこを押すのか、ひと目で分かります。",
                "使うボタンはすべて名前を挙げています。画面でもマニュアルでも見つけられます。",
                "色でセクションを分け、アイコンとヒントを添えて、構成がひと目で分かります。"]},
            "s3": {"lead": "1 冊のマニュアルで、6 つの言語。", "points": [
                "繁体字中国語・簡体字中国語・英語・日本語・韓国語・タイ語の 6 言語を同時に更新しています。",
                "どの言語も同じ構成なので、言語を切り替えても迷わず、内容の抜けもありません。",
                "図の説明にスクリーンショットの言語を明記しているので、どの言語の方も見比べやすくなっています。"]},
            "s4": {"lead": "分かりやすい構成、直感的な図解、やさしい言語対応。", "points": [
                "構造化: 道しるべが明確で、遠回りしません。",
                "視覚化: 図と文章で、見てすぐ分かります。",
                "多言語: 6 つの言語で、誰でも読めます。"],
                "closing": "誰もが気軽に Kairumo を使い始められるように。", "seal": "手引"},
        },
        "footer": ["1 ページ目", "2 ページ目", "3 ページ目", "4 ページ目"],
    },
    "ko": {
        "headings": {"s1": "1. 체계적인 정보 구성", "s2": "2. 한눈에 들어오는 직관적인 디자인",
                     "s3": "3. 다국어를 위한 친절한 지원", "s4": "요약"},
        "title": "강점",
        "subtitle": "세 가지 특징을 매뉴얼 한 권으로.",
        "sections": {
            "s1": {"lead": "이정표를 먼저 세우고 출발하세요.", "points": [
                "목차에서 한 번만 누르면 바로 이동합니다. 보고 싶은 부분을 누르면 처음부터 넘겨 볼 필요가 없습니다.",
                "장은 실제로 조작하는 순서대로 배치되어 있어, 한 단계씩 따라 하면 자연스럽게 익힐 수 있습니다.",
                "모든 단계에 번호를 붙이고 중요한 내용은 ‘팁’으로 따로 표시해 놓치지 않게 했습니다."]},
            "s2": {"lead": "글보다 그림이 더 빠릅니다.", "points": [
                "각 장에 실제 기기 화면을 실어, 어디를 눌러야 하는지 그림만 봐도 알 수 있습니다.",
                "사용하는 버튼은 이름을 하나하나 적어 두어, 화면에서도 매뉴얼에서도 쉽게 찾을 수 있습니다.",
                "색으로 단락을 구분하고 아이콘과 안내를 더해, 구조가 한눈에 보입니다."]},
            "s3": {"lead": "매뉴얼 한 권, 여섯 가지 언어.", "points": [
                "번체 중국어, 간체 중국어, 영어, 일본어, 한국어, 태국어 여섯 가지 언어를 함께 업데이트합니다.",
                "모든 언어의 구성이 같아서 언어를 바꿔도 길을 잃지 않고 빠지는 내용도 없습니다.",
                "그림 설명에 화면 캡처의 언어를 밝혀 두어, 어느 언어를 쓰는 분이든 쉽게 비교할 수 있습니다."]},
            "s4": {"lead": "명확한 구조, 직관적인 그림, 친절한 언어.", "points": [
                "체계적: 이정표가 분명해 돌아가지 않습니다.",
                "시각적: 그림과 글을 함께 두어 보자마자 이해됩니다.",
                "다국어: 여섯 가지 언어로 누구나 읽을 수 있습니다."],
                "closing": "누구나 쉽게 Kairumo를 시작할 수 있도록.", "seal": "매뉴얼"},
        },
        "footer": ["1페이지", "2페이지", "3페이지", "4페이지"],
    },
    "th": {
        "headings": {"s1": "1. ข้อมูลที่จัดเป็นระบบ", "s2": "2. การออกแบบที่เข้าใจได้ในพริบตา",
                     "s3": "3. รองรับหลายภาษาอย่างเป็นมิตร", "s4": "สรุป"},
        "title": "จุดเด่น",
        "subtitle": "สามจุดเด่น ในคู่มือเล่มเดียว",
        "sections": {
            "s1": {"lead": "ปักหลักนำทางก่อน แล้วค่อยออกเดินทาง", "points": [
                "สารบัญแตะครั้งเดียวก็ถึง อยากดูส่วนไหนก็แตะได้เลย ไม่ต้องไล่เปิดจากหน้าแรก",
                "บทต่าง ๆ เรียงตามลำดับการใช้งานจริง ทำตามทีละขั้นก็ใช้เป็น",
                "ทุกขั้นตอนมีหมายเลขกำกับ และจุดสำคัญถูกเน้นเป็น “เคล็ดลับ” จึงไม่พลาด"]},
            "s2": {"lead": "ดูภาพ เข้าใจเร็วกว่าอ่านตัวอักษร", "points": [
                "ทุกบทมีภาพหน้าจอจริง ดูภาพก็รู้ว่าต้องกดตรงไหน",
                "ปุ่มที่ต้องใช้มีชื่อกำกับครบ หาเจอทั้งบนหน้าจอและในคู่มือ",
                "ใช้สีแยกแต่ละส่วน พร้อมไอคอนและคำแนะนำ ทำให้เห็นลำดับชั้นได้ในพริบตา"]},
            "s3": {"lead": "คู่มือเล่มเดียว หกภาษา", "points": [
                "จีนตัวเต็ม จีนตัวย่อ อังกฤษ ญี่ปุ่น เกาหลี และไทย อัปเดตพร้อมกันทั้งหกภาษา",
                "ทุกภาษามีโครงสร้างเหมือนกัน สลับภาษาแล้วไม่หลง และเนื้อหาไม่ขาดหาย",
                "คำบรรยายภาพระบุภาษาของภาพหน้าจอ ผู้ใช้ทุกภาษาจึงเทียบกันได้สะดวก"]},
            "s4": {"lead": "โครงสร้างชัด ภาพเข้าใจง่าย ภาษาเป็นมิตร", "points": [
                "เป็นระบบ: ป้ายนำทางชัดเจน ไม่อ้อมทาง",
                "เห็นภาพ: มีทั้งภาพและข้อความ มองปุ๊บเข้าใจ",
                "หลายภาษา: หกภาษา ทุกคนอ่านได้"],
                "closing": "ให้ทุกคนเริ่มใช้ Kairumo ได้อย่างสบาย ๆ", "seal": "คู่มือ"},
        },
        "footer": ["หน้า 1", "หน้า 2", "หน้า 3", "หน้า 4"],
    },
}

# 繁體中文的結語（手寫版是「結語＋手繪 Kairumo＋句號」三段拼起來，排版版需要整句）。
ZH_HANT_CLOSING = "讓每個人，都能輕鬆上手 Kairumo。"


# ---- 簡體中文的手寫版 ---------------------------------------------------------------
#
# 筆順資料集（makemeahanzi）以簡體字為主，簡體手冊因此也能手寫。文字來自 `TYPED["zhHans"]`
# （同一份，所以排版版與手寫版不會各說各話），整理成與上面繁體版同樣的欄位，讓版面程式不必分兩套。
from types import SimpleNamespace as _NS  # noqa: E402

_H = TYPED["zhHans"]
HANS = _NS(
    HEADINGS=_H["headings"],
    TITLE_CJK=_H["title"],
    SUBTITLE=_H["subtitle"],
    SECTIONS=_H["sections"],
    FOOTER_PAGE=_H["footer"],
    CLOSING="让每个人，都能轻松上手",
    PUNCT=PUNCT,
)
del _H


def hans_text() -> str:
    parts = list(HANS.HEADINGS.values()) + [HANS.TITLE_CJK, HANS.SUBTITLE, HANS.CLOSING] + HANS.FOOTER_PAGE
    for s in HANS.SECTIONS.values():
        parts.append(s["lead"])
        parts += s["points"]
        parts.append(s.get("closing", ""))
        parts.append(s.get("seal", ""))
    return "".join(parts)


def cjk_chars_all() -> list:
    """繁體版與簡體版手寫用到的全部漢字（不含全形標點）。"""
    seen = []
    for ch in all_text() + hans_text():
        if ch in PUNCT or ch.isascii() or ch == " " or ch in seen:
            continue
        seen.append(ch)
    return seen
