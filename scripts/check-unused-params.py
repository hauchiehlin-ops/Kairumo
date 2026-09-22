#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""擋掉「宣告了但主體從沒讀過」的參數。

# 為什麼需要這道閘門

一個被默默忽略的參數**看起來像是有作用的**。呼叫端照著傳，以為設定生效了，
而它從頭到尾沒被讀過 —— 編譯器不會警告，測試也測不出來（因為那個功能
本來就沒接上，沒有人會為它寫測試）。

實際踩到的：
  * `height(forPage:defaultHeight:)` 的 `defaultHeight`，編輯器一直傳
    1800 進來，函式主體從來沒讀過它。
  * `downloadWhisperModel(useMirror:)` 的 `useMirror`，主體裡沒有任何
    鏡像邏輯。
  * `generate(prompt:maxTokens:)` 的 `maxTokens`，生成完全不受限。

這三個都是「介面上看得到、實際上沒接線」的同一類問題。

# 兩種合法的例外

1. **框架協定**：`makeUIView(context:)`、`urlSession(_:task:...)` 這些
   簽章由 Apple 定死，用不到也必須留著。列在 `FRAMEWORK_CALLBACKS`。
2. **刻意保留**：在函式上方三行內寫
   `// unused-param-ok: <理由>` 放行。理由要寫，不然下一個人不知道
   這是刻意的還是漏掉的。

Swift 可以用 `_` 當內部名明講「不用」，那種本來就不會被抓。

# 為什麼有 baseline（棘輪）

現況本來就有一批（第一次跑是 11 處我們自己的 API）。閘門一開始就全紅
會被關掉，然後一切照舊。所以已知的寫進 baseline，CI 只擋**新增**的。
`--update-baseline` 只縮不長；要變長必須 `--accept-new` 明講。

用法：
    python3 scripts/check-unused-params.py
    python3 scripts/check-unused-params.py --update-baseline
    python3 scripts/check-unused-params.py --update-baseline --accept-new
