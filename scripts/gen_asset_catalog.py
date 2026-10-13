#!/usr/bin/env python3
"""素材圖庫擴充目錄的產生器。

產出兩樣東西：
  1. `crates/padnote-core/src/asset_catalog_more.rs` —— 目錄列（`MORE`）與線圖代號清單（`MORE_CODES`）。
  2. `i18n/ui-strings.json` 裡每件素材的 `asset_<id>_title`（六語系）。

為什麼用產生器：新增素材 ≈ 一列資料 + 一個繪圖分支 + 六句名稱。手寫三處一定會漏（目錄有、翻譯沒有；翻譯有、線圖沒有）。
資料集中在這個檔案，產生器保證三處一致；核心的測試再確認每個代號都真的畫得出東西。

用法：python3 scripts/gen_asset_catalog.py        （重新產生；之後再跑 `scripts/i18n_tool.py generate`）
"""
import json
import math
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parent.parent
LANGS = ["zhHant", "en", "zhHans", "ja", "ko", "th"]


def T(zh, en, hans, ja, ko, th):
    return dict(zip(LANGS, (zh, en, hans, ja, ko, th)))


PHYS, AI = "PhysicalSpec", "AiConcept"
FAMILIES = []  # (category, source, code, titles, [(param, specs, material, dims)])


def fam(cat, src, code, titles, variants):
    FAMILIES.append((cat, src, code, titles, variants))


def single(cat, src, code, titles, specs, material, dims):
    fam(cat, src, code, titles, [("", specs, material, dims)])


# ═══ 機構設計 ═══════════════════════════════════════════════════════
M = "Mechanism"
fam(M, PHYS, "spur_gear", T("正齒輪 Z={p}", "Spur Gear Z={p}", "直齿轮 Z={p}", "平歯車 Z={p}", "평기어 Z={p}", "เฟืองตรง Z={p}"),
    [(str(n), f"m 2 · Z {n} · α 20° · JIS 3", "S45C · HRC 50–55", f"Ø{2 * (n + 2)} × 15 mm") for n in (12, 18, 24, 36, 48)])
fam(M, PHYS, "timing_pulley", T("同步帶輪 {p}T", "Timing Pulley {p}T", "同步带轮 {p}T", "タイミングプーリ {p}T", "타이밍 풀리 {p}T", "พูลเลย์ไทม์มิ่ง {p}T"),
    [(str(n), f"GT2 · 2 mm pitch · {n}T · bore Ø5", "6061 Al · anodised", f"Ø{n * 2 / math.pi:.1f} pitch × 16 mm") for n in (16, 20, 40)])
fam(M, PHYS, "coil_spring", T("壓縮彈簧 {p} 圈", "Compression Spring {p} Turns", "压缩弹簧 {p} 圈", "圧縮ばね {p} 巻", "압축 스프링 {p}회", "สปริงอัด {p} รอบ"),
    [(str(n), f"d 2.0 · {n} active coils · k {int(120 / n * 4)} N/mm", "SWOSC-V · shot-peened", f"Ø20 × {n * 12} mm free") for n in (4, 6, 8)])
single(M, PHYS, "four_bar", T("四連桿機構", "Four-Bar Linkage", "四连杆机构", "四節リンク機構", "4절 링크 기구", "กลไกสี่ก้านต่อ"),
       "Grashof crank-rocker · ratio 1 : 2.4 : 2 : 3", "S45C / 6061 Al", "L 180 × H 140 mm")
single(M, PHYS, "slider_crank", T("曲柄滑塊機構", "Slider-Crank Mechanism", "曲柄滑块机构", "スライダクランク機構", "슬라이더 크랭크 기구", "กลไกลูกสูบข้อเหวี่ยง"),
       "stroke 2r · rod/crank 3 : 1", "SCM440 · nitrided", "L 240 × H 100 mm")
single(M, PHYS, "rack_pinion", T("齒輪齒條", "Rack and Pinion", "齿轮齿条", "ラック＆ピニオン", "랙 앤 피니언", "เฟืองสะพาน"),
       "m 2 · Z 14 · α 20° · 1 rev = 88 mm", "S45C · induction hardened", "L 280 × H 38 mm")
single(M, PHYS, "worm_gear", T("蝸桿蝸輪", "Worm and Wheel", "蜗杆蜗轮", "ウォームギヤ", "웜 기어", "เฟืองตัวหนอน"),
       "i 30:1 · lead angle 4° · self-locking", "SCM415 / CuSn12", "Ø128 wheel × 30 mm")
single(M, PHYS, "planetary_gear", T("行星齒輪組", "Planetary Gearset", "行星齿轮组", "遊星歯車機構", "유성 기어", "ชุดเฟืองดาวเคราะห์"),
       "sun 12T · planet 14T · ring 48T · i 5:1", "S45C · HRC 55", "Ø132 × 24 mm")
single(M, PHYS, "ratchet_pawl", T("棘輪棘爪", "Ratchet and Pawl", "棘轮棘爪", "ラチェット機構", "래칫과 폴", "เฟืองฟันเลื่อยและตัวล็อก"),
       "14 teeth · 25.7° step · one-way", "SK5 · HRC 56", "Ø216 × 12 mm")
single(M, PHYS, "universal_joint", T("萬向接頭", "Universal Joint", "万向接头", "自在継手", "유니버설 조인트", "ข้อต่ออเนกประสงค์"),
       "Hooke · β ≤ 45° · 1 : 1 at 0°", "SCM435 · forged", "Ø25 × L 90 mm")
single(M, PHYS, "bevel_gear", T("傘齒輪", "Bevel Gear", "锥齿轮", "かさ歯車", "베벨 기어", "เฟืองเฉียง"),
       "m 2.5 · Z 20 · shaft angle 90°", "S45C · HRC 50", "Ø60 × 36 mm")
single(M, AI, "ai_bionic_muscle", T("仿生肌纖維致動器", "Bionic Muscle-Fibre Actuator", "仿生肌纤维致动器", "生体模倣筋繊維アクチュエータ", "생체모방 근섬유 액추에이터", "แอคทูเอเตอร์เส้นใยกล้ามเนื้อชีวภาพ"),
       "bundled fibres · contraction 25 % · 60 W/kg", "EAP / CNT yarn", "L 200 × Ø40 mm")
single(M, AI, "ai_origami_fold", T("摺紙式可展開機構", "Origami Deployable Mechanism", "折纸式可展开机构", "折り紙式展開機構", "종이접기식 전개 기구", "กลไกกางออกแบบโอริงามิ"),
       "Miura fold · packing ratio 1 : 12", "PET film / CFRP", "240 × 240 → 60 × 60 mm")

# ═══ 五金零件 ═══════════════════════════════════════════════════════
H = "Hardware"
fam(H, PHYS, "hex_bolt_m", T("六角螺栓 {p}", "Hex Bolt {p}", "六角螺栓 {p}", "六角ボルト {p}", "육각 볼트 {p}", "สลักเกลียวหกเหลี่ยม {p}"),
    [(f"M{d}", f"M{d} × {d * 5} · ISO 4017 · 8.8", "Carbon steel · zinc plated", f"{d} × {d * 5} mm · AF {({4: 7, 6: 10, 8: 13, 10: 16, 12: 18})[d]}") for d in (4, 6, 8, 10, 12)])
fam(H, PHYS, "hex_nut", T("六角螺帽 {p}", "Hex Nut {p}", "六角螺母 {p}", "六角ナット {p}", "육각 너트 {p}", "น็อตหกเหลี่ยม {p}"),
    [(f"M{d}", f"{('M' + str(d))} · ISO 4032 · class 8", "Carbon steel · zinc plated", f"AF {({4: 7, 6: 10, 8: 13, 10: 16})[d]} × H {({4: 3.2, 6: 5.2, 8: 6.8, 10: 8.4})[d]} mm") for d in (4, 6, 8, 10)])
fam(H, PHYS, "socket_cap", T("內六角螺釘 {p}", "Socket Cap Screw {p}", "内六角螺钉 {p}", "六角穴付きボルト {p}", "육각 구멍 볼트 {p}", "สกรูหัวจมหกเหลี่ยมใน {p}"),
    [(f"M{d}", f"M{d} × {d * 4} · ISO 4762 · 12.9", "Alloy steel · black oxide", f"Ø{({3: 5.5, 5: 8.5, 8: 13})[d]} head × {d * 4} mm") for d in (3, 5, 8)])
fam(H, PHYS, "washer", T("平墊圈 {p}", "Flat Washer {p}", "平垫圈 {p}", "平座金 {p}", "평와셔 {p}", "แหวนรองเรียบ {p}"),
    [(f"M{d}", f"M{d} · ISO 7089 · 200 HV", "SUS304 / zinc steel", f"Ø{({4: 9, 6: 12, 8: 16})[d]} × Ø{({4: 4.3, 6: 6.4, 8: 8.4})[d]} × {({4: 0.8, 6: 1.6, 8: 1.6})[d]} mm") for d in (4, 6, 8)])
