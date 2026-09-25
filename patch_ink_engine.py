import re
with open("android/app/src/main/java/com/kairumo/padnote/ink/InkEngine.kt", "r") as f:
    text = f.read()

text = text.replace(
"""    fun setPalmThresholds(palmRadiusDp: Float?, retractWindowMs: UInt?) {
        overrideRadiusDp = palmRadiusDp
        overrideRetractMs = retractWindowMs
        applyPalmThresholds(lastPenOnly)
    }""",
"""    fun setPalmThresholds(palmRadiusDp: Float?, retractWindowMs: UInt?) {
        overrideRadiusDp = palmRadiusDp
        overrideRetractMs = retractWindowMs
        applyPalmThresholds(lastPenOnly)
    }
    
    fun setPressureCurve(floor: Float, gamma: Float) {
        arbiter.setPressureCurve(floor, gamma)
    }""")

with open("android/app/src/main/java/com/kairumo/padnote/ink/InkEngine.kt", "w") as f:
    f.write(text)
