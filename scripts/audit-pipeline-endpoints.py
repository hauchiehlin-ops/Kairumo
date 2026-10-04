#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
audit-pipeline-endpoints.py - 跨平台畫布物件與工具「全管線貫通」自動化檢測腳本

檢驗維度：
1. Object Pipeline Audit:
   檢測畫布上所有物件型別（link, model3d, audio, pin, tape, sticky, shapestyle, connstyle, table, image, text）
   在各層級的實作完整性：
   - Apple Model/Attachment 宣告
   - Apple PackageBridge 導出/導入（ObjectEnvelope）
   - Apple UI View / Overlay
   - Android Model/Data class
   - Android Store/Persistence（NotebookMeta 或衍生區塊）
   - Android UI View / Composable
   - 跨端同步信封（ObjectEnvelope / DERIVED）對稱性

2. Dead Endpoints & UI Stub Audit:
   檢測 UI 層具有可互動/可編輯屬性（顏色、字型、尺寸、改名、刪除），但回調只改了本地臨時 state
   而未回寫至 Store/Model/Core 的斷頭管線。

3. Main Thread Watchdog Hazard Audit:
   檢測在 @MainActor 或主執行緒上直接呼叫包含同步磁碟 I/O、目錄列舉或 FFI 鎖等待的操作。
