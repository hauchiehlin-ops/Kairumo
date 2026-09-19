import re
with open('scripts/bump-version.sh', 'r', encoding='utf-8') as f:
    text = f.read()

part1 = r"""python3 -c '
import re, sys, os
manual, privacy, new_ver, new_bundle = sys.argv\[1\], sys.argv\[2\], sys.argv\[3\], sys.argv\[4\]

def bump\(path\):
    if not os.path.isfile\(path\):
        return
    with open\(path, "r", encoding="utf-8"\) as f:
        lines = f.readlines\(\)
    out = \[\]
    for line in lines:
        # 只動「適用版本」那幾行與行文中明確寫出的 "Kairumo vX.Y.Z" 範例，
        # 不要全檔盲目替換數字 —— 文件裡還有日期、尺寸、快捷鍵之類的數字。
        if re.search\(r"\[\\"\'\]\?\(version\|appver\)\[\\"\'\]\?\\s\*:", line\):
            line = re.sub\(r"\\d\+\\.\\d\+\\.\\d\+", new_ver, line\)
            line = re.sub\(r"\(\(?:bundle\|build\)\\s\*\)\\d\+", r"\\g<1>" \+ new_bundle, line\)
        line = re.sub\(r"\(Kairumo\\s\+v\)\\d\+\\.\\d\+\\.\\d\+", r"\\g<1>" \+ new_ver, line\)
        out.append\(line\)
    with open\(path, "w", encoding="utf-8"\) as f:
        f.writelines\(out\)

bump\(manual\)
bump\(privacy\)
' "\$DOC_MANUAL" "\$DOC_PRIVACY" "\$NEW_VERSION" "\$NEW_BUNDLE_VERSION\""""

repl1 = """python3 -c '
import re, sys, os
new_ver, new_bundle, repo_root = sys.argv[1], sys.argv[2], sys.argv[3]

docs = [
    "docs/manual/manual.js", "docs/manual/manual-apple.js", "docs/manual/manual-android.js",
    "docs/legal/privacy.html", "docs/legal/privacy-apple.html", "docs/legal/privacy-android.html"
]

def bump(rel_path):
    path = os.path.join(repo_root, rel_path)
    if not os.path.isfile(path):
        return
    with open(path, "r", encoding="utf-8") as f:
        lines = f.readlines()
    out = []
    for line in lines:
        if re.search(r"[\"']?(version|appver)[\"']?\s*:", line):
            line = re.sub(r"\d+\.\d+\.\d+", new_ver, line)
            line = re.sub(r"((?:bundle|build)\s*)\d+", r"\g<1>" + new_bundle, line)
        line = re.sub(r"(Kairumo\s+v)\d+\.\d+\.\d+", r"\g<1>" + new_ver, line)
        out.append(line)
    with open(path, "w", encoding="utf-8") as f:
        f.writelines(out)

for d in docs:
    bump(d)
' "$NEW_VERSION" "$NEW_BUNDLE_VERSION" "$REPO_ROOT" """

part2 = r"""cargo, yml, pbx, gradle, manual, privacy, new_ver, new_bundle = sys.argv\[1:9\]"""
repl2 = r"""cargo, yml, pbx, gradle, new_ver, new_bundle = sys.argv[1:7]
repo_root = os.path.dirname(os.path.dirname(cargo))"""

part3 = r"""for doc, label in \(\(manual, "docs/manual/manual.js"\), \(privacy, "docs/legal/privacy.html"\)\):
    if not os.path.isfile\(doc\):
        continue
    text = read\(doc\)
    stale = set\(\)
    for line in text.splitlines\(\):
        if re.search\(r"\[\\"\'\]\?\(version\|appver\)\[\\"\'\]\?\\s\*:", line\):
            stale.update\(v for v in re.findall\(r"\\d\+\\.\\d\+\\.\\d\+", line\) if v != new_ver\)
    if stale:
        problems.append\(f"\{label\} 還有沒更新的版本號：\{sorted\(stale\)\}"\)

if problems:
    for p in problems:
        print\("❌ " \+ p, file=sys.stderr\)
    sys.exit\(1\)
print\("✅ 版本號已在 Cargo.toml / project.yml / project.pbxproj / build.gradle.kts / 使用者文件 全數對齊"\)
' "\$CARGO_TOML" "\$APPLE_PROJECT_YML" "\$APPLE_PBXPROJ" "\$ANDROID_GRADLE" "\$DOC_MANUAL" "\$DOC_PRIVACY" "\$NEW_VERSION" "\$NEW_BUNDLE_VERSION\""""

repl3 = """docs = [
    "docs/manual/manual.js", "docs/manual/manual-apple.js", "docs/manual/manual-android.js",
    "docs/legal/privacy.html", "docs/legal/privacy-apple.html", "docs/legal/privacy-android.html"
]
for doc in docs:
    path = os.path.join(repo_root, doc)
    if not os.path.isfile(path):
        continue
    text = read(path)
    stale = set()
    for line in text.splitlines():
        if re.search(r"[\"']?(version|appver)[\"']?\s*:", line):
            stale.update(v for v in re.findall(r"\d+\.\d+\.\d+", line) if v != new_ver)
    if stale:
        problems.append(f"{doc} 還有沒更新的版本號：{sorted(stale)}")

if problems:
    for p in problems:
        print("❌ " + p, file=sys.stderr)
    sys.exit(1)
print("✅ 版本號已在 Cargo.toml / project.yml / project.pbxproj / build.gradle.kts / 使用者文件 全數對齊")
' "$CARGO_TOML" "$APPLE_PROJECT_YML" "$APPLE_PBXPROJ" "$ANDROID_GRADLE" "$NEW_VERSION" "$NEW_BUNDLE_VERSION\""""

text = re.sub(part1, repl1, text, flags=re.MULTILINE|re.DOTALL)
text = re.sub(part2, repl2, text)
text = re.sub(part3, repl3, text, flags=re.MULTILINE|re.DOTALL)

with open('scripts/bump-version.sh', 'w', encoding='utf-8') as f:
    f.write(text)

print("done")
