import json
with open("i18n/ui-strings.json", "r") as f:
    data = json.load(f)

data["tool_masking_tape"] = {
    "en": "Masking Tape",
    "ja": "マスキングテープ",
    "ko": "마스킹 테이프",
    "th": "กระดาษกาว",
    "zhHans": "胶带",
    "zhHant": "膠帶"
}
with open("i18n/ui-strings.json", "w") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