single(H, PHYS, "dowel_pin", T("定位銷", "Dowel Pin", "定位销", "位置決めピン", "위치결정 핀", "พินกำหนดตำแหน่ง"), "ISO 8734 · m6 · chamfered ends", "SUJ2 · HRC 60", "Ø6 × 24 mm")
single(H, PHYS, "feather_key", T("平行鍵", "Parallel Key", "平行键", "平行キー", "평행 키", "ลิ่มขนาน"), "DIN 6885 · type A · 8 × 7", "S45C", "8 × 7 × 40 mm")
single(H, PHYS, "eye_bolt", T("吊環螺栓", "Eye Bolt", "吊环螺栓", "アイボルト", "아이 볼트", "สลักตาเหล็ก"), "DIN 580 · WLL 230 kg · M8", "C15E · forged", "M8 × 16 · eye Ø20")
single(H, PHYS, "clevis_pin", T("叉銷", "Clevis Pin", "叉销", "クレビスピン", "클레비스 핀", "พินคลีวิส"), "ISO 2341 · type B · with split pin", "S355 · zinc", "Ø10 × 40 mm")
single(H, PHYS, "turnbuckle", T("花籃螺絲", "Turnbuckle", "花篮螺丝", "ターンバックル", "턴버클", "เทิร์นบักเคิล"), "DIN 1480 · M10 · left/right thread", "Carbon steel · galvanised", "L 190 · stroke ±40 mm")
single(H, PHYS, "butt_hinge", T("平板合頁", "Butt Hinge", "平板合页", "平蝶番", "경첩", "บานพับเรียบ"), "5 knuckles · 2 mm leaf · 4 holes", "SUS304", "100 × 75 × 2 mm")
single(H, PHYS, "caster_wheel", T("腳輪", "Caster Wheel", "脚轮", "キャスター", "캐스터", "ล้อเลื่อน"), "swivel · 75 mm · load 60 kg", "PU tread / steel", "Ø75 × H 105 mm")
single(H, PHYS, "u_bolt", T("U 型螺栓", "U-Bolt", "U 型螺栓", "Uボルト", "U볼트", "ยูโบลต์"), "M8 · for Ø25 pipe · DIN 3570", "SUS304", "Ø25 inner · L 70 mm")
single(H, PHYS, "threaded_rod", T("全牙螺桿", "Threaded Rod", "全牙螺杆", "全ねじボルト", "전산 볼트", "เหล็กเกลียวตลอด"), "DIN 975 · M8 · class 4.8", "Carbon steel · zinc", "M8 × 1000 mm")
single(H, AI, "ai_gecko_clamp", T("仿壁虎乾式黏附夾具", "Gecko-Inspired Dry-Adhesive Clamp", "仿壁虎干式粘附夹具", "ヤモリ模倣ドライ接着クランプ", "게코 모방 건식 접착 클램프", "แคลมป์ยึดติดแห้งแบบตุ๊กแก"),
       "micro-setae · 30 N/cm² · reusable", "PDMS / Si wafer", "60 × 40 mm pad")
single(H, AI, "ai_memory_fastener", T("形狀記憶合金扣件", "Shape-Memory Alloy Fastener", "形状记忆合金扣件", "形状記憶合金ファスナー", "형상기억합금 체결구", "ตัวยึดโลหะผสมจำรูป"),
       "Af 60 °C · 6 % recovery strain", "NiTi", "Ø6 × 30 mm")

# ═══ 汽車載具 ═══════════════════════════════════════════════════════
A = "Automotive"
fam(A, PHYS, "rim_spokes", T("鋁合金輪圈 {p} 輻", "Alloy Wheel {p}-Spoke", "铝合金轮圈 {p} 辐", "アルミホイール {p}スポーク", "알로이 휠 {p}스포크", "ล้ออัลลอยด์ {p} ก้าน"),
    [(str(n), f"18 × 8J · ET 35 · PCD 5×114.3 · {n} spokes", "A356 · cast / T6", "Ø457 × 203 mm") for n in (5, 6, 10)])
fam(A, PHYS, "brake_disc", T("煞車碟盤（{p}）", "Brake Disc ({p})", "制动盘（{p}）", "ブレーキディスク（{p}）", "브레이크 디스크({p})", "จานเบรก ({p})"),
    [("vented", "Ø330 × 28 · vented · 2-piece", "GG25 cast iron", "Ø330 × 28 mm"), ("drilled", "Ø300 × 24 · cross-drilled", "Cast iron · coated", "Ø300 × 24 mm")])
# 煞車碟盤的 {p} 需要語系詞，單獨處理（見 DISC_NAMES）
fam(A, PHYS, "car_profile", T("車身側視輪廓（{p}）", "Car Side Profile ({p})", "车身侧视轮廓（{p}）", "車体側面輪郭（{p}）", "차체 측면 윤곽({p})", "โครงรถด้านข้าง ({p})"),
    [("sedan", "wheelbase 2800 · Cd 0.27", "Monocoque steel", "L 4700 × H 1450 mm"),
     ("suv", "wheelbase 2750 · Cd 0.33", "Monocoque steel / Al", "L 4600 × H 1700 mm"),
     ("hatch", "wheelbase 2600 · Cd 0.30", "Monocoque steel", "L 4000 × H 1500 mm")])
single(A, PHYS, "turbocharger", T("渦輪增壓器", "Turbocharger", "涡轮增压器", "ターボチャージャー", "터보차저", "เทอร์โบชาร์จเจอร์"), "A/R 0.8 · 1.0 bar · 180 kRPM", "Inconel 713 / Al", "Ø140 × L 220 mm")
single(A, PHYS, "shock_absorber", T("避震器", "Shock Absorber", "减震器", "ショックアブソーバー", "쇼크 업소버", "โช้คอัพ"), "twin-tube · stroke 150 · coil-over", "SAE 1045 / SWOSC-V", "Ø50 × L 380 mm")
single(A, PHYS, "piston_rod", T("活塞連桿組", "Piston and Connecting Rod", "活塞连杆组", "ピストンとコンロッド", "피스톤과 커넥팅 로드", "ลูกสูบและก้านสูบ"), "bore Ø86 · stroke 86 · CR 10.5", "Forged Al / 4340", "Ø86 × L 150 mm")
single(A, AI, "ai_flying_car", T("四旋翼飛行汽車", "Quad-Rotor Flying Car", "四旋翼飞行汽车", "四ローター空飛ぶ車", "쿼드로터 플라잉카", "รถบินสี่โรเตอร์"), "VTOL · 4 × 150 kW · range 200 km", "CFRP monocoque", "L 5500 × span 6000 mm")
single(A, AI, "ai_modular_ev", T("滑板式模組化電動車", "Modular Skateboard EV", "滑板式模块化电动车", "スケートボード型モジュラーEV", "스케이트보드형 모듈형 전기차", "รถไฟฟ้าโมดูลาร์แบบสเก็ตบอร์ด"), "800 V · 100 kWh · swappable body", "Al extrusion / CFRP", "L 3200 × W 1700 mm")

# ═══ 工業家具 ═══════════════════════════════════════════════════════
F = "Furniture"
fam(F, PHYS, "chair", T("椅子（{p}）", "Chair ({p})", "椅子（{p}）", "椅子（{p}）", "의자({p})", "เก้าอี้ ({p})"),
    [("dining", "seat H 450 · back 45°", "Beech / ash", "W 440 × D 480 × H 820 mm"),
     ("stool", "seat H 650 · 3-leg brace", "Oak / steel", "Ø350 × H 650 mm"),
     ("office", "5-star base · gas lift · tilt", "Nylon / mesh / steel", "W 650 × D 650 × H 1100 mm")])
fam(F, PHYS, "table", T("桌子（{p}）", "Table ({p})", "桌子（{p}）", "テーブル（{p}）", "테이블({p})", "โต๊ะ ({p})"),
    [("dining", "top H 740 · 6 seats", "Oak veneer / steel", "W 1600 × D 800 × H 740 mm"),
     ("coffee", "top H 420 · lower shelf", "Walnut / brass", "W 900 × D 500 × H 420 mm"),
     ("desk", "top H 740 · drawer pedestal", "MDF / steel", "W 1400 × D 700 × H 740 mm")])
fam(F, PHYS, "shelf", T("置物架（{p}）", "Shelving ({p})", "置物架（{p}）", "棚（{p}）", "선반({p})", "ชั้นวาง ({p})"),
    [("bookcase", "4 shelves · adj. pitch 32", "Plywood / powder-coated steel", "W 800 × D 300 × H 1800 mm"),
     ("wall", "3 floating shelves · load 15 kg", "Birch ply", "W 800 × D 200 mm")])
fam(F, PHYS, "sofa", T("{p} 人沙發", "{p}-Seat Sofa", "{p} 人沙发", "{p}人掛けソファ", "{p}인 소파", "โซฟา {p} ที่นั่ง"),
    [("2", "seat H 420 · foam 35 kg/m³", "Fabric / pine frame", "W 1600 × D 850 × H 800 mm"),
     ("3", "seat H 420 · foam 35 kg/m³", "Fabric / pine frame", "W 2200 × D 850 × H 800 mm")])
single(F, PHYS, "bed_frame", T("床架", "Bed Frame", "床架", "ベッドフレーム", "침대 프레임", "โครงเตียง"), "queen · slat spacing 60", "Solid ash", "W 1600 × L 2100 × H 950 mm")
single(F, PHYS, "floor_lamp", T("落地燈", "Floor Lamp", "落地灯", "フロアランプ", "플로어 램프", "โคมไฟตั้งพื้น"), "E27 · 10 W LED · 2700 K", "Steel / linen shade", "Ø350 × H 1500 mm")
single(F, PHYS, "cabinet", T("雙門櫃", "Two-Door Cabinet", "双门柜", "両開きキャビネット", "양문 캐비닛", "ตู้สองบาน"), "soft-close hinges · 1 shelf", "Melamine board", "W 800 × D 400 × H 1000 mm")
single(F, AI, "ai_modular_furniture", T("自由組合方塊家具", "Free-Form Block Furniture", "自由组合方块家具", "自在に組める積木家具", "자유 조합 블록 가구", "เฟอร์นิเจอร์บล็อกประกอบอิสระ"), "magnetic joints · 400 mm module", "Bamboo ply / magnets", "400 × 400 × 400 mm cube")
single(F, AI, "ai_floating_lounge", T("磁浮躺椅", "Magnetic-Levitation Lounger", "磁浮躺椅", "磁気浮上ラウンジチェア", "자기부상 라운지 체어", "เก้าอี้เอนนอนลอยด้วยแม่เหล็ก"), "levitation gap 20 mm · load 120 kg", "Carbon fibre / NdFeB", "L 1500 × W 700 mm")

