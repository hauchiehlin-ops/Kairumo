#!/usr/bin/env python3
"""譯文的母語者審閱流程。

介面字串與核心訊息的非繁中譯文是機器輔助、由開發者撰寫的，**沒有母語者審閱過**。這支工具讓審閱可以
真的發生、而且看得出誰審了什麼：

  python3 scripts/i18n_review.py export ja            # 產生 docs/i18n-review/ja.tsv 給審閱者
  python3 scripts/i18n_review.py apply ja ja-reviewed.tsv --reviewer "名字"
                                                       # 把審閱者改過的譯文寫回 ui-strings.json，並登記為已審
  python3 scripts/i18n_review.py status                # 各語言已審／未審的條數
  python3 scripts/i18n_review.py lint                  # 機器抓得到的問題（佔位符、漏翻、混入別種文字）

審閱紀錄在 `i18n/review-status.json`：{語言: {鍵: {"reviewer": …, "date": …, "source": 當時的繁中原文}}}。
繁中原文改了，舊的審閱就視為過期（status 會算進「待重審」）—— 原文都變了，譯文當然要再看一次。

TSV 欄位：key、繁體中文（原文）、英文（對照）、目前譯文、修改後譯文（審閱者填；留空表示沒問題）、備註。
"""
import csv
import datetime
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CATALOG = ROOT / "i18n/ui-strings.json"
STATUS = ROOT / "i18n/review-status.json"
OUT = ROOT / "docs/i18n-review"
LANGS = ["en", "zhHans", "ja", "ko", "th"]
SKIP_PREFIXES = ("NS",)   # 權限說明另有流程（InfoPlist.strings），但仍然列出
COLUMNS = ["key", "繁體中文（原文）", "English（對照）", "目前譯文", "修改後譯文（沒問題就留空）", "備註"]


def load():
    catalog = json.loads(CATALOG.read_text())
    status = json.loads(STATUS.read_text()) if STATUS.exists() else {}
    return catalog, status


def is_reviewed(status, lang, key, source):
    rec = status.get(lang, {}).get(key)
    return bool(rec) and rec.get("source") == source


def cmd_export(lang):
    if lang not in LANGS:
        raise SystemExit(f"語言要是 {LANGS} 之一")
    catalog, status = load()
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / f"{lang}.tsv"
    rows = 0
    with path.open("w", newline="") as fh:
        w = csv.writer(fh, delimiter="\t")
        w.writerow(COLUMNS)
        for key in sorted(catalog):
            row = catalog[key]
            if lang not in row or "zhHant" not in row:
                continue
            if is_reviewed(status, lang, key, row["zhHant"]):
                continue   # 已審過而且原文沒變：不用再看
            w.writerow([key, row["zhHant"], row.get("en", ""), row[lang], "", ""])
            rows += 1
    print(f"{path.relative_to(ROOT)}：{rows} 條待審")


def cmd_apply(lang, tsv, reviewer):
    catalog, status = load()
    today = datetime.date.today().isoformat()
    changed = confirmed = 0
    with open(tsv, newline="") as fh:
        for rec in csv.DictReader(fh, delimiter="\t"):
            key = rec["key"]
            if key not in catalog or lang not in catalog[key]:
                print(f"略過：{key}（目錄裡沒有）")
                continue
            fixed = (rec.get(COLUMNS[4]) or "").strip()
            if fixed and fixed != catalog[key][lang]:
                catalog[key][lang] = fixed
                changed += 1
            else:
                confirmed += 1
            status.setdefault(lang, {})[key] = {
                "reviewer": reviewer, "date": today, "source": catalog[key]["zhHant"]}
    CATALOG.write_text(json.dumps(catalog, ensure_ascii=False, indent=2, sort_keys=True) + "\n")
    STATUS.write_text(json.dumps(status, ensure_ascii=False, indent=2, sort_keys=True) + "\n")
    print(f"{lang}：改了 {changed} 條、確認 {confirmed} 條（審閱者：{reviewer}）。"
          "接著跑 python3 scripts/i18n_tool.py generate")


def cmd_status():
    catalog, status = load()
    total = len([k for k, r in catalog.items() if "zhHant" in r])
    print(f"譯文 {total} 條 / 語言 {len(LANGS)} 種")
    for lang in LANGS:
        ok = sum(1 for k, r in catalog.items()
                 if "zhHant" in r and is_reviewed(status, lang, k, r["zhHant"]))
        stale = sum(1 for k, rec in status.get(lang, {}).items()
                    if k in catalog and rec.get("source") != catalog[k].get("zhHant"))
        print(f"  {lang:7} 已由母語者審閱 {ok:5} / {total}（{100 * ok / total:.1f}%）"
              + (f"，另有 {stale} 條原文已改、待重審" if stale else ""))


def cmd_lint():
    """機器抓得到的問題：佔位符與原文不一致、漏翻、混入別種文字。審閱者仍然不可取代。"""
    import re
    catalog, _ = load()
    ph = re.compile(r"%\d*\$?[@dfs]|%\d+@|\{\w*\}")
    han = re.compile(r"[\u3400-\u9fff]")
    kana = re.compile(r"[\u3040-\u30ff]")
    hangul = re.compile(r"[\uac00-\ud7af\u1100-\u11ff]")
    thai = re.compile(r"[\u0e00-\u0e7f]")
    problems = []
    for key, row in sorted(catalog.items()):
        if "zhHant" not in row:
            continue
        want = sorted(ph.findall(row["zhHant"]))
        for lang in LANGS:
            t = row.get(lang)
            if t is None:
                problems.append(f"{key}（{lang}）：缺譯文")
                continue
            if sorted(ph.findall(t)) != want:
                problems.append(f"{key}（{lang}）：佔位符 {sorted(ph.findall(t))} ≠ 原文 {want}")
            if not t.strip():
                problems.append(f"{key}（{lang}）：空字串")
            if lang in ("en", "ko", "th") and han.search(t):
                problems.append(f"{key}（{lang}）：混入漢字：{t[:30]}")
            if lang == "ja" and (hangul.search(t) or thai.search(t)):
                problems.append(f"{key}（ja）：混入諺文或泰文：{t[:30]}")
            if lang == "ko" and (kana.search(t) or thai.search(t)):
                problems.append(f"{key}（ko）：混入假名或泰文：{t[:30]}")
            if lang == "th" and (kana.search(t) or hangul.search(t)):
                problems.append(f"{key}（th）：混入假名或諺文：{t[:30]}")
    for line in problems:
        print("❌", line)
    print(("❌ " if problems else "✅ ") + f"譯文檢查：{len(problems)} 個問題")
    return 1 if problems else 0


def main():
    a = sys.argv[1:]
    if a[:1] == ["export"] and len(a) == 2:
        cmd_export(a[1])
    elif a[:1] == ["apply"] and len(a) >= 3 and "--reviewer" in a:
        cmd_apply(a[1], a[2], a[a.index("--reviewer") + 1])
    elif a[:1] == ["status"]:
        cmd_status()
    elif a[:1] == ["lint"]:
        return cmd_lint()
    else:
        print(__doc__)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
