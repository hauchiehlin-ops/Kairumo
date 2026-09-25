import re
with open("android/app/src/main/java/com/kairumo/padnote/MainActivity.kt", "r") as f:
    text = f.read()

text = text.replace(
    'backlogUs = runCatching { notebook?.first?.transcriptionBacklogUs() ?: 0L }.getOrDefault(0L)',
    'backlogUs = runCatching { notebook?.first?.transcriptionBacklogUs()?.toLong() ?: 0L }.getOrDefault(0L)'
)
with open("android/app/src/main/java/com/kairumo/padnote/MainActivity.kt", "w") as f:
    f.write(text)
