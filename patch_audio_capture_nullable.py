import re
with open("android/app/src/main/java/com/kairumo/padnote/platform/AudioCapture.kt", "r") as f:
    text = f.read()

text = text.replace("fun start(pageId: String,", "fun start(pageId: String?,")
text = text.replace(
    'transcriber?.start(pageId, languageTag)',
    'if (pageId != null) transcriber?.start(pageId, languageTag)'
)

with open("android/app/src/main/java/com/kairumo/padnote/platform/AudioCapture.kt", "w") as f:
    f.write(text)