# ═══ 3C 電子 ════════════════════════════════════════════════════════
E = "Electronics3C"
fam(E, PHYS, "pcb", T("開發板（{p}）", "Dev Board ({p})", "开发板（{p}）", "開発ボード（{p}）", "개발 보드({p})", "บอร์ดพัฒนา ({p})"),
    [("arduino", "ATmega328P · 14 GPIO · 5 V", "FR4 1.6 mm · ENIG", "68.6 × 53.4 mm"),
     ("raspi", "quad-core · 40-pin GPIO · USB-C", "FR4 1.6 mm", "85 × 56 mm"),
     ("esp32", "dual-core 240 MHz · Wi-Fi/BT", "FR4 · castellated", "51 × 25.5 mm")])
fam(E, PHYS, "connector", T("連接器（{p}）", "Connector ({p})", "连接器（{p}）", "コネクタ（{p}）", "커넥터({p})", "ขั้วต่อ ({p})"),
    [("usbc", "24-pin · USB 3.2 · 100 W PD", "LCP / SUS304 shell", "8.4 × 2.6 mm"),
     ("hdmi", "19-pin · HDMI 2.1 · 48 Gbps", "PA / brass", "14 × 4.5 mm"),
     ("jack", "TRS · Ø3.5 · 3 poles", "Brass · gold flash", "Ø3.5 × 14 mm"),
     ("rj45", "8P8C · Cat 6A", "PC / phosphor bronze", "11.7 × 13.5 mm")])
fam(E, PHYS, "ic_qfp", T("QFP 晶片 {p} 腳", "QFP-{p} IC", "QFP 芯片 {p} 脚", "QFP {p}ピン IC", "QFP {p}핀 IC", "ไอซี QFP {p} ขา"),
    [("32", "0.8 mm pitch · 7 × 7 body", "Epoxy / Cu leadframe", "9 × 9 mm"), ("48", "0.5 mm pitch · 7 × 7 body", "Epoxy / Cu leadframe", "9 × 9 mm")])
fam(E, PHYS, "ic_dip", T("DIP 晶片 {p} 腳", "DIP-{p} IC", "DIP 芯片 {p} 脚", "DIP {p}ピン IC", "DIP {p}핀 IC", "ไอซี DIP {p} ขา"),
    [("8", "2.54 mm pitch · 300 mil", "Epoxy / alloy 42", "9.3 × 6.4 mm"), ("16", "2.54 mm pitch · 300 mil", "Epoxy / alloy 42", "19.3 × 6.4 mm")])
fam(E, PHYS, "passive", T("被動元件（{p}）", "Passive Component ({p})", "被动元件（{p}）", "受動部品（{p}）", "수동 소자({p})", "ชิ้นส่วนพาสซีฟ ({p})"),
    [("smd", "0805 · 10 kΩ · ±1 %", "Thick film / Al₂O₃", "2.0 × 1.25 mm"),
     ("cap", "470 µF · 16 V · 105 °C", "Al foil / electrolyte", "Ø8 × 12 mm"),
     ("inductor", "10 µH · 3 A · shielded", "Ferrite / Cu", "7 × 7 × 3 mm")])
single(E, PHYS, "smartwatch", T("智慧手錶", "Smartwatch", "智能手表", "スマートウォッチ", "스마트워치", "สมาร์ทวอทช์"), "AMOLED 1.9\" · 50 m WR · 420 mAh", "Ti / sapphire", "44 × 38 × 10.7 mm")
single(E, PHYS, "power_bank", T("行動電源", "Power Bank", "移动电源", "モバイルバッテリー", "보조배터리", "พาวเวอร์แบงก์"), "20 000 mAh · 65 W PD · 4 ports", "Al shell / Li-polymer", "150 × 70 × 28 mm")
single(E, PHYS, "wireless_charger", T("無線充電座", "Wireless Charger", "无线充电座", "ワイヤレス充電器", "무선 충전기", "แท่นชาร์จไร้สาย"), "Qi2 · 15 W · magnetic alignment", "ABS / ferrite", "Ø75 × 8 mm")
single(E, PHYS, "smart_speaker", T("智慧音箱", "Smart Speaker", "智能音箱", "スマートスピーカー", "스마트 스피커", "ลำโพงอัจฉริยะ"), "360° · 4 mics · 30 W", "Fabric mesh / ABS", "Ø100 × H 180 mm")
single(E, PHYS, "vr_headset", T("VR 頭戴顯示器", "VR Headset", "VR 头戴显示器", "VRヘッドセット", "VR 헤드셋", "แว่น VR"), "2 × 2160² · 90 Hz · 110° FOV", "PC-ABS / foam", "190 × 175 × 95 mm")
single(E, AI, "ai_foldable_display", T("三折捲軸顯示器", "Tri-Fold Rollable Display", "三折卷轴显示器", "三つ折りローラブルディスプレイ", "3단 롤러블 디스플레이", "จอภาพพับสามทบแบบม้วนได้"), "OLED · fold R 1.5 mm · 4× fold", "UTG / PI film", "10\" → 30\" unfolded")
single(E, AI, "ai_neural_wearable", T("腦波貼片穿戴裝置", "Neural-Interface Patch", "脑波贴片穿戴设备", "脳波パッチ型ウェアラブル", "뇌파 패치 웨어러블", "แผ่นแปะคลื่นสมองแบบสวมใส่"), "dry electrodes · 8 ch · 250 Hz", "Graphene / TPU", "Ø60 × 3 mm")

# ═══ 數位產品 ═══════════════════════════════════════════════════════
D = "Digital"
fam(D, PHYS, "device_frame", T("裝置外框（{p}）", "Device Frame ({p})", "设备外框（{p}）", "デバイスフレーム（{p}）", "기기 프레임({p})", "กรอบอุปกรณ์ ({p})"),
    [("phone", "393 × 852 pt · 3× · safe area 59/34", "iOS / Android", "393 × 852 pt"),
     ("tablet", "834 × 1194 pt · 2×", "iPadOS / Android", "834 × 1194 pt"),
     ("laptop", "1440 × 900 pt · 2×", "macOS / Windows", "1440 × 900 pt"),
     ("monitor", "1920 × 1080 px · 16 : 9", "Desktop", "1920 × 1080 px"),
     ("watch", "198 × 242 pt · 2×", "watchOS / Wear OS", "198 × 242 pt")])
fam(D, PHYS, "wire", T("線框範本（{p}）", "Wireframe ({p})", "线框模板（{p}）", "ワイヤーフレーム（{p}）", "와이어프레임({p})", "ไวร์เฟรม ({p})"),
    [("landing", "hero · 3 features · footer · 12-col", "Low-fidelity", "1440 × 900 px"),
     ("dashboard", "sidebar · KPI cards · chart", "Low-fidelity", "1440 × 900 px"),
     ("login", "logo · 2 fields · primary CTA", "Low-fidelity", "390 × 844 pt"),
     ("card_list", "thumbnail · title · meta", "Low-fidelity", "390 × 844 pt"),
     ("kanban", "3 columns · draggable cards", "Low-fidelity", "1440 × 900 px"),
     ("chat", "bubbles · composer · send", "Low-fidelity", "390 × 844 pt")])
single(D, AI, "ai_spatial_ui", T("空間運算介面", "Spatial-Computing Interface", "空间计算界面", "空間コンピューティングUI", "공간 컴퓨팅 인터페이스", "อินเทอร์เฟซการประมวลผลเชิงพื้นที่"), "gaze + pinch · depth layers · 1 m focal", "visionOS / OpenXR", "2 m virtual canvas")
single(D, AI, "ai_adaptive_dashboard", T("自適應儀表板", "Adaptive Dashboard", "自适应仪表板", "適応型ダッシュボード", "적응형 대시보드", "แดชบอร์ดแบบปรับตัวอัตโนมัติ"), "usage-driven tile ordering", "ML ranking", "12-col responsive")