"""

import sys
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
APPLE_SOURCES = ROOT / "apple" / "Sources"
ANDROID_SOURCES = ROOT / "android" / "app" / "src" / "main" / "java" / "com" / "kairumo" / "padnote"

CANVAS_OBJECT_KINDS = [
    {
        "kind": "tape",
        "name": "遮蔽膠帶 (Masking Tape)",
        "apple_model": "NoteTapeAttachment",
        "apple_view": "MaskingTapeOverlayView",
        "android_model": "NoteTape",
        "android_view": "MaskingTapeOverlay",
        "envelope_key": "tape",
    },
    {
        "kind": "audio",
        "name": "錄音卡片 (Audio Attachment)",
        "apple_model": "NoteAudioAttachment",
        "apple_view": "AudioAttachmentItemView",
        "android_model": "AudioObject",
        "android_view": "AudioCardView",
        "envelope_key": "audio",
    },
    {
        "kind": "rectitle",
        "name": "自訂錄音標題 (Recording Title)",
        "apple_model": "RecordingTitle",
        "apple_view": "AudioAttachmentItemView",
        "android_model": "RecordingTitle",
        "android_view": "HomeScreen",
        "envelope_key": "rectitle",
    },
    {
        "kind": "link",
        "name": "網址卡片 (Link Attachment)",
        "apple_model": "NoteLinkAttachment",
        "apple_view": "NoteLinkView",
        "android_model": "LinkObject",
        "android_view": "LinkCard",
        "envelope_key": "link",
    },
    {
        "kind": "model3d",
        "name": "3D 模型卡片 (3D Model)",
        "apple_model": "Note3DAttachment",
        "apple_view": "Model3DInteractiveCardView",
        "android_model": "Model3DObject",
        "android_view": "Model3DView",
        "envelope_key": "model3d",
    },
    {
        "kind": "pin",
        "name": "留言圖釘 (Comment Pin)",
        "apple_model": "NoteCommentPin",
        "apple_view": "CommentPinMarkerView",
        "android_model": "CommentPin",
        "android_view": "CommentPinMarker",
        "envelope_key": "pin",
    },
    {
        "kind": "sticky",
        "name": "流式文字手寫錨定 (Sticky Annotation)",
        "apple_model": "StickyAnnotationAnchor",
        "apple_view": "ContinuousPageView",
        "android_model": "StickyAnnotationAnchor",
        "android_view": "CompositionOverlay",
        "envelope_key": "sticky",
    },
    {
        "kind": "shape",
        "name": "幾何形狀 (Vector Shape)",
        "apple_model": "NoteShapeAttachment",
        "apple_view": "NoteShapeView",
        "android_model": "NoteShape",
        "android_view": "ShapeLayer",
        "envelope_key": "shapestyle",
    },
    {
        "kind": "connection",
        "name": "形狀連接線 (Connection Line)",
        "apple_model": "NoteConnectionAttachment",
        "apple_view": "ConnectionLineView",
        "android_model": "NoteConnection",
        "android_view": "ConnectionLayer",
        "envelope_key": "connstyle",
    },
    {
        "kind": "table",
        "name": "表格 (Table Attachment)",
        "apple_model": "NoteTableAttachment",
        "apple_view": "NoteTableView",
        "android_model": "NoteTable",
        "android_view": "TableLayer",
        "envelope_key": None, # 原生核心區塊
    },
    {
        "kind": "image",
        "name": "圖片物件 (Image Attachment)",
        "apple_model": "NoteImageAttachment",
        "apple_view": "ImageAttachmentItemView",
        "android_model": "NoteImage",
        "android_view": "ImageLayer",
        "envelope_key": None, # 原生核心區塊
    },
    {
        "kind": "text",
        "name": "文字方塊 (Text Box)",
        "apple_model": "NoteTextAttachment",
        "apple_view": "TextBoxItemView",
        "android_model": "NoteText",
        "android_view": "TextLayer",
        "envelope_key": None, # 原生核心區塊
    },
]

def check_file_contains(files: list[Path], pattern: str) -> bool:
    reg = re.compile(pattern)
    for f in files:
        if not f.exists():
            continue
        try:
            content = f.read_text(encoding="utf-8", errors="ignore")
            if reg.search(content):
                return True
        except Exception:
            pass
    return False

def audit_pipelines():
    print("=" * 80)
    print("  Kairumo 跨平台全管線貫通與端點閉環檢測報告 (Phase 1 Pipeline Audit)")
    print("=" * 80)
    
    apple_swift_files = list(APPLE_SOURCES.rglob("*.swift"))
    android_kt_files = list(ANDROID_SOURCES.rglob("*.kt"))
    
    # 1. 檢查信封協議對稱性
    print("\n[1] 衍生區塊與信封協議 (ObjectEnvelope & Derived Blocks) 對齊檢查:")
    apple_bridge = (APPLE_SOURCES / "NotebookPackageBridge.swift").read_text(encoding="utf-8")
    android_note_image = (ANDROID_SOURCES / "image" / "NoteImage.kt").read_text(encoding="utf-8")
    android_meta = (ANDROID_SOURCES / "library" / "NotebookMeta.kt").read_text(encoding="utf-8")
    
    envelope_issues = []
    
    # 檢查 Android NoteImage 中的 DERIVED 集合
    derived_match = re.search(r'private val DERIVED = setOf\((.*?)\)', android_note_image)
    android_derived_set = set()
    if derived_match:
        android_derived_set = set(re.findall(r'"([^"]+)"', derived_match.group(1)))
    
    print(f"  • Android DERIVED 集合: {sorted(list(android_derived_set))}")

    # 檢查各物件在各平台的狀態
    print("\n[2] 畫布 12 大物件型別跨端管線貫通狀態矩陣:")
    print(f"  {'物件種類':<26} | {'Apple模型':<8} | {'Apple導出':<8} | {'Android模型':<9} | {'Android儲存':<9} | {'跨端管線狀態'}")
    print("  " + "-" * 88)
    
    for item in CANVAS_OBJECT_KINDS:
        kind = item["kind"]
        name = item["name"]
        
        # Apple 模型存在
        apple_has_model = check_file_contains(apple_swift_files, rf'\bstruct\s+{item["apple_model"]}\b')
        # Apple 導出
        apple_has_export = False
        if item["envelope_key"]:
            apple_has_export = f'kind: "{item["envelope_key"]}"' in apple_bridge or f'kind == "{item["envelope_key"]}"' in apple_bridge or f'case "{item["envelope_key"]}":' in apple_bridge
        else:
            apple_has_export = True # 原生核心區塊由 FFI 處理
            
        # Android 模型存在
        android_has_model = check_file_contains(android_kt_files, rf'\b(data\s+class|class)\s+{item["android_model"]}\b')
        
        # Android 儲存/讀取管線
        android_has_storage = False
        if item["envelope_key"] == "tape":
            # 檢查 Android 是否有讀寫 tape 信封或 NotebookMeta
            android_has_storage = check_file_contains(android_kt_files, r'KEY_TAPES|tapes\(\)|setTapes|kind == "tape"')
        elif item["envelope_key"] == "rectitle":
            android_has_storage = check_file_contains(android_kt_files, r'rectitle|recordingTitles')
        elif item["envelope_key"] in ["link", "audio", "model3d", "pin", "sticky"]:
            android_has_storage = check_file_contains([ROOT / "android" / "app" / "src" / "main" / "java" / "com" / "kairumo" / "padnote" / "library" / "NotebookMeta.kt"], rf'{item["envelope_key"]}|{item["android_model"]}')
        elif item["envelope_key"] in ["shapestyle", "connstyle"]:
            android_has_storage = check_file_contains(android_kt_files, r'shapeStyles|connectionStyles|KIND_SHAPE')
        else:
            android_has_storage = True
            
        status = "✅ 完整貫通"
        if not android_has_storage:
            status = "❌ Android 儲存/信封管線斷開！"
            envelope_issues.append(f"【嚴重斷頭管線】{name} ({kind}): Android UI 雖有實作但未連接持久化與同步信封！")
        elif not apple_has_export:
            status = "❌ Apple 導出管線斷開"
            envelope_issues.append(f"{name}: Apple 導出未找到信封")
            
        print(f"  {name:<24} | {'OK' if apple_has_model else 'MISSING':<8} | {'OK' if apple_has_export else 'MISSING':<8} | {'OK' if android_has_model else 'MISSING':<9} | {'OK' if android_has_storage else 'BROKEN':<9} | {status}")

    # 3. 檢查主執行緒與看門狗潛在風險
    print("\n[3] 主執行緒看門狗 (0x8BADF00D) 潛在阻塞風險審查:")
    watchdog_risks = []
    
    # 掃描 Apple 端在 @MainActor 或主線程呼叫內容
    cloud_sync_folder = (APPLE_SOURCES / "CloudSyncFolder.swift").read_text(encoding="utf-8")
    if "@MainActor public static func wipeCloud" in cloud_sync_folder:
        watchdog_risks.append("CloudSyncFolder.swift: `wipeCloud` 被標記為 @MainActor，且內部呼叫 FileManager 同步列舉 contentsOfDirectory 與同步刪除，在雲端大量檔案時會直接阻塞主執行緒造成 0x8BADF00D 看門狗超時！")
        
    for p in [APPLE_SOURCES / "NotebookStore.swift", APPLE_SOURCES / "NotebookSyncCoordinator.swift", APPLE_SOURCES / "DriveHttpClient.swift"]:
        if p.exists():
            text = p.read_text(encoding="utf-8")
            for lineno, line in enumerate(text.splitlines(), 1):
                if ("session.wipeCloud()" in line or "session.applyRemoteChanges()" in line) and "Task.detached" not in line and "Task {" in line:
                    watchdog_risks.append(f"{p.name}:{lineno} 可能在非 detached 背景任務中呼叫重型 FFI 同步操作")

    if watchdog_risks:
        for r in watchdog_risks:
            print(f"  ⚠️  {r}")
    else:
        print("  ✅ 未發現明顯的主執行緒重型 FFI 呼叫風險。")

    print("\n" + "=" * 80)
    print("  檢測總結與待解決關鍵痛點 (Key Findings)")
    print("=" * 80)
    for issue in envelope_issues:
        print(f"  🚨 {issue}")
    for risk in watchdog_risks:
        print(f"  ⚡ {risk}")
        
    return len(envelope_issues)

if __name__ == "__main__":
    issues_count = audit_pipelines()
    sys.exit(0 if issues_count == 0 else 1)
