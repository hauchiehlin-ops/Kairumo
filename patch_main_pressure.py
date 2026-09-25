import re
with open("android/app/src/main/java/com/kairumo/padnote/MainActivity.kt", "r") as f:
    lines = f.readlines()

for i, line in enumerate(lines):
    if "setPressureCurve" in line:
        if i > 5000:  # in the dialog callback
            lines[i] = line.replace("setPressureCurve(", "engine.setPressureCurve(")
        
with open("android/app/src/main/java/com/kairumo/padnote/MainActivity.kt", "w") as f:
    f.writelines(lines)
