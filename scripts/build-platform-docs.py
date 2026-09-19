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

import copy, json, os, re, sys

# ── 路徑 ──────────────────────────────────────────────────────────────
REPO = os.path.join(os.path.dirname(__file__), "..")
SRC  = os.path.join(REPO, "docs/manual/manual.js")
DEST_APPLE   = os.path.join(REPO, "docs/manual/manual-apple.js")
DEST_ANDROID = os.path.join(REPO, "docs/manual/manual-android.js")

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
    "zh-Hans": None,   # zh-Hans faq 無此題
    "ja":      "デスクトップ版のウインドウタイトルに表示されるバージョン（例：Kairumo v4.2.1）と、操作手順を添えてください。",
    "ko":      "데스크톱 창 제목에 보이는 버전(예: Kairumo v4.2.1)과 진행한 단계를 함께 알려 주세요。",
    "th":      "โปรดแจ้งเวอร์ชันที่แสดงบนชื่อหน้าต่างของเดสก์ท็อป (เช่น Kairumo v4.2.1) พร้อมขั้นตอนที่ทำ"
}
ANDROID_FAQ_REPORT_REPL = {
    "zh-Hant": "請附上版本號（在設定的「關於 Kairumo」查看，例如 Kairumo v4.2.1）與操作步驟。",
    "en":      "Include the version number (found in the app's About screen, for example Kairumo v4.2.1) and the steps you took.",
    "zh-Hans": None,
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
                new_steps = []
                for step in sec.get("steps", []):
                    if tablet_orig and step == tablet_orig:
                        new_steps.append(tablet_repl)
                    elif desktop_orig and step == desktop_orig:
                        new_steps.append(desktop_repl)
                    else:
                        new_steps.append(step)
                sec["steps"] = new_steps

            # 2. keys：完整替換為觸控手勢節
            elif sec["id"] == "keys":
                for k, v in ANDROID_KEYS[locale].items():
                    sec[k] = v

            # 3. multi：替換首步「桌機」描述，保留折疊螢幕
            elif sec["id"] == "multi":
                orig = ANDROID_MULTI_DESKTOP_ORIG.get(locale)
                repl = ANDROID_MULTI_DESKTOP_REPL.get(locale)
                if orig and repl:
                    sec["steps"] = [repl if s == orig else s for s in sec.get("steps", [])]

            # 4. faq：替換「問題回報」答案
            elif sec["id"] == "faq":
                orig_a = ANDROID_FAQ_REPORT_ORIG.get(locale)
                repl_a = ANDROID_FAQ_REPORT_REPL.get(locale)
                if orig_a and repl_a:
                    for qa in sec.get("faq", []):
                        if qa[1] == orig_a:
                            qa[1] = repl_a
    return d


def write_js(data, dest, comment):
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    payload = json.dumps(data, ensure_ascii=False, indent=2)
    content = f"/*\n{comment}\n */\n\nwindow.KAIRUMO_MANUAL = {payload};\n"
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
    print("✅ 基本驗證通過")


if __name__ == "__main__":
    main()
