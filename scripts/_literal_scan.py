import re,sys
CJK=re.compile(r'[一-鿿]')
def literals(src, lang):
    """回傳 [(行, 正規化樣式)]：只取含漢字的字串字面值，內插換成 {}。"""
    out=[]; i=0; n=len(src); line=1
    while i<n:
        c=src[i]
        if c=='\n': line+=1; i+=1; continue
        if src.startswith('//',i):
            while i<n and src[i]!='\n': i+=1
            continue
        if src.startswith('/*',i):
            j=src.find('*/',i+2); j=n if j<0 else j+2
            line+=src.count('\n',i,j); i=j; continue
        if c=='"':
            if lang=='kt' and src.startswith('"""',i): 
                j=src.find('"""',i+3); j=n if j<0 else j+3; line+=src.count('\n',i,j); i=j; continue
            start=line; i+=1; buf=[]; 
            while i<n and src[i]!='"':
                ch=src[i]
                if ch=='\\' and i+1<n:
                    if lang=='swift' and src[i+1]=='(':
                        depth=1; i+=2
                        while i<n and depth: 
                            if src[i]=='(' : depth+=1
                            elif src[i]==')': depth-=1
                            i+=1
                        buf.append('{}'); continue
                    buf.append({'n':'\n','t':'\t','"':'"','\\':'\\','$':'$'}.get(src[i+1],src[i+1])); i+=2; continue
                if lang=='kt' and ch=='$':
                    if i+1<n and src[i+1]=='{':
                        depth=1; i+=2
                        while i<n and depth:
                            if src[i]=='{': depth+=1
                            elif src[i]=='}': depth-=1
                            elif src[i]=='"':   # 內嵌字串
                                i+=1
                                while i<n and src[i]!='"': i+= 2 if src[i]=='\\' else 1
                            i+=1
                        buf.append('{}'); continue
                    m=re.match(r'\$[A-Za-z_]\w*',src[i:])
                    if m: i+=len(m.group(0)); buf.append('{}'); continue
                if ch=='\n': line+=1
                buf.append(ch); i+=1
            i+=1
            s=''.join(buf)
            if CJK.search(s): out.append((start,re.sub(r'\s+',' ',s).strip()))
            continue
        i+=1
    return out
if __name__=='__main__':
    for f in sys.argv[1:]:
        lang='swift' if f.endswith('.swift') else 'kt'
        for ln,p in literals(open(f).read(),lang): print(f"{f.split('/')[-1]}:{ln}\t{p}")
