// 開發用：用 CoreText 排一段文字，印出「字形編號 x y」（原點座標，字型單位），
// 給 scripts/verify-otl-coretext.py 與 padnote-export 的 otl 引擎比對。
// 用法：swift scripts/ct_dump.swift <字型檔> <TTC 索引> <文字>
import CoreText
import Foundation

let args = CommandLine.arguments
guard args.count == 4 else { FileHandle.standardError.write(Data("用法：ct_dump <字型檔> <索引> <文字>\n".utf8)); exit(2) }
let url = URL(fileURLWithPath: args[1]) as CFURL
guard let descs = CTFontManagerCreateFontDescriptorsFromURL(url) as? [CTFontDescriptor],
      let index = Int(args[2]), index < descs.count else { print("nofont"); exit(0) }
let probe = CTFontCreateWithFontDescriptor(descs[index], 1000, nil)
let upm = Double(CTFontGetUnitsPerEm(probe))
let font = CTFontCreateWithFontDescriptor(descs[index], upm, nil) // 字級 = upm → 1 字型單位 = 1 點
print("upm \(Int(upm))")
let attributed = NSAttributedString(string: args[3], attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font])
let line = CTLineCreateWithAttributedString(attributed)
for run in CTLineGetGlyphRuns(line) as! [CTRun] {
    let n = CTRunGetGlyphCount(run)
    var glyphs = [CGGlyph](repeating: 0, count: n)
    var pos = [CGPoint](repeating: .zero, count: n)
    CTRunGetGlyphs(run, CFRange(location: 0, length: 0), &glyphs)
    CTRunGetPositions(run, CFRange(location: 0, length: 0), &pos)
    // 字體備援：這一段沒用我們指定的字型，代表字型缺字，不拿來比對。
    let attrs = CTRunGetAttributes(run) as NSDictionary
    let runFont = attrs[kCTFontAttributeName as String] as! CTFont
    if CTFontCopyPostScriptName(runFont) != CTFontCopyPostScriptName(font) { print("fallback"); exit(0) }
    for i in 0..<n { print("\(glyphs[i]) \(Int(pos[i].x.rounded())) \(Int(pos[i].y.rounded()))") }
}