# ═══ 美學構圖與黃金比例 ═════════════════════════════════════════════
C = "AestheticComposition"
fam(C, PHYS, "comp", T("{p}", "{p}", "{p}", "{p}", "{p}", "{p}"), [])  # 占位，下面逐項單列
COMP = [
    ("golden_rect", T("黃金矩形分割", "Golden Rectangle Division", "黄金矩形分割", "黄金矩形の分割", "황금 사각형 분할", "การแบ่งสี่เหลี่ยมทองคำ"), "φ 1 : 1.618 · recursive split", "—", "any frame"),
    ("fibonacci_tiles", T("費氏方塊拼貼", "Fibonacci Tiling", "斐波那契方块拼贴", "フィボナッチタイリング", "피보나치 타일링", "การปูกระเบื้องฟีโบนัชชี"), "1 · 1 · 2 · 3 · 5 · 8", "—", "any frame"),
    ("diagonal", T("對角線構圖", "Diagonal Composition", "对角线构图", "対角線構図", "대각선 구도", "องค์ประกอบแนวทแยง"), "baroque · sinister diagonals", "—", "3 : 2 frame"),
    ("radial", T("放射構圖", "Radial Composition", "放射构图", "放射構図", "방사형 구도", "องค์ประกอบแบบรัศมี"), "12 spokes · focal centre", "—", "1 : 1 frame"),
    ("triangle", T("三角構圖", "Triangular Composition", "三角构图", "三角構図", "삼각 구도", "องค์ประกอบสามเหลี่ยม"), "stable apex · base ≥ ⅔ width", "—", "4 : 5 frame"),
    ("leading_lines", T("引導線構圖", "Leading Lines", "引导线构图", "誘導線構図", "리딩 라인 구도", "เส้นนำสายตา"), "vanishing point on upper third", "—", "16 : 9 frame"),
    ("frame_in_frame", T("框中框構圖", "Frame-in-Frame", "框中框构图", "額縁構図", "프레임 속 프레임", "กรอบซ้อนกรอบ"), "2 nested frames · 60 % scale", "—", "3 : 2 frame"),
    ("symmetry", T("對稱構圖", "Symmetrical Composition", "对称构图", "対称構図", "대칭 구도", "องค์ประกอบสมมาตร"), "central axis · mirrored masses", "—", "1 : 1 frame"),
    ("negative_space", T("留白構圖", "Negative Space", "留白构图", "余白構図", "여백 구도", "พื้นที่ว่าง"), "subject ≤ 15 % of area", "—", "3 : 2 frame"),
    ("s_curve", T("S 形曲線構圖", "S-Curve Composition", "S 形曲线构图", "S字曲線構図", "S자 곡선 구도", "องค์ประกอบเส้นโค้งรูปตัว S"), "leading S · soft tension", "—", "4 : 5 frame"),
]
FAMILIES.pop()  # 移除上面的占位
for p, t, s, mt, d in COMP:
    single(C, PHYS, f"comp:{p}", t, s, mt, d)
single(C, AI, "ai_generative_layout", T("生成式版面", "Generative Layout", "生成式版面", "生成型レイアウト", "생성형 레이아웃", "เลย์เอาต์เชิงสร้างสรรค์"), "constraint solver · 12-col · rhythm 8 pt", "ML + rules", "any frame")
single(C, AI, "ai_balance_heatmap", T("視覺重量熱度圖", "Visual-Weight Heatmap", "视觉重量热度图", "視覚的重みヒートマップ", "시각 무게 히트맵", "แผนภาพความหนักทางสายตา"), "saliency · centroid offset", "ML", "any frame")

# ═══ 字體排印與版面網格 ═════════════════════════════════════════════
Y = "Typography"
TYPO = [
    ("baseline_grid", T("基線網格", "Baseline Grid", "基线网格", "ベースライングリッド", "기준선 그리드", "กริดเส้นฐาน"), "line 18 pt · 4 pt sub-grid", "—", "A4"),
    ("grid_12col", T("12 欄網格", "12-Column Grid", "12 栏网格", "12カラムグリッド", "12열 그리드", "กริด 12 คอลัมน์"), "gutter 16 · margin 24", "—", "1440 px"),
    ("margins_vdg", T("范德格拉夫版心", "Van de Graaf Canon", "范德格拉夫版心", "ヴァン・デ・グラーフの図", "반 더 흐라프 캐논", "สัดส่วนแวนเดอแกรฟ"), "text block 2/9 : 1/9 margins", "—", "2 : 3 page"),
    ("measure", T("行寬（每行字數）", "Line Measure", "行宽（每行字数）", "行長", "행 길이", "ความยาวบรรทัด"), "45–75 characters · 66 ideal", "—", "text column"),
    ("hierarchy", T("字級階層", "Type Hierarchy", "字级层次", "文字の階層", "서체 위계", "ลำดับชั้นตัวอักษร"), "H1 32 · H2 24 · body 16", "—", "scale 1.25"),
    ("drop_cap", T("首字下沉", "Drop Cap", "首字下沉", "ドロップキャップ", "드롭 캡", "อักษรตัวแรกขนาดใหญ่"), "3 lines deep · baseline aligned", "—", "column"),
    ("kerning_pairs", T("字距微調", "Kerning Pairs", "字距微调", "カーニング", "커닝", "การปรับระยะห่างตัวอักษร"), "AV · To · Ty · 1/1000 em", "—", "display size"),
    ("serif_anatomy", T("襯線字形解剖", "Serif Anatomy", "衬线字形解剖", "セリフ体の構造", "세리프 구조", "โครงสร้างตัวอักษรมีเชิง"), "baseline · x-height · cap height", "—", "1000 UPM"),
    ("leading_scale", T("行距比較", "Leading Comparison", "行距比较", "行間の比較", "행간 비교", "เปรียบเทียบระยะบรรทัด"), "1.2 · 1.5 · 1.8", "—", "body 16"),
    ("ligatures", T("連字", "Ligatures", "连字", "リガチャ", "합자", "ลิเกเจอร์"), "fi · fl · ff · discretionary", "—", "text size"),
]
for p, t, s, mt, d in TYPO:
    single(Y, PHYS, f"typo:{p}", t, s, mt, d)
single(Y, AI, "ai_variable_font", T("可變字型軸向", "Variable-Font Axes", "可变字体轴向", "可変フォントの軸", "가변 글꼴 축", "แกนฟอนต์แปรผัน"), "wght 100–900 · wdth 75–125 · opsz", "OpenType 1.8", "1 file")
single(Y, AI, "ai_type_pairing", T("智慧字體配對", "Smart Type Pairing", "智能字体配对", "スマートな書体ペアリング", "스마트 서체 페어링", "การจับคู่ฟอนต์อัจฉริยะ"), "serif ↔ sans · contrast score", "ML", "2 families")

# ═══ 造型語彙與工藝紋樣 ═════════════════════════════════════════════
MO = "DesignMotifs"
MOTIFS = [
    ("seigaiha", T("青海波", "Seigaiha (Wave)", "青海波", "青海波", "청해파", "ลายคลื่นเซไกฮะ"), "concentric arcs · offset rows", "—", "tile 56 × 32"),
    ("asanoha", T("麻葉紋", "Asanoha (Hemp Leaf)", "麻叶纹", "麻の葉", "마엽 문양", "ลายใบกัญชง"), "hexagonal star lattice", "—", "tile 60 × 60"),
    ("kikko", T("龜甲紋", "Kikko (Tortoiseshell)", "龟甲纹", "亀甲", "귀갑 문양", "ลายกระดองเต่า"), "regular hexagon grid", "—", "tile 52 × 45"),
    ("meander", T("回紋（雷紋）", "Greek Key (Meander)", "回纹（雷纹）", "雷文", "뇌문", "ลายกุญแจกรีก"), "continuous right-angle spiral", "—", "tile 50 × 50"),
    ("quatrefoil", T("四葉紋", "Quatrefoil", "四叶纹", "四つ葉紋", "사엽 문양", "ลายสี่แฉก"), "4 overlapping circles", "—", "Ø108"),
    ("herringbone", T("人字紋", "Herringbone", "人字纹", "ヘリンボーン", "헤링본", "ลายก้างปลา"), "45° staggered bricks", "—", "tile 40 × 36"),
    ("chevron", T("山形紋", "Chevron", "山形纹", "シェブロン", "셰브런", "ลายเชฟรอน"), "V-stripes · 34 pt pitch", "—", "tile 240 × 34"),
    ("trellis", T("菱格紋", "Trellis", "菱格纹", "格子（トレリス）", "격자 문양", "ลายตาข่ายไม้ระแนง"), "diagonal lattice · 36 pt", "—", "tile 72 × 72"),
    ("mandala", T("曼陀羅", "Mandala", "曼陀罗", "曼荼羅", "만다라", "มันดาลา"), "12-fold radial symmetry", "—", "Ø200"),
    ("star", T("八角星（伊斯蘭幾何）", "Eight-Point Star (Islamic Geometry)", "八角星（伊斯兰几何）", "八芒星（イスラム幾何学）", "팔각별(이슬람 기하)", "ดาวแปดแฉก (เรขาคณิตอิสลาม)"), "{8/3} star · 8-fold", "—", "Ø220"),
]
for p, t, s, mt, d in MOTIFS:
    single(MO, PHYS, f"motif:{p}", t, s, mt, d)
single(MO, AI, "ai_fractal_tile", T("碎形自相似拼貼", "Fractal Self-Similar Tiling", "分形自相似拼贴", "フラクタル自己相似タイリング", "프랙탈 자기유사 타일링", "การปูกระเบื้องแฟรกทัลคล้ายตัวเอง"), "Sierpiński · depth 3", "Procedural", "Ø240")

