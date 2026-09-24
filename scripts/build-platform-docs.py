#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
scripts/build-platform-docs.py
-------------------------------
根據 docs/manual/manual.js 分別產生：
  docs/manual/manual-apple.js   — 適用 Apple 平台（iOS · iPadOS · macOS）
  docs/manual/manual-android.js — 適用 Android 平台

執行方式：
  python3 scripts/build-platform-docs.py

規則：
  Apple 版：
    - 移除 multi 節中「折疊螢幕 / Tabletop/Flex Mode」步驟與按鈕
    - 其餘保留（含 keys 鍵盤快捷鍵、桌機版視窗等 macOS 描述）

  Android 版：
    - 完整替換 keys 節為「觸控手勢與快速操作」（六語系）
    - multi 節移除「桌機」描述，保留折疊螢幕步驟
    - start 節「桌機版視窗左上角版本號」改為 Android 說明
    - faq 節「問題回報」答案改為 Android 說明
"""

import copy, io, json, os, re, sys


def swap(steps, orig, repl):
    """把含有 `orig` 特徵的那一步換成 `repl`。

    # 為什麼不是整句相等

    舊版用 `step == orig`。而那幾句裡含著版本號（「例如 Kairumo v4.2.1」）——
    版本一升，比對就失效，**改寫靜默地不再發生**，Android 的手冊從此叫
    使用者去看「桌機版視窗左上角」。那是 2026-09-22 實際發生的事：
    manual.js 裡已經是 v4.8.2，產生器裡還寫著 v4.2.1。

    改成比對一段不含版本號的特徵字串，版本再怎麼跳都不會脫鉤。
    真的脫鉤了也有第二道：`check_no_leak` 會擋下來。

    # 替換那一半也有同一個坑

    上面只修好了**比對**。替換文字裡還寫死著 `v4.2.1`，所以升版之後重新
    產生，會把 manual.js 已經更新的版本號**換回舊的** —— 而症狀出現在
    別的地方：CI 的「操作手冊各平台版與來源一致」在每一次升版之後變紅，
    看起來像手冊忘了重新產生。2026-09-24 實際發生（v4.9.0）。

    所以替換文字裡的版本號一律改寫成**當下的版本**，取自 `Cargo.toml`
    那個單一來源。寫死的那二十六處就此不必逐一維護。
    """
    if not orig or not repl:
        return steps
    key = re.sub(r"v\d+(\.\d+)*", "", orig)[:14].strip()
    repl = re.sub(r"v\d+(?:\.\d+)+", "v" + current_version(), repl)
    return [repl if key and key in st else st for st in steps]


def current_version():
    """版本的單一來源：`Cargo.toml` 的 workspace 版本。

    `scripts/check-version-consistency.sh` 守著它與其餘九處一致，所以從
    這裡讀就等於從所有地方讀。
    """
    global _VERSION
    if _VERSION is None:
        with io.open(os.path.join(REPO, "Cargo.toml"), encoding="utf-8") as f:
            match = re.search(r'^version\s*=\s*"([^"]+)"', f.read(), re.M)
        if not match:
            raise SystemExit("Cargo.toml 裡找不到版本號")
        _VERSION = match.group(1)
    return _VERSION


_VERSION = None

# ── 路徑 ──────────────────────────────────────────────────────────────
REPO = os.path.join(os.path.dirname(__file__), "..")
SRC  = os.path.join(REPO, "docs/manual/manual.js")
DEST_APPLE   = os.path.join(REPO, "docs/manual/manual-apple.js")
DEST_ANDROID = os.path.join(REPO, "docs/manual/manual-android.js")

# ── 掌拒靈敏度：入口兩端不同 ──────────────────────────────────────
#
# Apple：插入／工具選單裡的一項。
# Android：手繪模式工具列上的一顆晶片。
ANDROID_PALM_ORIG = {
 "zh-Hant": "手掌放在螢幕上會留下線條時，調「掌拒靈敏度」：在插入／工具選單裡找到它，用兩支滑桿調「接觸半徑門檻」與「筆落下時的收回時間窗」。**調壞了按「恢復預設」** —— 半徑調太低連筆尖都會被當成手掌，那時候畫布上什麼都畫不出來。",
 "en": "If resting your palm leaves marks, adjust “Palm rejection”: find it in the insert/tools menu and use the two sliders, “Touch radius threshold” and “Retract window when the pen lands”. **If it goes wrong, press “Restore defaults”** — set the radius too low and even the pen tip is treated as a palm, and then nothing draws at all.",
 "zh-Hans": "手掌放在屏幕上会留下线条时，调「掌拒灵敏度」：在插入／工具菜单里找到它，用两支滑杆调「接触半径阈值」与「笔落下时的收回时间窗」。**调坏了按「恢复默认」** —— 半径调太低连笔尖都会被当成手掌，那时候画布上什么都画不出来。",
 "ja": "手のひらを置くと線が残る場合は「パームリジェクション」を調整します。挿入／ツールメニューから開き、「接触半径のしきい値」と「ペンが触れたときの取り消し時間」の 2 つのスライダーで調整してください。**おかしくなったら「既定に戻す」を押します** —— 半径を下げすぎるとペン先まで手のひらと判定され、何も描けなくなります。",
 "ko": "손바닥을 올렸을 때 선이 남는다면 “손바닥 인식 차단”을 조정하세요. 삽입/도구 메뉴에서 열어 “접촉 반경 임계값”과 “펜이 닿을 때 되돌릴 시간” 두 슬라이더로 조정합니다. **잘못되면 “기본값 복원”을 누르세요** — 반경을 너무 낮추면 펜촉까지 손바닥으로 인식되어 아무것도 그려지지 않습니다.",
 "th": "หากวางฝ่ามือแล้วเกิดรอยเส้น ให้ปรับ “การปฏิเสธฝ่ามือ” เปิดจากเมนูแทรก/เครื่องมือ แล้วปรับด้วยแถบเลื่อนสองอัน คือ “เกณฑ์รัศมีการสัมผัส” และ “ช่วงเวลาย้อนกลับเมื่อปากกาแตะ” **หากผิดพลาดให้กด “คืนค่าเริ่มต้น”** เพราะถ้าตั้งรัศมีต่ำเกินไป ปลายปากกาจะถูกมองว่าเป็นฝ่ามือ และจะวาดอะไรไม่ได้เลย",
}

ANDROID_PALM_REPL = {
 "zh-Hant": "手掌放在螢幕上會留下線條時，調「掌拒靈敏度」：切到手繪模式，工具列上就有這顆按鈕（調過之後它會亮著）。用兩支滑桿調「接觸半徑門檻」與「筆落下時的收回時間窗」。**調壞了按「恢復預設」** —— 半徑調太低連筆尖都會被當成手掌，那時候畫布上什麼都畫不出來。",
 "en": "If resting your palm leaves marks, adjust “Palm rejection”: switch to drawing mode and the button is right there on the toolbar (it stays highlighted once you have changed it). Use the two sliders, “Touch radius threshold” and “Retract window when the pen lands”. **If it goes wrong, press “Restore defaults”** — set the radius too low and even the pen tip is treated as a palm, and then nothing draws at all.",
 "zh-Hans": "手掌放在屏幕上会留下线条时，调「掌拒灵敏度」：切到手绘模式，工具列上就有这颗按钮（调过之后它会亮着）。用两支滑杆调「接触半径阈值」与「笔落下时的收回时间窗」。**调坏了按「恢复默认」** —— 半径调太低连笔尖都会被当成手掌，那时候画布上什么都画不出来。",
 "ja": "手のひらを置くと線が残る場合は「パームリジェクション」を調整します。手書きモードに切り替えると、ツールバーにそのボタンがあります（変更後はハイライト表示されます）。「接触半径のしきい値」と「ペンが触れたときの取り消し時間」の 2 つのスライダーで調整してください。**おかしくなったら「既定に戻す」を押します** —— 半径を下げすぎるとペン先まで手のひらと判定され、何も描けなくなります。",
 "ko": "손바닥을 올렸을 때 선이 남는다면 “손바닥 인식 차단”을 조정하세요. 필기 모드로 전환하면 도구 막대에 해당 버튼이 있습니다(한 번 변경하면 계속 강조 표시됩니다). “접촉 반경 임계값”과 “펜이 닿을 때 되돌릴 시간” 두 슬라이더로 조정합니다. **잘못되면 “기본값 복원”을 누르세요** — 반경을 너무 낮추면 펜촉까지 손바닥으로 인식되어 아무것도 그려지지 않습니다.",
 "th": "หากวางฝ่ามือแล้วเกิดรอยเส้น ให้ปรับ “การปฏิเสธฝ่ามือ” สลับไปโหมดวาดมือ แล้วปุ่มนี้จะอยู่บนแถบเครื่องมือ (จะสว่างค้างไว้เมื่อคุณปรับแล้ว) ปรับด้วยแถบเลื่อนสองอัน คือ “เกณฑ์รัศมีการสัมผัส” และ “ช่วงเวลาย้อนกลับเมื่อปากกาแตะ” **หากผิดพลาดให้กด “คืนค่าเริ่มต้น”** เพราะถ้าตั้งรัศมีต่ำเกินไป ปลายปากกาจะถูกมองว่าเป็นฝ่ามือ และจะวาดอะไรไม่ได้เลย",
}

# ── Android keys 節（觸控手勢與快速操作）六語系完整內容 ─────────────
ANDROID_KEYS = {
    "zh-Hant": {
        "id": "keys",
        "title": "觸控手勢與快速操作",
        "lead": "不需要鍵盤，手指就能完成大部分操作。以下是最常用的手勢。",
        "buttons": [],
        "steps": [
            "**長按畫布**可喚起「徑向飛輪快捷盤」，向八個方向輕輕一揮即可切換筆刷、橡皮擦、套索等工具，手指不需抬回螢幕頂端。",
            "**雙指捏合或張開**可縮放畫布；**雙指拖曳**可平移畫布，兩者都不受手繪或打字模式影響。",
            "**在縮圖上長按**（頁面結構欄）會叫出快顯選單，等同於縮圖右上角的「\u22ef」，可插入、複製、搬移、刪除頁面。",
            "**長按文字方塊**可拖動；**拖右下角控制點**可調整大小；**雙指觸碰並旋轉**可旋轉物件。",
            "**從畫布左側邊緣向右滑**（若系統手勢未佔用）可快速呼出或收回左側結構欄。",
            "**三指輕掃向左**：復原。**三指輕掃向右**：重做。（實際效果取決於系統手勢設定。）"
        ],
        "tip": "手勢無法取代的操作（例如特殊符號輸入、插入連結），請點螢幕上的對應按鈕。",
        "fig": None
    },
    "en": {
        "id": "keys",
        "title": "Touch gestures and quick actions",
        "lead": "No keyboard required — your fingers handle most actions. Here are the most useful gestures.",
        "buttons": [],
        "steps": [
            "**Long-press the canvas** to summon the Radial Mark Menu; flick in 8 directions to switch tools (pen, eraser, lasso, undo, redo, colour, stabiliser) without reaching for the top bar.",
            "**Two-finger pinch or spread** to zoom the canvas; **two-finger drag** to pan. Both work in any mode.",
            "**Long-press a thumbnail** in the Pages panel to open its menu \u2014 same items as the \u201c\u22ef\u201d at the top right of each page (insert, duplicate, move, delete).",
            "**Long-press a text box** to drag it; **drag the bottom-right handle** to resize; **two-finger twist** to rotate any object.",
            "**Swipe from the canvas left edge inward** (if the system gesture is not claimed) to quickly show or hide the left structure panel.",
            "**Three-finger swipe left**: Undo. **Three-finger swipe right**: Redo. (Availability depends on your system gesture settings.)"
        ],
        "tip": "For actions that gestures cannot replace — such as inserting special symbols or links — tap the on-screen button.",
        "fig": None
    },
    "zh-Hans": {
        "id": "keys",
        "title": "触控手势与快速操作",
        "lead": "无需键盘，手指就能完成大部分操作。以下是最常用的手势。",
        "buttons": [],
        "steps": [
            "**长按画布**可唤起「径向飞轮快捷盘」，向八个方向轻轻一划即可切换画笔、橡皮擦、套索等工具，手指无需回到屏幕顶端。",
            "**双指捏合或张开**可缩放画布；**双指拖动**可平移画布，两者不受手绘或打字模式影响。",
            "**在缩略图上长按**（页面结构栏）会弹出快捷菜单，等同于缩略图右上角的「\u22ef」，可插入、复制、移动、删除页面。",
            "**长按文字框**可拖动；**拖右下角控制点**可调整大小；**双指触碰并旋转**可旋转对象。",
            "**从画布左侧边缘向右滑**（若系统手势未占用）可快速呼出或收回左侧结构栏。",
            "**三指向左滑**：撤销。**三指向右滑**：重做。（实际效果取决于系统手势设置。）"
        ],
        "tip": "手势无法替代的操作（例如特殊符号输入、插入链接），请点击屏幕上的对应按钮。",
        "fig": None
    },
    "ja": {
        "id": "keys",
        "title": "タッチジェスチャーとクイック操作",
        "lead": "キーボードがなくても、ほとんどの操作は指で完結します。よく使うジェスチャーをまとめました。",
        "buttons": [],
        "steps": [
            "**キャンバスを長押し**すると「ラジアルマークメニュー」が開きます。8方向に軽くフリックしてブラシ・消しゴム・なげなわなどのツールをトップバーへ戻らずに切り替えられます。",
            "**2本指のピンチイン／ピンチアウト**でキャンバスを拡大縮小。**2本指でドラッグ**してパンできます。モードを問わず使えます。",
            "**ページパネルのサムネイルを長押し**すると各ページの「\u22ef」と同じメニューが開きます（挿入・複製・移動・削除）。",
            "**テキストボックスを長押し**してドラッグ。**右下のハンドルをドラッグ**してサイズ変更。**2本指でつまみ回転**してオブジェクトを回転できます。",
            "**キャンバスの左端から内側へスワイプ**すると（システムのジェスチャーが割り当たっていない場合）、左の構造パネルをすばやく開閉できます。",
            "**3本指を左にスワイプ**：元に戻す。**3本指を右にスワイプ**：やり直す。（システムのジェスチャー設定によります。）"
        ],
        "tip": "ジェスチャーで代替できない操作（特殊記号の入力・リンクの挿入など）は、画面上のボタンをタップしてください。",
        "fig": None
    },
    "ko": {
        "id": "keys",
        "title": "터치 제스처와 빠른 작업",
        "lead": "키보드 없이도 손가락만으로 대부분의 작업을 할 수 있습니다. 자주 쓰는 제스처를 정리했습니다.",
        "buttons": [],
        "steps": [
            "**캔버스를 길게 누르면** 방사형 마크 메뉴가 열립니다. 8방향으로 살짝 밀어 브러시·지우개·올가미 등 도구를 상단 바로 돌아가지 않고 바꿀 수 있습니다.",
            "**두 손가락으로 핀치인/핀치아웃**하여 캔버스를 확대·축소하고, **두 손가락으로 드래그**하여 이동할 수 있습니다. 어느 모드에서도 사용할 수 있습니다.",
            "**페이지 패널의 썸네일을 길게 누르면** 각 페이지의 \"\u22ef\"와 동일한 메뉴가 열립니다 (삽입·복제·이동·삭제).",
            "**텍스트 상자를 길게 눌러** 드래그하고, **오른쪽 아래 핸들을 드래그**하여 크기를 조절합니다. **두 손가락으로 집어 돌리면** 개체를 회전할 수 있습니다.",
            "**캔버스 왼쪽 가장자리에서 안쪽으로 스와이프**하면 (시스템 제스처가 지정되어 있지 않은 경우) 왼쪽 구조 패널을 빠르게 열거나 닫을 수 있습니다.",
            "**세 손가락을 왼쪽으로 스와이프**: 실행 취소. **세 손가락을 오른쪽으로 스와이프**: 다시 실행. (시스템 제스처 설정에 따라 다를 수 있습니다.)"
        ],
        "tip": "제스처로 대체할 수 없는 작업 (특수 기호 입력·링크 삽입 등)은 화면의 버튼을 탭하세요.",
        "fig": None
    },
    "th": {
        "id": "keys",
        "title": "ท่าทางสัมผัสและการดำเนินการด่วน",
        "lead": "ไม่ต้องใช้แป้นพิมพ์ นิ้วมือเพียงอย่างเดียวก็จัดการได้เกือบทุกอย่าง นี่คือท่าทางที่ใช้บ่อยที่สุด",
        "buttons": [],
        "steps": [
            "**แตะค้างที่ผืนหน้ากระดาษ** เพื่อเรียก Radial Mark Menu เลื่อนนิ้วเบา ๆ ใน 8 ทิศทางเพื่อสลับเครื่องมือ (ปากกา ยางลบ ลาสโซ เลิกทำ ทำซ้ำ สี ตัวทำให้เส้นเรียบ) โดยไม่ต้องกลับขึ้นไปที่แถบด้านบน",
            "**บีบหรือกางนิ้วสองนิ้ว** เพื่อซูมเข้าและซูมออก **ลากสองนิ้ว** เพื่อเลื่อนหน้ากระดาษ ใช้ได้ทุกโหมด",
            "**แตะค้างที่ภาพขนาดย่อ** ในแผง Pages เพื่อเปิดเมนูเดียวกับ \"\u22ef\" ที่มุมขวาบนของแต่ละหน้า (แทรก ทำซ้ำ ย้าย ลบ)",
            "**แตะค้างกล่องข้อความ** เพื่อลากย้าย **ลากจุดจับมุมขวาล่าง** เพื่อปรับขนาด **บีบหมุนสองนิ้ว** เพื่อหมุนออบเจกต์",
            "**ปัดจากขอบซ้ายของผืนหน้ากระดาษเข้าด้านใน** (หากระบบไม่ได้กำหนดท่าทางนั้นไว้) เพื่อแสดงหรือซ่อนแผงโครงสร้างด้านซ้ายอย่างรวดเร็ว",
            "**ปัดสามนิ้วไปทางซ้าย**: เลิกทำ **ปัดสามนิ้วไปทางขวา**: ทำซ้ำ (ขึ้นอยู่กับการตั้งค่าท่าทางของระบบ)"
        ],
        "tip": "สำหรับการดำเนินการที่ท่าทางไม่สามารถทำแทนได้ เช่น การแทรกสัญลักษณ์พิเศษหรือลิงก์ ให้แตะปุ่มบนหน้าจอ",
        "fig": None
    }
}

# ── Android start 節中「桌機版本號」步驟的替換文字（六語系）─────────
ANDROID_START_DESKTOP_ORIG = {
    "zh-Hant": "桌機版視窗左上角會顯示版本號（例如 Kairumo v4.2.1），回報問題時請附上它。",
    "en":      "On desktop the window title shows the version (for example Kairumo v4.2.1) — include it when you report a problem.",
    "zh-Hans": "台式机版窗口左上角会显示版本号（例如 Kairumo v4.2.1），反馈问题时请附上它。",
    "ja":      "デスクトップ版ではウインドウのタイトルにバージョン（例：Kairumo v4.2.1）が表示されます。不具合報告の際は添えてください。",
    "ko":      "데스크톱에서는 창 제목에 버전(예: Kairumo v4.2.1)이 표시됩니다. 문제를 알릴 때 함께 적어 주세요.",
    "th":      "บนเดสก์ท็อป ชื่อหน้าต่างจะแสดงเวอร์ชัน (เช่น Kairumo v4.2.1) โปรดแจ้งมาด้วยเมื่อรายงานปัญหา"
}
ANDROID_START_DESKTOP_REPL = {
    "zh-Hant": "在設定頁面的「關於 Kairumo」可查看版本號（例如 v4.2.1），回報問題時請附上它。",
    "en":      "Find the version number in the app's About screen (for example Kairumo v4.2.1) and include it when you report a problem.",
    "zh-Hans": "在设置页面的「关于 Kairumo」可查看版本号（例如 v4.2.1），反馈问题时请附上它。",
    "ja":      "アプリの「設定」→「Kairumo について」でバージョン番号（例：Kairumo v4.2.1）を確認できます。不具合報告の際は添えてください。",
    "ko":      "앱 내 정보 화면에서 버전(예: Kairumo v4.2.1)을 확인할 수 있습니다. 문제를 알릴 때 함께 적어 주세요.",
    "th":      "ดูหมายเลขเวอร์ชัน (เช่น Kairumo v4.2.1) ได้ในหน้า 'เกี่ยวกับ Kairumo' ในการตั้งค่า โปรดแจ้งมาด้วยเมื่อรายงานปัญหา"
}

# ── Android start 節中「平板/桌機」首步替換文字（六語系）──────────────
ANDROID_START_TABLET_ORIG = {
    "zh-Hant": "平板、手機與桌機都能用；手寫用觸控筆最順，用手指或滑鼠一樣可以寫。",
    "en":      "Works on tablets, phones and desktops. A stylus feels best, but a finger or a mouse works too.",
    "zh-Hans": "平板、手机与台式机都能用；手写用触控笔最顺手，用手指或鼠标同样可以写。",
    "ja":      "タブレット・スマートフォン・デスクトップに対応。スタイラスが最適ですが、指やマウスでも書けます。",
    "ko":      "태블릿, 스마트폰, 데스크톱에서 사용할 수 있습니다. 스타일러스가 가장 자연스럽지만, 손가락도 됩니다.",
    "th":      "ใช้ได้บนแท็บเล็ต โทรศัพท์ และเดสก์ท็อป เขียนด้วยสไตลัสลื่นที่สุด แต่ใช้นิ้วหรือเมาส์ก็ได้"
}
ANDROID_START_TABLET_REPL = {
    "zh-Hant": "平板與手機都能用；手寫用觸控筆最順，用手指一樣可以寫。",
    "en":      "Works on tablets and phones. A stylus feels best, but a finger works fine too.",
    "zh-Hans": "平板和手机都能用；手写用触控笔最顺手，用手指同样可以写。",
    "ja":      "タブレット・スマートフォンに対応。スタイラスが最適ですが、指でも書けます。",
    "ko":      "태블릿과 스마트폰에서 사용할 수 있습니다. 스타일러스가 가장 자연스럽지만, 손가락도 됩니다.",
    "th":      "ใช้ได้บนแท็บเล็ตและโทรศัพท์ เขียนด้วยสไตลัสลื่นที่สุด แต่ใช้นิ้วก็ได้"
}

# ── Android faq 節中「問題回報」答案替換（六語系）──────────────────────
ANDROID_FAQ_REPORT_ORIG = {
    "zh-Hant": "請附上桌機版視窗左上角顯示的版本號（例如 Kairumo v4.2.1）與操作步驟。",
    "en":      "Include the version shown in the desktop window title (for example Kairumo v4.2.1) and the steps you took.",
    # 這裡原本寫著「zh-Hans faq 無此題」—— 那個註解是過期的，題目後來加上去了，
    # 於是簡中的 Android 使用者被叫去看「台式机版窗口」。現在補上。
    "zh-Hans": "请附上台式机版窗口左上角显示的版本号（例如 Kairumo v4.2.1）与操作步骤。",
    "ja":      "デスクトップ版のウインドウタイトルに表示されるバージョン（例：Kairumo v4.2.1）と、操作手順を添えてください。",
    "ko":      "데스크톱 창 제목에 보이는 버전(예: Kairumo v4.2.1)과 진행한 단계를 함께 알려 주세요。",
    "th":      "โปรดแจ้งเวอร์ชันที่แสดงบนชื่อหน้าต่างของเดสก์ท็อป (เช่น Kairumo v4.2.1) พร้อมขั้นตอนที่ทำ"
}
ANDROID_FAQ_REPORT_REPL = {
    "zh-Hant": "請附上版本號（在設定的「關於 Kairumo」查看，例如 Kairumo v4.2.1）與操作步驟。",
    "en":      "Include the version number (found in the app's About screen, for example Kairumo v4.2.1) and the steps you took.",
    "zh-Hans": "请附上版本号（在设置的「关于 Kairumo」查看，例如 Kairumo v4.2.1）与操作步骤。",
    "ja":      "アプリの「設定」→「Kairumo について」で確認できるバージョン（例：Kairumo v4.2.1）と、操作手順を添えてください。",
    "ko":      "앱 내 정보 화면에서 확인한 버전(예: Kairumo v4.2.1)과 진행한 단계를 함께 알려 주세요.",
    "th":      "โปรดแจ้งเวอร์ชัน (ดูได้ที่หน้า 'เกี่ยวกับ Kairumo' ในการตั้งค่า เช่น Kairumo v4.2.1) พร้อมขั้นตอนที่ทำ"
}

# ── Android multi 節「桌機」描述替換（六語系）─────────────────────────
ANDROID_MULTI_DESKTOP_ORIG = {
    "zh-Hant": "在平板或桌機上，用系統的分割畫面把 Kairumo 與相簿（或檔案、瀏覽器）並排。",
    "en":      "On a tablet or a desktop, use the system's split screen to put Kairumo next to your photo library (or files, or a browser).",
    "zh-Hans": "在平板或桌面设备上，用系统的分屏把 Kairumo 与相册（或文件、浏览器）并排。",
    "ja":      "タブレットやデスクトップでは、システムの分割表示で Kairumo と写真（またはファイル、ブラウザ）を並べます。",
    "ko":      "태블릿이나 데스크톱에서 시스템의 화면 분할로 Kairumo와 사진 보관함(또는 파일, 브라우저)을 나란히 둡니다.",
    "th":      "บนแท็บเล็ตหรือเครื่องตั้งโต๊ะ ใช้การแบ่งหน้าจอของระบบเพื่อวาง Kairumo ไว้ข้างคลังรูปภาพ (หรือไฟล์ หรือเบราว์เซอร์)"
}
ANDROID_MULTI_DESKTOP_REPL = {
    "zh-Hant": "在平板或大螢幕裝置上，用系統的分割畫面把 Kairumo 與相簿（或檔案、瀏覽器）並排。",
    "en":      "On a tablet or a large-screen device, use the system's split screen to put Kairumo next to your photo library (or files, or a browser).",
    "zh-Hans": "在平板或大屏设备上，用系统的分屏把 Kairumo 与相册（或文件、浏览器）并排。",
    "ja":      "タブレットや大画面端末では、システムの分割表示で Kairumo と写真（またはファイル、ブラウザ）を並べます。",
    "ko":      "태블릿이나 대화면 기기에서 시스템의 화면 분할로 Kairumo와 사진 보관함(또는 파일, 브라우저)을 나란히 둡니다.",
    "th":      "บนแท็บเล็ตหรืออุปกรณ์หน้าจอใหญ่ ใช้การแบ่งหน้าจอของระบบเพื่อวาง Kairumo ไว้ข้างคลังรูปภาพ (หรือไฟล์ หรือเบราว์เซอร์)"
}

# ── Apple multi 節中「折疊螢幕」步驟識別字串（六語系）────────────────
APPLE_MULTI_FOLDABLE_FRAGMENTS = {
    "zh-Hant": "折疊螢幕裝置半折立起",
    "en":      "half-folding a foldable device",
    "zh-Hans": "折叠屏设备半折立起",
    "ja":      "折りたたみ端末を半折りに",
    "ko":      "폴더블 기기를 반으로 접어",
    "th":      "ตั้งอุปกรณ์จอพับครึ่งหนึ่ง"
}

# ── Apple multi 節中要移除的按鈕名稱（六語系）────────────────────────
APPLE_MULTI_FOLDABLE_BUTTONS = {
    "zh-Hant": "立起懸停模式",
    "en":      "Tabletop / Flex Mode",
    "zh-Hans": "立起悬停模式",
    "ja":      "テーブルトップ／フレックスモード",
    "ko":      "테이블탑 / 플렉스 모드",
    "th":      "โหมดตั้งโต๊ะ / เฟล็กซ์"
}


def build_apple(data):
    d = copy.deepcopy(data)
    for locale in [k for k in d if k != "figsets"]:
        frag   = APPLE_MULTI_FOLDABLE_FRAGMENTS[locale]
        btn    = APPLE_MULTI_FOLDABLE_BUTTONS[locale]
        for sec in d[locale]["sections"]:
            if sec["id"] == "multi":
                # 移除包含折疊螢幕的步驟
                sec["steps"] = [s for s in sec["steps"] if frag not in s]
                # 移除按鈕
                sec["buttons"] = [b for b in sec.get("buttons", []) if b != btn]
    return d


def build_android(data):
    d = copy.deepcopy(data)
    for locale in [k for k in d if k != "figsets"]:
        for sec in d[locale]["sections"]:

            # 1. start：替換「桌機版視窗」與「平板/桌機」首步
            if sec["id"] == "start":
                tablet_orig  = ANDROID_START_TABLET_ORIG.get(locale)
                tablet_repl  = ANDROID_START_TABLET_REPL.get(locale)
                desktop_orig = ANDROID_START_DESKTOP_ORIG.get(locale)
                desktop_repl = ANDROID_START_DESKTOP_REPL.get(locale)
                steps = sec.get("steps", [])
                steps = swap(steps, tablet_orig, tablet_repl)
                steps = swap(steps, desktop_orig, desktop_repl)
                sec["steps"] = steps

            # 2. keys：完整替換為觸控手勢節
            elif sec["id"] == "keys":
                for k, v in ANDROID_KEYS[locale].items():
                    sec[k] = v

            # 3. multi：替換首步「桌機」描述，保留折疊螢幕
            elif sec["id"] == "multi":
                orig = ANDROID_MULTI_DESKTOP_ORIG.get(locale)
                repl = ANDROID_MULTI_DESKTOP_REPL.get(locale)
                sec["steps"] = swap(sec.get("steps", []), orig, repl)

            # 4. write：掌拒靈敏度的入口兩端不同
            #
            # Apple 放在插入／工具選單裡，Android 是手繪工具列上的晶片。
            # 不改的話，Android 的手冊會叫使用者去一個不存在的地方 ——
            # 那對零基礎的讀者是死路。
            elif sec["id"] == "write":
                orig = ANDROID_PALM_ORIG.get(locale)
                repl = ANDROID_PALM_REPL.get(locale)
                sec["steps"] = swap(sec.get("steps", []), orig, repl)

            # 5. faq：替換「問題回報」答案
            elif sec["id"] == "faq":
                orig_a = ANDROID_FAQ_REPORT_ORIG.get(locale)
                repl_a = ANDROID_FAQ_REPORT_REPL.get(locale)
                if orig_a and repl_a:
                    key = re.sub(r"v\d+(\.\d+)*", "", orig_a)[:14].strip()
                    for qa in sec.get("faq", []):
                        if key and key in qa[1]:
                            qa[1] = repl_a
    return d


# `--check`：只驗證不寫檔（CI 用這條）。
#
# 產出是**產物**。有人改了 manual.js 卻沒重跑產生器，或直接改了產物，
# 兩個 App 打包進去的就是對不上來源的那一份 —— 而那不會有任何錯誤訊息，
# 只是使用者讀到的說明是錯的。
CHECK = "--check" in sys.argv
STALE = []


def write_js(data, dest, comment):
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    payload = json.dumps(data, ensure_ascii=False, indent=2)
    content = f"/*\n{comment}\n */\n\nwindow.KAIRUMO_MANUAL = {payload};\n"
    if CHECK:
        have = open(dest, encoding="utf-8").read() if os.path.exists(dest) else ""
        if have != content:
            STALE.append(os.path.relpath(dest, REPO))
        return
    with open(dest, "w", encoding="utf-8") as f:
        f.write(content)
    print(f"✅ 已產生 {os.path.relpath(dest, REPO)}")


def main():
    # 解析原始 manual.js
    src_text = open(SRC, encoding="utf-8").read()
    m = re.search(r"window\.KAIRUMO_MANUAL\s*=\s*(\{.*\})\s*;?\s*$", src_text, re.DOTALL)
    if not m:
        print("❌ 無法解析 manual.js 的 JSON", file=sys.stderr)
        sys.exit(1)
    base = json.loads(m.group(1))

    apple_data   = build_apple(base)
    android_data = build_android(base)

    write_js(apple_data, DEST_APPLE,
             " * Kairumo 操作手冊（Apple 平台版）\n"
             " * 適用：iOS · iPadOS · macOS\n"
             " * 本檔案由 scripts/build-platform-docs.py 自動產生，請勿手動修改。\n"
             " * 來源：docs/manual/manual.js")

    write_js(android_data, DEST_ANDROID,
             " * Kairumo 操作手冊（Android 平台版）\n"
             " * 適用：Android\n"
             " * 本檔案由 scripts/build-platform-docs.py 自動產生，請勿手動修改。\n"
             " * 來源：docs/manual/manual.js")

    # 簡單驗證
    for locale in [k for k in base if k != "figsets"]:
        a_sec_ids = [s["id"] for s in apple_data[locale]["sections"]]
        and_sec_ids = [s["id"] for s in android_data[locale]["sections"]]
        assert "keys" in a_sec_ids,   f"Apple/{locale} 缺少 keys 節"
        assert "keys" in and_sec_ids, f"Android/{locale} 缺少 keys 節"
        # Apple 版不應含 foldable 描述
        apple_multi = next(s for s in apple_data[locale]["sections"] if s["id"] == "multi")
        frag = APPLE_MULTI_FOLDABLE_FRAGMENTS[locale]
        assert not any(frag in step for step in apple_multi["steps"]), \
            f"Apple/{locale} multi 節仍含折疊螢幕描述"
    check_no_leak(apple_data, android_data)
    if STALE:
        print("❌ 這幾份與 manual.js 不一致：" + "、".join(STALE), file=sys.stderr)
        print("   手冊只維護 docs/manual/manual.js，", file=sys.stderr)
        print("   另外兩份請跑 python3 scripts/build-platform-docs.py 重新產生。", file=sys.stderr)
        sys.exit(1)
    print("✅ 基本驗證通過")


# ── 平台用語洩漏檢查 ──────────────────────────────────────────────
#
# 2026-09-22：Android 的手冊裡有兩句叫使用者去看「桌機版視窗左上角」。
# 改寫規則其實寫了，只是比對的原文含著版本號，版本一升就對不上，
# **改寫靜默地不再發生**。沒有人會去讀產生出來的六語系 JSON 找這種東西。
#
# 所以把「不准出現」寫成會擋下來的檢查。字詞刻意挑得保守 ——
# 誤擋一個字的代價是改一行文案；漏掉一個字的代價是使用者照著手冊
# 去找一個不存在的東西，然後以為是自己笨。
APPLE_FORBIDDEN = ["Android", "android", "Google Play", "S Pen", "Samsung"]
ANDROID_FORBIDDEN = [
    "iPad", "iPhone", "iPadOS", "macOS", "iCloud", "Apple Pencil",
    "桌機", "デスクトップ", "데스크톱", "台式机",
]


def check_no_leak(apple_data, android_data):
    """一端的手冊不准出現另一端才有的東西。"""
    problems = []
    for name, data, forbidden in (
        ("manual-apple.js", apple_data, APPLE_FORBIDDEN),
        ("manual-android.js", android_data, ANDROID_FORBIDDEN),
    ):
        blob = json.dumps(data, ensure_ascii=False)
        for word in forbidden:
            if word in blob:
                problems.append(f"{name} 出現了「{word}」")
    if problems:
        print("❌ 平台用語洩漏：", file=sys.stderr)
        for p2 in problems:
            print("   " + p2, file=sys.stderr)
        print(
            "\n改寫規則可能與 manual.js 的原文脫鉤了（常見原因：原文含版本號，"
            "版本一升就對不上）。\n修 build-platform-docs.py 的對照表，不要去改產生出來的檔案。",
            file=sys.stderr,
        )
        sys.exit(1)


if __name__ == "__main__":
    main()
