import re

with open("android/app/src/main/java/com/kairumo/padnote/audio/StreamingTranscriber.kt", "r") as f:
    text = f.read()

# Fix words -> segments
text = text.replace("result.words", "result.segments")

# Fix startUs / endUs
# wait, TranscriptWordInput expects startUs and endUs
text = text.replace(
"""                                TranscriptWordInput(
                                    text = w.text,
                                    // 偏移量：從這段音訊在筆記本的時間點開始加
                                    startUs = seg.sessionStartUs + seg.startUs + w.startUs,
                                    endUs = seg.sessionStartUs + seg.startUs + w.endUs,
                                    confidence = w.confidence
                                )""",
"""                                TranscriptWordInput(
                                    text = w.text,
                                    // 偏移量：從這段音訊在筆記本的時間點開始加
                                    startUs = seg.sessionStartUs + seg.startUs + w.startMs * 1000u,
                                    endUs = seg.sessionStartUs + seg.startUs + w.endMs * 1000u,
                                    confidence = w.confidence
                                )""")

with open("android/app/src/main/java/com/kairumo/padnote/audio/StreamingTranscriber.kt", "w") as f:
    f.write(text)