# ═══ 模具與注塑成型 ═════════════════════════════════════════════════
TM = "ToolingMolding"
MOLD = [
    ("cross_section", T("注塑模剖面", "Injection Mold Cross-Section", "注塑模剖面", "射出成形金型の断面", "사출 금형 단면", "ภาคตัดแม่พิมพ์ฉีด"), "2-plate · cavity + core", "P20 / H13", "300 × 300 mm"),
    ("gate_edge", T("側澆口", "Edge Gate", "侧浇口", "サイドゲート", "사이드 게이트", "เกทด้านข้าง"), "t 0.8 × w 3 mm", "P20", "—"),
    ("gate_pin", T("針點澆口", "Pin Gate", "针点浇口", "ピンゲート", "핀 게이트", "เกทแบบพิน"), "Ø0.8 mm · 3-plate", "H13", "—"),
    ("gate_sub", T("潛伏式澆口", "Submarine Gate", "潜伏式浇口", "サブマリンゲート", "서브마린 게이트", "เกทแบบเรือดำน้ำ"), "45° tunnel · auto-degate", "H13 · nitrided", "—"),
    ("cooling", T("冷卻水路配置", "Cooling Channel Layout", "冷却水路布置", "冷却水管レイアウト", "냉각 채널 배치", "การจัดวางช่องระบายความร้อน"), "Ø8 · 20 mm pitch · 15 mm to cavity", "Cu-Be insert", "—"),
    ("ejector", T("頂針配置", "Ejector Pin Layout", "顶针布置", "エジェクターピン配置", "이젝터 핀 배치", "การจัดวางพินดีด"), "Ø3 · stroke 12 mm", "SKD61 · nitrided", "—"),
    ("parting_line", T("分模線", "Parting Line", "分模线", "パーティングライン", "파팅 라인", "เส้นแบ่งแม่พิมพ์"), "step 0.1 mm · shut-off 3°", "—", "—"),
    ("core_cavity", T("公母模", "Core and Cavity", "公母模", "コアとキャビティ", "코어와 캐비티", "คอร์และคาวิตี้"), "draft 1.5° · shrink 0.5 %", "NAK80", "—"),
    ("slider_lifter", T("滑塊與斜頂", "Slider and Lifter", "滑块与斜顶", "スライドとリフター", "슬라이더와 리프터", "สไลเดอร์และลิฟเตอร์"), "angle pin 15° · lock 3°", "SKD11", "—"),
    ("runner_cold", T("冷澆道系統", "Cold Runner System", "冷浇道系统", "コールドランナー", "콜드 러너", "ระบบรันเนอร์เย็น"), "sprue + balanced runner", "P20", "—"),
    ("runner_hot", T("熱澆道系統", "Hot Runner System", "热浇道系统", "ホットランナー", "핫 러너", "ระบบรันเนอร์ร้อน"), "manifold 250 °C · 3 drops", "H13 / heaters", "—"),
]
for p, t, s, mt, d in MOLD:
    single(TM, PHYS, f"mold:{p}", t, s, mt, d)
single(TM, AI, "ai_conformal_cooling", T("3D 列印隨形水路", "3D-Printed Conformal Cooling", "3D 打印随形水路", "3Dプリント追従冷却", "3D 프린팅 컨포멀 냉각", "ช่องระบายความร้อนตามรูปทรงแบบพิมพ์ 3 มิติ"), "cycle −30 % · uniform ΔT < 3 °C", "Maraging steel / SLM", "insert 80 × 80 mm")
single(TM, AI, "ai_adaptive_mold", T("可調式針陣模具", "Adaptive Pin-Array Mold", "可调式针阵模具", "可変ピンアレイ金型", "가변 핀 어레이 금형", "แม่พิมพ์พินอาร์เรย์ปรับได้"), "reconfigurable surface · 1 mm pitch", "Steel pins / servo", "300 × 300 mm")

# ═══ 鈑金與 CNC ═════════════════════════════════════════════════════
SM = "SheetMetalCNC"
SHEET = [
    ("v_bend", T("V 型折彎", "V-Bend", "V 型折弯", "V曲げ", "V 벤딩", "การพับรูปตัววี"), "90° · r = t · K 0.33", "SPCC / AL5052", "t 2 mm"),
    ("hem", T("摺邊", "Hem", "折边", "ヘミング", "헤밍", "การพับขอบ"), "closed hem · 2t return", "SPCC", "t 1.2 mm"),
    ("z_bend", T("Z 形折彎（偏置）", "Z-Bend (Offset)", "Z 形折弯（偏置）", "Z曲げ（オフセット）", "Z 벤딩(오프셋)", "การพับรูปตัวแซด"), "offset 3t · 2 bends", "SUS304", "t 1.5 mm"),
    ("flat_pattern", T("展開圖", "Flat Pattern", "展开图", "展開図", "전개도", "แบบคลี่"), "bend deduction · relief 2t", "SPCC", "t 1.5 mm"),
    ("louvre", T("百葉窗沖壓", "Louvre Forming", "百叶窗冲压", "ルーバー成形", "루버 성형", "การปั๊มช่องระบายอากาศ"), "pitch 28 · height 8", "AL5052", "t 1.0 mm"),
    ("punch_pattern", T("沖孔陣列", "Punched Hole Pattern", "冲孔阵列", "パンチ穴パターン", "타공 패턴", "แบบรูเจาะ"), "Ø8 · staggered 34 pitch", "SPCC", "t 1.2 mm"),
    ("tab_slot", T("卡榫與槽", "Tab and Slot", "卡榫与槽", "タブ＆スロット", "탭과 슬롯", "แท็บและร่อง"), "clearance 0.1 · self-locating", "SPCC", "t 1.5 mm"),
]
for p, t, s, mt, d in SHEET:
    single(SM, PHYS, f"sheet:{p}", t, s, mt, d)
CNC = [
    ("pocket", T("口袋銑削刀路", "Pocket Milling Path", "型腔铣削刀路", "ポケット加工パス", "포켓 밀링 경로", "เส้นทางกัดโพรง"), "stepover 40 % · climb", "AL6061", "Ø6 flat end mill"),
    ("contour", T("輪廓銑削刀路", "Contour Milling Path", "轮廓铣削刀路", "輪郭加工パス", "윤곽 밀링 경로", "เส้นทางกัดโครงร่าง"), "offset 3 mm · lead-in arc", "AL6061", "Ø6 flat end mill"),
    ("drill_pattern", T("鑽孔陣列", "Drill Pattern", "钻孔阵列", "穴あけパターン", "드릴 패턴", "แบบการเจาะรู"), "peck 2 mm · 3 × 4 grid", "SUS304", "Ø5 drill"),
    ("spiral", T("螺旋刀路", "Spiral Toolpath", "螺旋刀路", "スパイラルパス", "나선 경로", "เส้นทางเกลียว"), "constant engagement", "AL6061", "Ø8 ball end mill"),
    ("endmill", T("端銑刀", "End Mill", "立铣刀", "エンドミル", "엔드밀", "ดอกกัดปลาย"), "4 flutes · 30° helix", "Carbide · TiAlN", "Ø6 × 50 mm"),
    ("chamfer", T("倒角加工", "Chamfer Cut", "倒角加工", "面取り加工", "모따기 가공", "การตัดเฉียงขอบ"), "C1 · 45°", "AL6061", "chamfer mill Ø10"),
]
for p, t, s, mt, d in CNC:
    single(SM, PHYS, f"cnc:{p}", t, s, mt, d)
single(SM, AI, "ai_robotic_forming", T("機械臂漸進成形", "Robotic Incremental Forming", "机械臂渐进成形", "ロボット逐次成形", "로봇 점진 성형", "การขึ้นรูปแบบค่อยเป็นค่อยไปด้วยหุ่นยนต์"), "dieless · 6-axis · ±0.3 mm", "AL5052 / Ti", "800 × 800 mm")
single(SM, AI, "ai_adaptive_toolpath", T("自適應刀路最佳化", "Adaptive Toolpath Optimiser", "自适应刀路优化", "適応型ツールパス最適化", "적응형 공구 경로 최적화", "ตัวปรับเส้นทางมีดตัดอัตโนมัติ"), "load-controlled stepover · −35 % time", "CAM + ML", "any part")

# ═══ 表面處理與材料工藝 ═════════════════════════════════════════════
SF = "SurfaceFinishing"
FIN = [
    ("ra_chart", T("表面粗糙度曲線", "Surface Roughness Profile", "表面粗糙度曲线", "表面粗さ曲線", "표면 거칠기 곡선", "โปรไฟล์ความขรุขระผิว"), "Ra 0.8 µm · Rz 4", "ISO 4287", "cut-off 0.8 mm"),
    ("anodize_layers", T("陽極處理層", "Anodised Layer", "阳极处理层", "アルマイト層", "아노다이징 층", "ชั้นอะโนไดซ์"), "type II · 15 µm · sealed", "AL6061", "—"),
    ("powder_coat", T("粉體塗裝", "Powder Coating", "粉末涂装", "粉体塗装", "분체 도장", "การพ่นสีฝุ่น"), "60–80 µm · cure 180 °C / 15 min", "Polyester", "—"),
    ("plating_stack", T("電鍍層堆疊", "Plating Stack", "电镀层堆叠", "めっき層構成", "도금 층 구조", "ชั้นชุบหลายชั้น"), "Cu 10 · Ni 15 · Cr 0.3 µm", "Steel / ABS", "—"),
    ("knurl_diamond", T("菱形網紋", "Diamond Knurl", "菱形网纹", "あや目ローレット", "다이아몬드 널링", "ลายเกลียวข้าวหลามตัด"), "pitch 1.0 · 30° / 90°", "S45C", "—"),
    ("knurl_straight", T("直紋網紋", "Straight Knurl", "直纹网纹", "平目ローレット", "직선 널링", "ลายเกลียวตรง"), "pitch 0.8 · 90°", "SUS303", "—"),
    ("brushed", T("拉絲處理", "Brushed Finish", "拉丝处理", "ヘアライン仕上げ", "헤어라인 마감", "ผิวขัดเส้นผม"), "grit 240 · uni-directional", "SUS304", "—"),
    ("peened", T("珠擊（噴砂）紋理", "Bead-Blasted Texture", "喷珠纹理", "ビーズブラスト", "비드 블라스트", "ผิวพ่นเม็ดบีด"), "glass bead 120 µm · 0.4 MPa", "AL6061", "—"),
    ("laser_etch", T("雷射雕刻", "Laser Etching", "激光雕刻", "レーザー刻印", "레이저 에칭", "การสลักด้วยเลเซอร์"), "fibre 20 W · 50 µm spot", "SUS304", "—"),
    ("sandblast", T("噴砂處理", "Sandblasting", "喷砂处理", "サンドブラスト", "샌드블라스팅", "การพ่นทราย"), "Al₂O₃ #120 · 0.5 MPa", "Steel", "—"),
]
for p, t, s, mt, d in FIN:
    single(SF, PHYS, f"finish:{p}", t, s, mt, d)
