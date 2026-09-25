import re
with open("android/app/src/main/java/com/kairumo/padnote/MainActivity.kt", "r") as f:
    text = f.read()

text = text.replace(
    'message = audio.start(notebook?.second?.pages?.get(viewport.currentPage)?.id ?: "", session, deviceLanguageTag()) { message = it }',
    'message = audio.start(pageId ?: "", session, deviceLanguageTag()) { message = it }'
)

# And fix setPressureCurve
text = text.replace(
    'notebook?.first?.setPressureCurve(',
    'engine.setPressureCurve('
)
text = text.replace(
    'notebook?.first?.setPressureCurve(floor ?: 0.1f, gamma ?: 1.0f)',
    'engine.setPressureCurve(floor ?: 0.1f, gamma ?: 1.0f)'
)
# Wait, engine is already instantiated? Let's check the context for setPressureCurve.
with open("android/app/src/main/java/com/kairumo/padnote/MainActivity.kt", "w") as f:
    f.write(text)
