import re
with open("android/app/src/main/java/com/kairumo/padnote/sync/FolderSync.kt", "r") as f:
    text = f.read()

text = text.replace(
    'LocalizationStrings.localized("folder_sync_not_set")',
    'LocalizationStrings.localized("folder_sync_not_set", context.resources.configuration.locales[0].toLanguageTag())'
)
text = text.replace(
    'LocalizationStrings.localized("folder_sync_inaccessible")',
    'LocalizationStrings.localized("folder_sync_inaccessible", context.resources.configuration.locales[0].toLanguageTag())'
)

with open("android/app/src/main/java/com/kairumo/padnote/sync/FolderSync.kt", "w") as f:
    f.write(text)