single(SF, AI, "ai_self_healing_coat", T("自修復塗層", "Self-Healing Coating", "自修复涂层", "自己修復コーティング", "자가 치유 코팅", "สารเคลือบซ่อมแซมตัวเอง"), "microcapsules · heals 100 µm cracks", "Polyurethane", "—")
single(SF, AI, "ai_structural_color", T("結構色薄膜", "Structural-Colour Film", "结构色薄膜", "構造色フィルム", "구조색 필름", "ฟิล์มสีโครงสร้าง"), "multilayer interference · no pigment", "TiO₂ / SiO₂", "—")

# ═══ 機構傳動與流體管路 ═════════════════════════════════════════════
PP = "PneumaticsPiping"
PIPE = [
    ("elbow", T("90° 彎頭", "90° Elbow", "90° 弯头", "90°エルボ", "90° 엘보", "ข้องอ 90°"), "R = 1.5D · ASME B16.9", "SS316L", "DN50"),
    ("tee", T("三通", "Tee", "三通", "ティー", "티", "ข้อต่อสามทาง"), "equal tee · ASME B16.9", "SS316L", "DN50"),
    ("reducer", T("異徑接頭", "Concentric Reducer", "同心异径接头", "同心レデューサ", "동심 리듀서", "ข้อลดแบบศูนย์กลาง"), "DN80 → DN50", "SS316L", "L 127 mm"),
    ("flange", T("法蘭", "Flange", "法兰", "フランジ", "플랜지", "หน้าแปลน"), "PN16 · 8 × Ø18 · RF", "A105", "Ø165 × 20 mm"),
    ("union", T("活接頭", "Union", "活接头", "ユニオン", "유니온", "ข้อต่อยูเนียน"), "G1/2 · 3-piece", "Brass", "Ø45 × 70 mm"),
    ("gate_valve", T("閘閥", "Gate Valve", "闸阀", "ゲートバルブ", "게이트 밸브", "ประตูน้ำ"), "PN16 · rising stem", "CF8M", "DN50 · H 280 mm"),
    ("check_valve", T("逆止閥", "Check Valve", "止回阀", "チェックバルブ", "체크 밸브", "เช็ควาล์ว"), "swing · cracking 0.02 bar", "CF8M", "DN50"),
    ("ball_valve", T("球閥", "Ball Valve", "球阀", "ボールバルブ", "볼 밸브", "บอลวาล์ว"), "full bore · 90° turn", "SS316", "DN25"),
]
for p, t, s, mt, d in PIPE:
    single(PP, PHYS, f"pipe:{p}", t, s, mt, d)
PNEU = [
    ("cyl_single", T("單動氣壓缸", "Single-Acting Cylinder", "单动气缸", "単動シリンダ", "단동 실린더", "กระบอกลมทำงานทางเดียว"), "bore 32 · stroke 50 · spring return", "Al / NBR", "Ø32 × 130 mm"),
    ("cyl_double", T("雙動氣壓缸", "Double-Acting Cylinder", "双动气缸", "複動シリンダ", "복동 실린더", "กระบอกลมทำงานสองทาง"), "bore 40 · stroke 100 · 0.6 MPa", "Al / NBR", "Ø40 × 220 mm"),
    ("valve_32", T("3/2 方向閥", "3/2 Directional Valve", "3/2 方向阀", "3/2方向弁", "3/2 방향 밸브", "วาล์วทิศทาง 3/2"), "solenoid · spring · NC", "Al / NBR", "G1/4"),
    ("valve_52", T("5/2 方向閥", "5/2 Directional Valve", "5/2 方向阀", "5/2方向弁", "5/2 방향 밸브", "วาล์วทิศทาง 5/2"), "double solenoid · 24 VDC", "Al / NBR", "G1/4"),
    ("frl_unit", T("氣源處理組合", "FRL Air-Prep Unit", "气源处理组合", "エアFRLユニット", "FRL 공기 조절 유닛", "ชุดปรับสภาพลม FRL"), "5 µm · 0–0.8 MPa · lubricator", "Al / PC bowl", "G1/2"),
    ("compressor", T("空氣壓縮機", "Air Compressor", "空气压缩机", "エアコンプレッサ", "공기 압축기", "ปั๊มลม"), "2.2 kW · 0.8 MPa · 8 bar tank", "Cast iron", "L 900 × H 800 mm"),
    ("gripper", T("氣動夾爪", "Pneumatic Gripper", "气动夹爪", "エアグリッパ", "공압 그리퍼", "มือจับลม"), "parallel · stroke 10 · 70 N", "Al / SUS", "40 × 30 × 20 mm"),
]
for p, t, s, mt, d in PNEU:
    single(PP, PHYS, f"pneu:{p}", t, s, mt, d)
single(PP, AI, "ai_soft_actuator", T("軟體氣動致動器", "Soft Pneumatic Actuator", "软体气动致动器", "ソフト空気圧アクチュエータ", "소프트 공압 액추에이터", "แอคทูเอเตอร์ลมแบบนิ่ม"), "chambered silicone · bend 180° @ 40 kPa", "Ecoflex 00-30", "L 120 × 20 mm")
single(PP, AI, "ai_microfluidic", T("微流道晶片", "Microfluidic Chip", "微流道芯片", "マイクロ流体チップ", "미세유체 칩", "ชิปไมโครฟลูอิดิก"), "channel 100 µm · 2 in / 1 out", "PDMS / glass", "30 × 20 mm")

# ═══ 跨平台系統標準件 ═══════════════════════════════════════════════
UI = "CrossPlatformUI"
UIS = [
    ("button_ios", T("iOS 按鈕", "iOS Buttons", "iOS 按钮", "iOSのボタン", "iOS 버튼", "ปุ่ม iOS"), "min 44 × 44 pt · capsule / r 12", "HIG", "—"),
    ("button_material", T("Material 按鈕", "Material Buttons", "Material 按钮", "Materialのボタン", "Material 버튼", "ปุ่ม Material"), "40 dp · r 8 · FAB 56", "Material 3", "—"),
    ("toggle", T("開關與滑桿", "Toggle and Slider", "开关与滑杆", "トグルとスライダー", "토글과 슬라이더", "สวิตช์และสไลเดอร์"), "51 × 31 pt · track 4 dp", "HIG / M3", "—"),
    ("nav_bar", T("導覽列", "Navigation Bar", "导览栏", "ナビゲーションバー", "내비게이션 바", "แถบนำทาง"), "44 pt · large title 96", "HIG", "—"),
    ("tab_bar", T("分頁列", "Tab Bar", "分页栏", "タブバー", "탭 바", "แถบแท็บ"), "49 pt · 3–5 items", "HIG / M3", "—"),
    ("dialog", T("對話框", "Dialog / Alert", "对话框", "ダイアログ", "대화상자", "กล่องโต้ตอบ"), "270 pt wide · r 14", "HIG / M3", "—"),
    ("list_row", T("清單列", "List Row", "列表行", "リスト行", "목록 행", "แถวรายการ"), "44–56 pt · inset separator", "HIG / M3", "—"),
    ("search_bar", T("搜尋列", "Search Bar", "搜索栏", "検索バー", "검색 바", "แถบค้นหา"), "36 pt · r 10 · cancel", "HIG / M3", "—"),
    ("segmented", T("分段控制", "Segmented Control", "分段控制", "セグメントコントロール", "세그먼트 컨트롤", "ตัวควบคุมแบบแบ่งส่วน"), "32 pt · 2–5 segments", "HIG", "—"),
    ("slider", T("滑桿", "Slider", "滑杆", "スライダー", "슬라이더", "สไลเดอร์"), "track 4 · thumb 28", "HIG / M3", "—"),
]
for p, t, s, mt, d in UIS:
    single(UI, PHYS, f"ui:{p}", t, s, mt, d)
single(UI, AI, "ai_adaptive_component", T("情境變形元件", "Context-Morphing Component", "情境变形组件", "文脈に応じて変形する部品", "상황 적응 변형 컴포넌트", "คอมโพเนนต์ปรับรูปตามบริบท"), "pill → card → sheet", "ML + layout", "—")
single(UI, AI, "ai_gesture_palette", T("手勢環狀調色盤", "Gestural Radial Palette", "手势环形调色盘", "ジェスチャーラジアルパレット", "제스처 방사형 팔레트", "จานสีแบบวงกลมด้วยท่าทาง"), "press-hold · 6 slices", "ML", "Ø220")

