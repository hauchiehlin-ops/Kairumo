#!/usr/bin/env python3
"""從 HuggingFace 官方 funasr/* 權重匯出 ONNX（ADR-0006 / 決策 D-07）。

**為什麼要自己匯出**：官方 repo 內含完整的 Apache-2.0 LICENSE 檔，那是最強的
授權依據。第三方轉換版雖然也標 Apache-2.0，但轉換者的宣告不能高於上游授予的
權利。自行匯出讓整條鏈都落在官方那份授權底下。

用法：
    python3 -m venv .venv && .venv/bin/pip install torch funasr onnx
    .venv/bin/python scripts/export-funasr-onnx.py --out models/exported

產出：
    models/exported/<model-id>/*.onnx
    models/exported/<model-id>/PROVENANCE.json   ← 授權稽核的證據
    models/exported/<model-id>/LICENSE           ← 取得當下的授權原文
"""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

# 要匯出的模型。**釘住 revision** —— 用 "main" 的話，來源會浮動，
# provenance 紀錄就失去意義。
MODELS = [
    {
        # 刻意選 streaming 版：它是三個 funasr repo 中**唯一內含完整 LICENSE 檔**的，
        # 而且串流正是 C2「邊錄邊出字」需要的形態。授權證據與功能需求剛好一致。
        "id": "paraformer-zh-streaming",
        "repo": "funasr/paraformer-zh-streaming",
        "revision": "main",
        "purpose": "中文 ASR 主力引擎（串流，功能 C2）",
        "capabilities": ["asr.zh"],
    },
    {
        "id": "ct-punc",
        "repo": "funasr/ct-punc",
        "revision": "main",
        "purpose": "中文標點還原（功能 C5，P0）",
        "capabilities": ["punctuation.zh"],
    },
]


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def tool_versions() -> dict[str, str]:
    out = {"python": sys.version.split()[0]}
    for mod in ("torch", "funasr", "onnx"):
        try:
            out[mod] = __import__(mod).__version__
        except Exception as e:  # noqa: BLE001
            out[mod] = f"<unavailable: {e}>"
    return out


def fetch_license(repo: str, revision: str, dest: Path) -> dict | None:
    """取得授權證據，並**標明證據強度**。

    這是本腳本最重要的一步：把「我們取得權重時，著作權人宣告的授權是什麼」
    固定下來。日後對方改授權，已匯出的版本仍受當時的條款涵蓋。

    兩種證據，強度不同：

    - ``license_file``：repo 內有完整的授權文本。**最強** ——
      著作權人在自己的散布通路放上完整授權原文。
    - ``model_card_metadata``：只有 model card 的 ``license:`` 標籤。
      仍是著作權人的正式宣告（HF 會把它顯示在頁面上），但沒有條款原文，
      **證據較弱**，需在稽核文件中標明。
    """
    import urllib.error
    import urllib.request

    for name in ("LICENSE", "LICENSE.txt", "LICENSE.md"):
        url = f"https://huggingface.co/{repo}/raw/{revision}/{name}"
        try:
            with urllib.request.urlopen(url, timeout=60) as r:  # noqa: S310
                if r.status != 200:
                    continue
                body = r.read()
        except urllib.error.HTTPError:
            continue
        except Exception as e:  # noqa: BLE001
            print(f"  ! 取得 {name} 失敗：{e}")
            continue

        # 29 bytes 的 "Invalid username or password" 也是 200 —— 必須檢查內容。
        if len(body) < 200:
            print(f"  ! {name} 只有 {len(body)} bytes，看起來不是授權文本，忽略")
            continue

        dest.write_bytes(body)
        return {
            "evidence": "license_file",
            "file": name,
            "url": url,
            "sha256": hashlib.sha256(body).hexdigest(),
            "bytes": len(body),
        }

    # 沒有授權檔 → 退而求其次，記錄 model card 的宣告。
    return fetch_card_license(repo, revision, dest)


def fetch_card_license(repo: str, revision: str, dest: Path) -> dict | None:
    """記錄 model card 的 ``license:`` 宣告與 README 原文。

    證據較弱，但仍是著作權人在自己通路上的正式宣告。README 一併留存，
    因為額外的授權說明通常寫在那裡。
    """
    import urllib.request

    try:
        api = f"https://huggingface.co/api/models/{repo}"
        with urllib.request.urlopen(api, timeout=60) as r:  # noqa: S310
            card = json.load(r)
    except Exception as e:  # noqa: BLE001
        print(f"  ! 無法取得 model card：{e}")
        return None

    declared = (card.get("cardData") or {}).get("license")
    if not declared:
        return None

    readme_url = f"https://huggingface.co/{repo}/raw/{revision}/README.md"
    readme = b""
    try:
        with urllib.request.urlopen(readme_url, timeout=60) as r:  # noqa: S310
            readme = r.read()
    except Exception:  # noqa: BLE001
        pass

    # 留存 README 原文，額外的授權說明通常在裡面。
    dest.with_name("README.snapshot.md").write_bytes(readme)

    print(f"  ⚠ repo 內無 LICENSE 檔，退回 model card 宣告：{declared}（證據較弱）")
    return {
        "evidence": "model_card_metadata",
        "declared_license": declared,
        "url": api,
        "readme_url": readme_url,
        "readme_sha256": hashlib.sha256(readme).hexdigest(),
        "sha256": hashlib.sha256(json.dumps(card.get("cardData") or {}, sort_keys=True).encode()).hexdigest(),
        "bytes": len(readme),
    }


