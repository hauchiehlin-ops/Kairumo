import re, subprocess, pathlib, json

root = pathlib.Path('.')
# 1. 收集核心所有 #[uniffi::export] 的自由函式與方法
fns = {}   # rust_name -> file
for p in root.glob('crates/padnote-core/src/*.rs'):
    src = p.read_text(encoding='utf-8')
    lines = src.split('\n')
    for i, line in enumerate(lines):
        if '#[uniffi::export' not in line:
            continue
        # 往下找第一個 fn
        for j in range(i, min(i+40, len(lines))):
            m = re.match(r'\s*(?:pub )?fn (\w+)', lines[j])
            if m:
                fns[m.group(1)] = p.name
                break
            if re.match(r'\s*impl ', lines[j]):
                # impl 區塊：把裡面所有 pub fn 都收進來
                depth = 0
                for k in range(j, len(lines)):
                    depth += lines[k].count('{') - lines[k].count('}')
                    mm = re.match(r'\s*pub fn (\w+)', lines[k])
                    if mm:
                        fns[mm.group(1)] = p.name
                    if depth <= 0 and k > j:
                        break
                break

def camel(name):
    parts = name.split('_')
    return parts[0] + ''.join(w[:1].upper()+w[1:] for w in parts[1:])

apple = subprocess.run(['bash','-c',"cat apple/Sources/*.swift apple/Examples/*.swift 2>/dev/null"],
                       capture_output=True, text=True).stdout
android = subprocess.run(['bash','-c',
    "find android/app/src/main/java/com/kairumo -name '*.kt' -exec cat {} + 2>/dev/null"],
                       capture_output=True, text=True).stdout

rows = []
for rust_name, file in sorted(fns.items()):
    c = camel(rust_name)
    in_a = bool(re.search(r'\b'+re.escape(c)+r'\b', apple))
    in_k = bool(re.search(r'\b'+re.escape(c)+r'\b', android))
    rows.append((rust_name, c, file, in_a, in_k))

none = [r for r in rows if not r[3] and not r[4]]
apple_only = [r for r in rows if r[3] and not r[4]]
android_only = [r for r in rows if r[4] and not r[3]]

print(f"核心匯出的 FFI 函式/方法：{len(rows)}")
print(f"\n=== 兩邊都沒有呼叫（{len(none)}）===")
for r in none:
    print(f"  {r[0]:40s} {r[2]}")
print(f"\n=== 只有 Apple 呼叫（{len(apple_only)}）===")
for r in apple_only:
    print(f"  {r[0]:40s} {r[2]}")
print(f"\n=== 只有 Android 呼叫（{len(android_only)}）===")
for r in android_only:
    print(f"  {r[0]:40s} {r[2]}")
