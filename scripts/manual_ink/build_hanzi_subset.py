"""從 makemeahanzi 的 graphics.txt 取出手冊用到的字，輸出精簡的筆順中線檔。

用法：python3 scripts/manual_ink/build_hanzi_subset.py <graphics.txt 的路徑>

輸出 `third_party/makemeahanzi/strokes-subset.json`：只保留 `medians`（每一筆的中線座標），
丟掉輪廓路徑（strokes）—— 手寫只需要中線。這是對原資料的修改，依 Arphic Public License
第 2 條 (a) 在 README 與檔頭註明。
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from manual_text import cjk_chars_all  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "third_party/makemeahanzi/strokes-subset.json"


def main(src: str):
    need = cjk_chars_all()
    found = {}
    for line in Path(src).read_text(encoding="utf-8").splitlines():
        rec = json.loads(line)
        if rec["character"] in need:
            found[rec["character"]] = rec["medians"]
    missing = [c for c in need if c not in found]
    if missing:
        raise SystemExit(f"graphics.txt 沒有這些字：{''.join(missing)}")
    data = {
        "_notice": (
            "Derived from makemeahanzi graphics.txt (https://github.com/skishore/makemeahanzi), "
            "itself derived from Arphic PL KaitiM GB / Arphic PL UKai. Licensed under the Arphic "
            "Public License (see ARPHICPL.TXT). Modified 2026-10-06 by the Kairumo project: only the "
            "'medians' (stroke centre lines) of the characters used in the preloaded manual (Traditional and Simplified Chinese editions) were "
            "kept; glyph outlines were dropped. Coordinates are unchanged (1024 grid, y up, "
            "baseline at y=-124 ... top at y=900)."
        ),
        "chars": {c: found[c] for c in need},
    }
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(data, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    print(f"{OUT.relative_to(ROOT)}  {len(found)} 字 / {OUT.stat().st_size // 1024} KB")


if __name__ == "__main__":
    main(sys.argv[1])
