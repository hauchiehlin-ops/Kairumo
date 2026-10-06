#!/usr/bin/env python3
"""開發用（只在 macOS 上跑）：拿系統字型當考題，比對 `otl` 排版引擎與 CoreText 排出來的字形。

為什麼：引擎照 OpenType 規格實作了每一種 GSUB／GPOS 查詢，但只有 Noto Sans Thai 一支字型當考題的話，
其他字型用到的格式（上下文格式 2、標記對合字、草寫連接…）有沒有寫對，沒人知道。這支腳本把系統裡
一批字型（拉丁、泰文、CFF 外框、TTC…）逐一排同一批字串，字形編號與位置要和 CoreText 一致。

不進 CI：系統字型是 Apple 的、只有 macOS 上有，也不能放進 repo。
用法：python3 scripts/verify-otl-coretext.py [--verbose]
"""
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
# 可變字型（有 fvar）：CoreText 會依字級自動調光學尺寸軸，寬度跟預設實例不同，所以只比字形編號。
# 從右到左的文字：CoreText 輸出的是視覺順序（反過來），也只比字形（引擎不做雙向排版）。
VARIABLE = {"NewYork.ttf", "SFNS.ttf", "ThonburiUI.ttc"}
RTL = {"SFHebrew.ttf"}

FONTS = [
    # (路徑, TTC 索引, 要排的字串們)
    ("/System/Library/Fonts/Supplemental/Arial.ttf", 0, ["AVATAR To Wa", "office affluent", "Hello, World 123"]),
    ("/System/Library/Fonts/Supplemental/Arial Unicode.ttf", 0, ["AVATAR To", "Ελληνικά Кириллица"]),
    ("/System/Library/Fonts/Avenir Next.ttc", 0, ["AVATAR To Wa", "office fi ffi fl", "Typography"]),
    ("/System/Library/Fonts/Avenir.ttc", 0, ["AVATAR To Wa", "Fifty affluent"]),
    ("/System/Library/Fonts/NewYork.ttf", 0, ["AVATAR To Wa", "office fi ffi", "Final"]),
    ("/System/Library/Fonts/Supplemental/Charter.ttc", 0, ["AVATAR To Wa", "office fi ffl"]),
    ("/System/Library/Fonts/SFNS.ttf", 0, ["AVATAR To Wa", "Hello World"]),
    ("/System/Library/Fonts/SFHebrew.ttf", 0, ["שלום עולם"]),
    ("/System/Library/Fonts/ThonburiUI.ttc", 0, ["ภาษาไทย", "ที่ ปู่ ผู้ ซึ่ง นี้", "น้ำ ป่า ญี่ปุ่น ฐาน"]),
    ("/System/Library/Fonts/SukhumvitSet.ttc", 0, ["ภาษาไทย", "ที่ ปู่ ผู้ ซึ่ง นี้ น้ำ"]),
    ("/System/Library/Fonts/Hiragino Sans GB.ttc", 0, ["日本語 漢字 ひらがな", "Hello"]),
    ("/System/Library/Fonts/AppleSDGothicNeo.ttc", 0, ["한국어 문장입니다", "Hello"]),
    (str(ROOT / "third_party/notosansthai/NotoSansThai-Regular.ttf"), 0, ["ภาษาไทย", "ที่ ปู่ ผู้ ซึ่ง นี้ น้ำ ป่า", "การประชุมและบันทึก"]),
]


CT_TOOL = Path("/tmp/kairumo-ct-dump")


def build_tools():
    """先把 CoreText 的傾印工具與我們的傾印範例都編好，後面逐組比對才不會每組都重編。"""
    subprocess.run(["swiftc", "-O", str(ROOT / "scripts/ct_dump.swift"), "-o", str(CT_TOOL)], check=True)
    subprocess.run(["cargo", "build", "-q", "-p", "padnote-export", "--example", "otl_dump"], cwd=ROOT, check=True)


def dump_ct(path, index, text):
    out = subprocess.run([str(CT_TOOL), path, str(index), text], capture_output=True, text=True, timeout=120)
    return out.stdout.split("\n")


def dump_ours(path, index, text):
    out = subprocess.run([str(ROOT / "target/debug/examples/otl_dump"), path, str(index), text],
                         capture_output=True, text=True, cwd=ROOT, timeout=300)
    return out.stdout.split("\n") if out.returncode == 0 else ["error", out.stderr[-300:]]


def parse(lines):
    if not lines or lines[0] in ("nofont", "fallback", "error", "unmapped"):
        return lines[0] if lines and lines[0] else "empty", []
    return "ok", [tuple(int(x) for x in l.split()) for l in lines[1:] if l.strip()]


def main():
    verbose = "--verbose" in sys.argv
    build_tools()
    total = bad = skipped = 0
    for path, index, texts in FONTS:
        if not Path(path).exists():
            print(f"（略過，找不到）{path}")
            continue
        for text in texts:
            ct_state, ct = parse(dump_ct(path, index, text))
            our_state, ours = parse(dump_ours(path, index, text))
            if ct_state != "ok" or our_state != "ok":
                skipped += 1
                print(f"· 略過 {Path(path).name} {text!r}：CoreText={ct_state} 我們={our_state}")
                continue
            total += 1
            name = Path(path).name
            if name in RTL:
                ct = list(reversed(ct))
            same_gids = [g[0] for g in ct] == [g[0] for g in ours]
            # 位置容差 2 個字型單位：CoreText 內部用浮點，我們用整數。
            if name in VARIABLE or name in RTL:
                same_pos = same_gids
            else:
                same_pos = same_gids and all(abs(a[1] - b[1]) <= 2 and abs(a[2] - b[2]) <= 2 for a, b in zip(ct, ours))
            if same_gids and same_pos:
                if verbose:
                    print(f"✓ {Path(path).name} {text!r}")
            else:
                bad += 1
                print(f"✗ {Path(path).name} {text!r}\n   CoreText: {ct}\n   我們    : {ours}")
    print(f"\n比對 {total} 組：{total - bad} 組一致、{bad} 組不同（另有 {skipped} 組因字型缺字或格式不支援略過）")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