"""

from __future__ import annotations

import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
BASELINE = ROOT / "docs" / "gates" / "unused-params-baseline.json"

# 簽章由框架定死的回呼。用不到也必須照著寫。
FRAMEWORK_CALLBACKS = {
    # UIApplicationDelegate
    "application",
    # AVAudioPlayerDelegate
    "audioPlayerDidFinishPlaying", "audioPlayerDecodeErrorDidOccur",
    # URLSessionDelegate 家族
    "urlSession",
    # UIViewRepresentable / UIViewControllerRepresentable
    "makeUIView", "updateUIView", "makeUIViewController", "updateUIViewController",
    "makeCoordinator", "dismantleUIView", "dismantleUIViewController",
    # ASWebAuthenticationPresentationContextProviding
    "presentationAnchor",
    # UIPointerInteractionDelegate
    "pointerInteraction",
    # UIPencilInteractionDelegate
    "pencilInteraction", "pencilInteractionDidTap",
    # SwiftUI Layout（cache 依設計可不使用）
    "sizeThatFits", "placeSubviews",
    # UIDocumentPickerDelegate / UIScrollViewDelegate 等常見回呼
    "documentPicker", "scrollViewDidScroll", "scrollViewDidZoom",
    "viewForZooming", "gestureRecognizer", "connection",
}

WAIVER = re.compile(r"//\s*unused-param-ok:")


def blank_strings_and_comments(src: str) -> str:
    """把字串字面值與註解塗白 —— 但保留 Swift `\\(…)` 插值裡的程式碼。

    很多參數只在插值裡被讀到（`"\\(notebookId)_p\\(pageIndex).drawing"`）。
    整串塗白會把它們全部誤判成沒用過 —— 第一版就是這樣，抓出 14 個假陽性。
    """
    out = list(src)
    i, n = 0, len(src)
    while i < n:
        if src[i] == '"':
            out[i] = " "
            j = i + 1
            while j < n and src[j] != "\n":
                # Swift：\(…)
                if src[j] == "\\" and j + 1 < n and src[j + 1] == "(":
                    out[j] = out[j + 1] = " "
                    depth, k = 1, j + 2
                    while k < n and depth:
                        if src[k] == "(":
                            depth += 1
                        elif src[k] == ")":
                            depth -= 1
                            if depth == 0:
                                out[k] = " "
                                break
                        k += 1
                    j = k + 1
                    continue
                # Kotlin：${…}
                if src[j] == "$" and j + 1 < n and src[j + 1] == "{":
                    out[j] = out[j + 1] = " "
                    depth, k = 1, j + 2
                    while k < n and depth:
                        if src[k] == "{":
                            depth += 1
                        elif src[k] == "}":
                            depth -= 1
                            if depth == 0:
                                out[k] = " "
                                break
                        k += 1
                    j = k + 1
                    continue
                # Kotlin：$name（含 $a.b 這種鏈）
                if src[j] == "$" and j + 1 < n and (src[j + 1].isalpha() or src[j + 1] == "_"):
                    out[j] = " "
                    k = j + 1
                    while k < n and (src[k].isalnum() or src[k] in "_."):
                        k += 1
                    j = k
                    continue
                if src[j] == '"' and src[j - 1] != "\\":
                    out[j] = " "
                    j += 1
                    break
                out[j] = " "
                j += 1
            i = j
            continue
        if src.startswith("//", i):
            j = src.find("\n", i)
            j = n if j < 0 else j
            for k in range(i, j):
                out[k] = " "
            i = j
            continue
        if src.startswith("/*", i):
            j = src.find("*/", i)
            j = n if j < 0 else j + 2
            for k in range(i, j):
                if src[k] != "\n":
                    out[k] = " "
            i = j
            continue
        i += 1
    return "".join(out)


def split_params(sig: str) -> list[str]:
    """切出參數的**內部名**（`label name:` → name，`_ name:` → name）。"""
    parts, depth, cur = [], 0, ""
    for ch in sig:
        if ch in "([<":
            depth += 1
        elif ch in ")]>":
            depth -= 1
        if ch == "," and depth == 0:
            parts.append(cur)
            cur = ""
        else:
            cur += ch
    parts.append(cur)

    names = []
    for part in parts:
        part = part.strip()
        if not part or ":" not in part:
            continue
        head = part.split(":", 1)[0].strip()
        words = head.split()
        if not words:
            continue
        internal = words[-1]
        if internal == "_":          # 明講不用
            continue
        if not re.fullmatch(r"[A-Za-z_]\w*", internal):
            continue
        names.append(internal)
    return names


def _expression_body_start(src: str, close_paren: int) -> int | None:
    """參數列之後、主體之前若出現 `=`，回傳它的位置（Kotlin 表達式主體）。

    要跳過回傳型別（`: List<NoteShape>`）與泛型裡的 `=`，所以只看
    括號／角括號深度為 0 的那個 `=`，而且遇到 `{` 就放棄。
    """
    depth = 0
    i = close_paren + 1
    while i < len(src):
        c = src[i]
        if c in "(<[":
            depth += 1
        elif c in ")>]":
            depth -= 1
        elif depth <= 0:
            if c == "{":
                return None
            if c == "=" and src[i + 1 : i + 2] != "=" and src[i - 1] not in "=!<>":
                return i
            if c == "\n" and src[i + 1 : i + 2] not in (" ", "\t", "=", ":", ""):
                return None
        i += 1
    return None


def _expression_body(src: str, eq: int, decl: str) -> str:
    """從 `=` 讀到這個宣告結束：深度歸零、且下一行縮排不比宣告本身深。"""
    indent = len(decl) - len(decl.lstrip())
    depth = 0
    i = eq + 1
    while i < len(src):
        c = src[i]
        if c in "({[":
            depth += 1
        elif c in ")}]":
            depth -= 1
        elif c == "\n" and depth <= 0:
            j = i + 1
            while j < len(src) and src[j] in " \t":
                j += 1
            if j < len(src) and src[j] != "\n" and (j - i - 1) <= indent:
                break
        i += 1
    return src[eq + 1 : i]


def scan(path: pathlib.Path, keyword: str) -> list[tuple[str, int, str, str]]:
    raw = path.read_text(encoding="utf-8")
    src = blank_strings_and_comments(raw)
    raw_lines = raw.split("\n")
    pattern = re.compile(r"\b" + keyword + r"\s+([A-Za-z_]\w*)\s*(?:<[^>]*>)?\s*\(")
    hits = []
    for m in pattern.finditer(src):
        name = m.group(1)
        if name in FRAMEWORK_CALLBACKS:
            continue
        line_no = raw[: m.start()].count("\n") + 1
        decl = raw_lines[line_no - 1]
        if "override" in decl:
            continue
        # 上方三行內的放行註解
        window = "\n".join(raw_lines[max(0, line_no - 4) : line_no])
        if WAIVER.search(window):
            continue

        # 參數列
        open_paren = m.end() - 1
        depth, i = 0, open_paren
        while i < len(src):
            if src[i] == "(":
                depth += 1
            elif src[i] == ")":
                depth -= 1
                if depth == 0:
                    break
            i += 1
        close_paren = i
        brace = src.find("{", close_paren)
        eq = _expression_body_start(src, close_paren)

        if eq is not None and (brace < 0 or eq < brace):
            # Kotlin 的單一表達式主體：`fun f(x: Int) = x * 2`，沒有大括號。
            #
            # 漏掉這個的代價是 79 個假陽性 —— 找不到自己的 `{`，就抓到了
            # 下一個宣告的大括號，於是整個 Kotlin 端幾乎全被誤判。
            body = _expression_body(src, eq, decl)
        else:
            if brace < 0:
                continue
            # 中間隔著空行代表這是沒有主體的宣告（協定／抽象），下一個 { 是別人的
            if "\n\n" in src[close_paren:brace]:
                continue
            depth, j = 0, brace
            while j < len(src):
                if src[j] == "{":
                    depth += 1
                elif src[j] == "}":
                    depth -= 1
                    if depth == 0:
                        break
                j += 1
            body = src[brace + 1 : j]
        if not body.strip():
            continue

        for param in split_params(src[open_paren + 1 : close_paren]):
            if not re.search(r"\b" + re.escape(param) + r"\b", body):
                rel = str(path.relative_to(ROOT))
                hits.append((rel, line_no, name, param))
    return hits


# 產生的程式碼不是人寫的，改不了也不該擋。
GENERATED = ("/Generated/", "/uniffi/", ".generated.")


def _is_generated(path: pathlib.Path) -> bool:
    p = "/" + str(path).replace("\\", "/")
    return any(marker in p for marker in GENERATED)


def collect() -> list[str]:
    found = []
    for path in sorted((ROOT / "apple" / "Sources").rglob("*.swift")):
        if _is_generated(path):
            continue
        found += [f"{f}::{fn}::{p}" for f, _, fn, p in scan(path, "func")]
    kotlin_root = ROOT / "android" / "app" / "src" / "main"
    if kotlin_root.exists():
        for path in sorted(kotlin_root.rglob("*.kt")):
            if _is_generated(path):
                continue
            found += [f"{f}::{fn}::{p}" for f, _, fn, p in scan(path, "fun")]
    return sorted(set(found))


def locations() -> dict[str, str]:
    """key -> 檔案:行，只給人看，不進 baseline（行號會漂）。"""
    out = {}
    for path in sorted((ROOT / "apple" / "Sources").rglob("*.swift")):
        if _is_generated(path):
            continue
        for f, ln, fn, p in scan(path, "func"):
            out[f"{f}::{fn}::{p}"] = f"{f}:{ln}"
    kotlin_root = ROOT / "android" / "app" / "src" / "main"
    if kotlin_root.exists():
        for path in sorted(kotlin_root.rglob("*.kt")):
            if _is_generated(path):
                continue
            for f, ln, fn, p in scan(path, "fun"):
                out[f"{f}::{fn}::{p}"] = f"{f}:{ln}"
    return out


def main() -> int:
    update = "--update-baseline" in sys.argv
    accept_new = "--accept-new" in sys.argv

    found = collect()
    known = json.loads(BASELINE.read_text(encoding="utf-8")) if BASELINE.exists() else []

    if update:
        merged = sorted(set(found) & set(known)) if not accept_new else found
        if not accept_new and set(found) - set(known):
            print("⚠️  有 baseline 之外的新項目，沒有 --accept-new 不會寫進去：")
            for k in sorted(set(found) - set(known)):
                print(f"   {k}")
        BASELINE.parent.mkdir(parents=True, exist_ok=True)
        BASELINE.write_text(
            json.dumps(merged, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
        )
        print(f"✅ baseline 已更新：{len(known)} → {len(merged)} 項")
        return 0

    where = locations()
    new = sorted(set(found) - set(known))
    if new:
        print("❌ 這些參數宣告了但函式主體從來沒讀過 —— 呼叫端會以為設定生效了：")
        for key in new:
            f, fn, p = key.split("::")
            print(f"   {where.get(key, f)}  {fn}(…{p}…)")
        print()
        print("   修法三選一：真的要用它／拿掉它／在上方寫")
        print("   // unused-param-ok: <理由>")
        return 1

    stale = sorted(set(known) - set(found))
    print(f"✅ 沒有新的空參數（baseline 尚欠 {len(found)} 項，逐步清空）")
    if stale:
        print(f"   （baseline 有 {len(stale)} 項已經修好了，可以跑 --update-baseline 縮小）")
    return 0


if __name__ == "__main__":
    sys.exit(main())