def resolve_revision(repo: str, revision: str) -> str:
    """把 'main' 解析成實際的 commit sha，讓 provenance 可驗證。"""
    import urllib.request

    url = f"https://huggingface.co/api/models/{repo}/revision/{revision}"
    try:
        with urllib.request.urlopen(url, timeout=60) as r:  # noqa: S310
            return json.load(r).get("sha", revision)
    except Exception:  # noqa: BLE001
        return revision


def force_legacy_onnx_exporter() -> None:
    """強制使用舊版 torch.onnx 匯出器。

    torch 2.9+ 把 ``dynamo=True`` 設為預設，而新匯出器不接受 FunASR 傳入的
    ``dynamic_axes``（會報 "Failed to convert 'dynamic_axes' to 'dynamic_shapes'"）。
    在 FunASR 更新之前，這裡把預設改回舊版路徑。
    """
    import torch

    original = torch.onnx.export
    if getattr(original, "_padnote_patched", False):
        return

    def patched(*args, **kwargs):
        kwargs.setdefault("dynamo", False)
        return original(*args, **kwargs)

    patched._padnote_patched = True  # noqa: SLF001
    torch.onnx.export = patched
    print("  (已強制使用舊版 ONNX 匯出器：torch 2.9+ 的 dynamo 匯出器不相容 FunASR)")


def export_one(spec: dict, out_root: Path, *, quantize: bool = False) -> bool:
    from funasr import AutoModel

    force_legacy_onnx_exporter()

    model_dir = out_root / spec["id"]
    model_dir.mkdir(parents=True, exist_ok=True)
    print(f"\n=== {spec['id']} ({spec['repo']}) ===")

    resolved = resolve_revision(spec["repo"], spec["revision"])
    print(f"  revision: {resolved}")

    license_info = fetch_license(spec["repo"], resolved, model_dir / "LICENSE")
    if license_info is None:
        # 連宣告都找不到就不匯出 —— 這正是 D-07 選擇本方案的全部理由。
        print("  ✗ 找不到任何授權宣告，中止。無法證明授權即不得匯出。")
        return False
    if license_info["evidence"] == "license_file":
        print(f"  ✓ LICENSE 檔：{license_info['file']}（{license_info['bytes']} bytes）")

    print("  匯出 ONNX 中…")
    model = AutoModel(model=spec["repo"], hub="hf", disable_update=True)
    exported = model.export(type="onnx", quantize=quantize)
    print(f"  匯出完成：{exported}")

    # 把產出搬進我們的目錄並計算雜湊。
    # `export()` 回傳的可能是目錄本身，也可能是檔案路徑或其列表。
    artifacts = []
    first = Path(exported[0] if isinstance(exported, (list, tuple)) else exported)
    src_dir = first if first.is_dir() else first.parent
    for f in sorted(src_dir.glob("*")):
        if f.suffix in (".onnx", ".json", ".txt", ".yaml", ".mvn"):
            target = model_dir / f.name
            target.write_bytes(f.read_bytes())
            artifacts.append(
                {"file": f.name, "sha256": sha256_file(target), "bytes": target.stat().st_size}
            )

    provenance = {
        "model_id": spec["id"],
        "purpose": spec["purpose"],
        "capabilities": spec["capabilities"],
        "source": {
            "host": "huggingface.co",
            "repo": spec["repo"],
            "revision": resolved,
            "url": f"https://huggingface.co/{spec['repo']}/tree/{resolved}",
        },
        "license": license_info,
        "exported_at_utc": datetime.now(timezone.utc).isoformat(),
        "exported_by": "scripts/export-funasr-onnx.py",
        "tools": tool_versions(),
        "artifacts": artifacts,
        "quantized": quantize,
        "note": (
            "依 ADR-0006 / 決策 D-07 自行匯出。授權依據為上方 license 欄位所記錄的"
            "檔案內容（其雜湊已固定），而非任何第三方轉換者的宣告。"
        ),
    }
    (model_dir / "PROVENANCE.json").write_text(
        json.dumps(provenance, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    onnx_count = sum(1 for a in artifacts if a["file"].endswith(".onnx"))
    if onnx_count == 0:
        print(f"  ✗ 在 {src_dir} 找不到任何 .onnx 產出")
        return False

    print(f"  ✓ {onnx_count} 個 ONNX（共 {len(artifacts)} 個檔案）+ PROVENANCE.json")
    return True


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="models/exported", type=Path)
    ap.add_argument("--only", help="只匯出指定的 model id")
    ap.add_argument(
        "--quantize",
        action="store_true",
        help="同時產生 int8 量化版。FP32 的 ct-punc 有 1.1 GB，行動裝置帶不動；"
        "量化後約四分之一。品質影響需以 padnote-bench 實測（TODO H2）。",
    )
    args = ap.parse_args()

    specs = [m for m in MODELS if not args.only or m["id"] == args.only]
    if not specs:
        print(f"沒有符合的模型：{args.only}")
        return 2

    ok = True
    for spec in specs:
        try:
            ok &= export_one(spec, args.out, quantize=args.quantize)
        except Exception as e:  # noqa: BLE001
            print(f"  ✗ {spec['id']} 匯出失敗：{e}")
            ok = False

    print("\n完成。" if ok else "\n有項目失敗。")
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