# ═══ 互動手勢與動效軌跡 ═════════════════════════════════════════════
UX = "UxMotion"
GEST = [
    ("tap", T("輕點", "Tap", "轻点", "タップ", "탭", "แตะ"), "touch ≤ 300 ms · slop 10 pt", "—", "—"),
    ("double_tap", T("連點兩下", "Double Tap", "连点两下", "ダブルタップ", "더블 탭", "แตะสองครั้ง"), "2 taps ≤ 300 ms", "—", "—"),
    ("long_press", T("長按", "Long Press", "长按", "長押し", "길게 누르기", "กดค้าง"), "≥ 500 ms", "—", "—"),
    ("swipe", T("滑動", "Swipe", "滑动", "スワイプ", "스와이프", "ปัด"), "velocity ≥ 300 pt/s", "—", "—"),
    ("pinch", T("捏合縮放", "Pinch", "捏合缩放", "ピンチ", "핀치", "ถ่างนิ้ว"), "2 touches · scale ratio", "—", "—"),
    ("rotate", T("雙指旋轉", "Rotate", "双指旋转", "回転", "회전", "หมุนสองนิ้ว"), "2 touches · angle Δ", "—", "—"),
    ("drag", T("拖曳", "Drag", "拖曳", "ドラッグ", "드래그", "ลาก"), "slop 10 pt · hit-test lift", "—", "—"),
    ("scroll", T("捲動", "Scroll", "滚动", "スクロール", "스크롤", "เลื่อน"), "inertia · rubber-band", "—", "—"),
]
for p, t, s, mt, d in GEST:
    single(UX, PHYS, f"gesture:{p}", t, s, mt, d)
EASE = [
    ("ease_in", T("緩入曲線", "Ease-In Curve", "缓入曲线", "イーズイン", "이즈 인", "เส้นโค้ง Ease-In"), "cubic-bezier(0.42, 0, 1, 1)", "—", "—"),
    ("ease_out", T("緩出曲線", "Ease-Out Curve", "缓出曲线", "イーズアウト", "이즈 아웃", "เส้นโค้ง Ease-Out"), "cubic-bezier(0, 0, 0.58, 1)", "—", "—"),
    ("ease_in_out", T("緩入緩出曲線", "Ease-In-Out Curve", "缓入缓出曲线", "イーズインアウト", "이즈 인아웃", "เส้นโค้ง Ease-In-Out"), "cubic-bezier(0.42, 0, 0.58, 1)", "—", "—"),
    ("linear", T("線性曲線", "Linear Curve", "线性曲线", "リニア", "리니어", "เส้นโค้งเชิงเส้น"), "cubic-bezier(0, 0, 1, 1)", "—", "—"),
    ("bounce", T("彈跳曲線", "Bounce Curve", "弹跳曲线", "バウンス", "바운스", "เส้นโค้งกระดอน"), "3 rebounds · decay 0.5", "—", "—"),
    ("overshoot", T("過衝曲線", "Overshoot Curve", "过冲曲线", "オーバーシュート", "오버슈트", "เส้นโค้งเกินเป้า"), "back ease · 1.7 tension", "—", "—"),
]
for p, t, s, mt, d in EASE:
    single(UX, PHYS, f"ease:{p}", t, s, mt, d)
single(UX, AI, "ai_predictive_motion", T("預測式動效", "Predictive Motion", "预测式动效", "予測型モーション", "예측형 모션", "แอนิเมชันเชิงคาดการณ์"), "trajectory extrapolation · 80 ms ahead", "ML", "—")
single(UX, AI, "ai_haptic_map", T("觸覺回饋對應圖", "Haptic Feedback Map", "触觉反馈对应图", "触覚フィードバックマップ", "촉각 피드백 맵", "แผนที่การสั่นตอบสนอง"), "per-region waveform · 170 Hz LRA", "Core Haptics", "—")

# ═══ 資訊架構與服務流程 ═════════════════════════════════════════════
IA = "InfoArchitecture"
IAS = [
    ("user_flow", T("使用者流程圖", "User Flow", "用户流程图", "ユーザーフロー", "사용자 플로우", "ผังขั้นตอนผู้ใช้"), "start · screen · decision · end", "—", "—"),
    ("journey_map", T("使用者旅程地圖", "Journey Map", "用户旅程地图", "ジャーニーマップ", "사용자 여정 지도", "แผนที่การเดินทางของผู้ใช้"), "5 stages · emotion curve", "—", "—"),
    ("card_sort", T("卡片分類法", "Card Sorting", "卡片分类法", "カードソーティング", "카드 소팅", "การจัดกลุ่มการ์ด"), "open · 30 cards · 5 users", "—", "—"),
    ("funnel", T("轉換漏斗", "Conversion Funnel", "转化漏斗", "コンバージョンファネル", "전환 퍼널", "กรวยการแปลง"), "3 stages · drop-off", "—", "—"),
    ("pyramid", T("需求金字塔", "Needs Pyramid", "需求金字塔", "ニーズのピラミッド", "요구 피라미드", "พีระมิดความต้องการ"), "3 levels · foundation first", "—", "—"),
    ("venn", T("文氏圖", "Venn Diagram", "文氏图", "ベン図", "벤 다이어그램", "แผนภาพเวนน์"), "3 sets · overlap = sweet spot", "—", "—"),
    ("swimlane", T("泳道圖", "Swimlane Diagram", "泳道图", "スイムレーン図", "스윔레인 다이어그램", "แผนภาพสวิมเลน"), "3 actors · hand-offs", "—", "—"),
    ("kanban_flow", T("看板流程", "Kanban Flow", "看板流程", "かんばんフロー", "칸반 흐름", "กระบวนการคัมบัง"), "4 columns · WIP limit 3", "—", "—"),
    ("tree_nav", T("樹狀導覽結構", "Tree Navigation", "树状导览结构", "ツリーナビゲーション", "트리 내비게이션", "โครงสร้างการนำทางแบบต้นไม้"), "3 levels · max 7 items", "—", "—"),
    ("hub_spoke", T("輻輳式導覽", "Hub and Spoke", "辐辏式导览", "ハブ＆スポーク", "허브 앤 스포크", "โครงสร้างศูนย์กลางและซี่"), "central hub · 6 spokes", "—", "—"),
]
for p, t, s, mt, d in IAS:
    single(IA, PHYS, f"ia:{p}", t, s, mt, d)
single(IA, AI, "ai_intent_map", T("意圖地圖", "Intent Map", "意图地图", "インテントマップ", "의도 맵", "แผนที่เจตนา"), "LLM clustering · query → intent tree", "LLM", "—")
single(IA, AI, "ai_adaptive_ia", T("自適應導覽架構", "Adaptive Navigation", "自适应导览架构", "適応型ナビゲーション", "적응형 내비게이션", "โครงสร้างการนำทางแบบปรับตัว"), "re-ranked by usage", "ML", "—")

# ═══ 設計系統原子元件 ═══════════════════════════════════════════════
DT = "DesignTokens"
TOK = [
    ("color_scale", T("10 階色階", "10-Step Colour Scale", "10 阶色阶", "10段階カラースケール", "10단계 색상 스케일", "สเกลสี 10 ระดับ"), "50 … 900 · contrast AA", "—", "—"),
    ("type_scale", T("字級比例", "Type Scale", "字级比例", "タイプスケール", "타입 스케일", "สเกลตัวอักษร"), "ratio 1.25 · 14–44 pt", "—", "—"),
    ("radius_scale", T("圓角比例", "Radius Scale", "圆角比例", "角丸スケール", "라운드 스케일", "สเกลมุมโค้ง"), "0 · 6 · 12 · 20 · pill", "—", "—"),
    ("elevation", T("陰影層級", "Elevation Levels", "阴影层级", "エレベーション", "엘리베이션", "ระดับเงา"), "0–4 · blur 2/4/8/16", "—", "—"),
    ("breakpoints", T("響應式斷點", "Breakpoints", "响应式断点", "ブレークポイント", "브레이크포인트", "จุดตัดการตอบสนอง"), "600 · 840 · 1200", "—", "—"),
    ("icon_sizes", T("圖示尺寸", "Icon Sizes", "图标尺寸", "アイコンサイズ", "아이콘 크기", "ขนาดไอคอน"), "16 · 24 · 32 · 48 · 64", "—", "—"),
    ("opacity_ramp", T("透明度階", "Opacity Ramp", "透明度阶", "不透明度ランプ", "불투명도 단계", "ระดับความโปร่งใส"), "10 % steps", "—", "—"),
    ("stroke_weights", T("線寬規格", "Stroke Weights", "线宽规格", "線幅の規格", "선 굵기 규격", "ความหนาเส้น"), "1 · 2 · 4 · 6 · 10 pt", "—", "—"),
    ("motion_durations", T("動效時長", "Motion Durations", "动效时长", "モーション時間", "모션 지속 시간", "ระยะเวลาแอนิเมชัน"), "100 · 200 · 350 · 500 ms", "—", "—"),
    ("spacing_4pt", T("4 點間距階", "4-pt Spacing Scale", "4 点间距阶", "4ptスペーシング", "4pt 간격 스케일", "สเกลระยะห่าง 4 พอยต์"), "4 · 8 · 12 · 16 · 24 · 32 · 48", "—", "—"),
]
for p, t, s, mt, d in TOK:
    single(DT, PHYS, f"token:{p}", t, s, mt, d)
single(DT, AI, "ai_token_generator", T("設計變數產生器", "Design-Token Generator", "设计变量生成器", "デザイントークン生成器", "디자인 토큰 생성기", "ตัวสร้างดีไซน์โทเคน"), "1 seed colour → 10-step scale", "OKLCH", "—")
single(DT, AI, "ai_theme_morph", T("主題變形（亮／暗）", "Theme Morphing (Light / Dark)", "主题变形（亮／暗）", "テーマモーフィング（ライト／ダーク）", "테마 모핑(라이트/다크)", "การเปลี่ยนธีม (สว่าง/มืด)"), "token remap · contrast preserved", "ML", "—")

