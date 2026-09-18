import json

with open("i18n/ui-strings.json", "r") as f:
    data = json.load(f)

data["sticker_library"] = {
    "en": "Sticker Library",
    "ja": "ステッカーライブラリ",
    "ko": "스티커 라이브러리",
    "th": "คลังสติกเกอร์",
    "zhHans": "贴纸库",
    "zhHant": "貼紙庫"
}

data["save_as_sticker"] = {
    "en": "Save as Sticker",
    "ja": "ステッカーとして保存",
    "ko": "스티커로 저장",
    "th": "บันทึกเป็นสติกเกอร์",
    "zhHans": "保存为贴纸",
    "zhHant": "儲存為貼紙"
}

data["no_stickers"] = {
    "en": "No Stickers Yet",
    "ja": "ステッカーがありません",
    "ko": "아직 스티커가 없습니다",
    "th": "ยังไม่มีสติกเกอร์",
    "zhHans": "还没有贴纸",
    "zhHant": "還沒有貼紙"
}

data["no_stickers_hint"] = {
    "en": "Select strokes with lasso tool to save custom stickers.",
    "ja": "なげなわツールでストロークを選択し、カスタムステッカーを保存します。",
    "ko": "올가미 도구로 스트로크를 선택하여 사용자 정의 스티커를 저장합니다.",
    "th": "เลือกจังหวะด้วยเครื่องมือบ่วงบาศเพื่อบันทึกสติกเกอร์แบบกำหนดเอง",
    "zhHans": "用套索圈选笔画，即可保存为自定义贴纸。",
    "zhHant": "用套索圈選筆劃，即可儲存為自訂貼紙。"
}

with open("i18n/ui-strings.json", "w") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
