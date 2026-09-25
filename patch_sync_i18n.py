import json
with open("i18n/ui-strings.json", "r") as f:
    data = json.load(f)

data["folder_sync_not_set"] = {
    "en": "Sync folder not set",
    "zhHant": "未設定同步資料夾",
    "zhHans": "未设置同步文件夹",
    "ja": "同期フォルダが設定されていません",
    "ko": "동기화 폴더가 설정되지 않았습니다"
}

data["folder_sync_inaccessible"] = {
    "en": "Folder inaccessible",
    "zhHant": "無法存取資料夾",
    "zhHans": "无法访问文件夹",
    "ja": "フォルダにアクセスできません",
    "ko": "폴더에 접근할 수 없습니다"
}

with open("i18n/ui-strings.json", "w") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