# 煞車碟盤的 {p} 需要語系詞
DISC_NAMES = {
    "vented": T("通風", "Vented", "通风", "ベンチレーテッド", "벤틸레이티드", "ระบายอากาศ"),
    "drilled": T("打孔", "Cross-Drilled", "打孔", "ドリルド", "드릴드", "เจาะรู"),
}
CAR_NAMES = {
    "sedan": T("轎車", "Sedan", "轿车", "セダン", "세단", "ซีดาน"),
    "suv": T("休旅車", "SUV", "SUV", "SUV", "SUV", "เอสยูวี"),
    "hatch": T("掀背車", "Hatchback", "掀背车", "ハッチバック", "해치백", "แฮทช์แบ็ก"),
}
OTHER_NAMES = {  # 家族內款式的語系詞（{p} 在標題裡）
    "chair": {"dining": T("餐椅", "Dining", "餐椅", "ダイニング", "식탁 의자", "เก้าอี้ทานข้าว"), "stool": T("吧檯凳", "Stool", "吧台凳", "スツール", "스툴", "สตูล"), "office": T("辦公椅", "Office", "办公椅", "オフィス", "사무용", "เก้าอี้สำนักงาน")},
    "table": {"dining": T("餐桌", "Dining", "餐桌", "ダイニング", "식탁", "โต๊ะอาหาร"), "coffee": T("茶几", "Coffee", "茶几", "コーヒー", "커피 테이블", "โต๊ะกาแฟ"), "desk": T("書桌", "Desk", "书桌", "デスク", "책상", "โต๊ะทำงาน")},
    "shelf": {"bookcase": T("書櫃", "Bookcase", "书柜", "本棚", "책장", "ตู้หนังสือ"), "wall": T("壁架", "Wall", "壁架", "ウォール", "벽 선반", "ชั้นติดผนัง")},
    "pcb": {"arduino": T("Arduino 型", "Arduino-Type", "Arduino 型", "Arduino型", "Arduino형", "แบบ Arduino"), "raspi": T("樹莓派型", "Raspberry-Pi-Type", "树莓派型", "ラズベリーパイ型", "라즈베리 파이형", "แบบราสเบอร์รีพาย"), "esp32": T("ESP32 型", "ESP32-Type", "ESP32 型", "ESP32型", "ESP32형", "แบบ ESP32")},
    "connector": {"usbc": T("USB-C", "USB-C", "USB-C", "USB-C", "USB-C", "USB-C"), "hdmi": T("HDMI", "HDMI", "HDMI", "HDMI", "HDMI", "HDMI"), "jack": T("3.5 mm 耳機孔", "3.5 mm Jack", "3.5 mm 耳机孔", "3.5mmジャック", "3.5mm 잭", "แจ็ค 3.5 มม."), "rj45": T("RJ45 網路", "RJ45 Ethernet", "RJ45 网络", "RJ45 イーサネット", "RJ45 이더넷", "อีเทอร์เน็ต RJ45")},
    "passive": {"smd": T("貼片電阻", "SMD Resistor", "贴片电阻", "チップ抵抗", "SMD 저항", "ตัวต้านทาน SMD"), "cap": T("電解電容", "Electrolytic Capacitor", "电解电容", "電解コンデンサ", "전해 커패시터", "ตัวเก็บประจุอิเล็กโทรไลต์"), "inductor": T("功率電感", "Power Inductor", "功率电感", "パワーインダクタ", "파워 인덕터", "ตัวเหนี่ยวนำกำลัง")},
    "device_frame": {"phone": T("手機", "Phone", "手机", "スマートフォン", "스마트폰", "โทรศัพท์"), "tablet": T("平板", "Tablet", "平板", "タブレット", "태블릿", "แท็บเล็ต"), "laptop": T("筆電", "Laptop", "笔记本", "ノートPC", "노트북", "แล็ปท็อป"), "monitor": T("桌機螢幕", "Monitor", "台式显示器", "モニター", "모니터", "จอคอมพิวเตอร์"), "watch": T("手錶", "Watch", "手表", "ウォッチ", "워치", "นาฬิกา")},
    "wire": {"landing": T("登陸頁", "Landing Page", "落地页", "ランディングページ", "랜딩 페이지", "หน้าแลนดิ้ง"), "dashboard": T("儀表板", "Dashboard", "仪表板", "ダッシュボード", "대시보드", "แดชบอร์ด"), "login": T("登入", "Login", "登录", "ログイン", "로그인", "เข้าสู่ระบบ"), "card_list": T("卡片清單", "Card List", "卡片列表", "カードリスト", "카드 목록", "รายการการ์ด"), "kanban": T("看板", "Kanban", "看板", "かんばん", "칸반", "คัมบัง"), "chat": T("聊天", "Chat", "聊天", "チャット", "채팅", "แชต")},
}


def title_for(code_base, param, titles):
    """把標題裡的 {p} 換成該款式的語系詞（沒有語系詞表的家族，{p} 就是參數字面值）。"""
    table = None
    if code_base == "brake_disc":
        table = DISC_NAMES
    elif code_base == "car_profile":
        table = CAR_NAMES
    elif code_base in OTHER_NAMES:
        table = OTHER_NAMES[code_base]
    out = {}
    for lang in LANGS:
        word = table[param][lang] if table and param in table else param
        out[lang] = titles[lang].replace("{p}", word)
    return out


def main():
    cat_path = ROOT / "i18n" / "ui-strings.json"
    catalog = json.loads(cat_path.read_text(encoding="utf-8"))
    # 現有素材 id 的計數（接續編號）
    existing = re.findall(r'\(\n\s+"([a-z0-9_]+)",\n\s+"[^"]*",\n\s+FfiAssetCategory::(\w+)',
                          (ROOT / "crates/padnote-core/src/ffi_assets.rs").read_text(encoding="utf-8"))
    prefixes = {"Mechanism": "mech", "Electronics3C": "elec", "Automotive": "auto", "Furniture": "furn", "Hardware": "hard",
                "Digital": "digi", "AestheticComposition": "aes_comp", "Typography": "typo", "DesignMotifs": "motif",
                "ToolingMolding": "mold", "SheetMetalCNC": "sheet", "SurfaceFinishing": "surf", "PneumaticsPiping": "pipe",
                "CrossPlatformUI": "ui", "UxMotion": "motion", "InfoArchitecture": "ia", "DesignTokens": "token"}
    counters = {c: sum(1 for _, cc in existing if cc == c) for c in prefixes}
    rows, codes, titles_out = [], [], {}
    for cat, src, code, titles, variants in FAMILIES:
        base = code.split(":")[0]
        for param, specs, material, dims in variants:
            full = f"{code}:{param}" if param else code
            counters[cat] += 1
            item_id = f"{prefixes[cat]}_{counters[cat]:02d}"
            t = title_for(base, param, titles)
            if code == base and ":" not in code and param == "" and "{p}" in titles["en"]:
                raise SystemExit(f"{code} 的標題有 {{p}} 卻沒有參數")
            size = round(1.2 + (len(specs) % 30) / 10.0, 1)
            rows.append((item_id, t["zhHant"], cat, src, specs, material, dims, size, full))
            codes.append(full)
            titles_out[f"asset_{item_id}_title"] = t
    # 驗證：規格三欄語言中性
    cjk = re.compile(r"[㐀-䶿一-鿿豈-﫿぀-ヿ가-힯]")
    for r in rows:
        for v in r[4:7]:
            if cjk.search(v):
                raise SystemExit(f"{r[0]} 規格含非英文字元：{v}")
    out = ["// 由 scripts/gen_asset_catalog.py 產生，請勿手改（改那支腳本再重新產生）。",
           "",
           "/// 擴充素材的線圖代號。測試用它確認每一個代號都有對應的繪圖分支。",
           "pub(crate) static MORE_CODES: &[&str] = &["]
    out += [f'    "{c}",' for c in codes]
    out += ["];", "", "/// 擴充素材目錄列（欄位同 `RAW`）。", "static MORE: &[Row] = &["]
    for r in rows:
        esc = lambda s: s.replace("\\", "\\\\").replace('"', '\\"')
        out.append("    (")
        out.append(f'        "{r[0]}",')
        out.append(f'        "{esc(r[1])}",')
        out.append(f"        FfiAssetCategory::{r[2]},")
        out.append(f"        FfiAssetSource::{r[3]},")
        out.append(f'        "{esc(r[4])}",')
        out.append(f'        "{esc(r[5])}",')
        out.append(f'        "{esc(r[6])}",')
        out.append(f"        {r[7]:.1f},")
        out.append(f'        "{esc(r[8])}",')
        out.append("    ),")
    out.append("];")
    (ROOT / "crates/padnote-core/src/asset_catalog_more.rs").write_text("\n".join(out) + "\n", encoding="utf-8")
    # 先清掉這個產生器上一次寫進去的鍵（id 在 existing 之後的），再寫入
    for k in list(catalog):
        if re.fullmatch(r"asset_[a-z_]+_\d+_title", k):
            num = int(k.rsplit("_", 2)[1])
            prefix = k[len("asset_"):k.rindex("_", 0, k.rindex("_"))]
            base_count = {prefixes[c]: counters_base for c, counters_base in
                          ((c, sum(1 for _, cc in existing if cc == c)) for c in prefixes)}
            if prefix in base_count and num > base_count[prefix]:
                del catalog[k]
    for k, v in titles_out.items():
        catalog[k] = v
    cat_path.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"產生 {len(rows)} 件素材、{len(titles_out)} 組名稱")


if __name__ == "__main__":
    main()
