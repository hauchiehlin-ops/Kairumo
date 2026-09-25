import re
with open("android/app/src/main/java/com/kairumo/padnote/sync/FolderSync.kt", "r") as f:
    text = f.read()

text = text.replace("import com.kairumo.padnote.LocalizationStrings\npackage ", "package ")
text = text.replace("package com.kairumo.padnote.sync", "package com.kairumo.padnote.sync\n\nimport com.kairumo.padnote.LocalizationStrings")

with open("android/app/src/main/java/com/kairumo/padnote/sync/FolderSync.kt", "w") as f:
    f.write(text)
