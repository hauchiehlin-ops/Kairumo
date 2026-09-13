//
//  ObjectFrameStyleMenu.swift
//  Kairumo
//
//  插入物件的外框與底色控制項（四種物件共用）。
//
//  # 為什麼共用一份
//
//  文字方塊、圖片、3D 模型、網址預覽在畫布上都是「一個有邊框與底色的方框」。
//  各寫一份控制項的結果是：改了文字方塊的，圖片的還是寫死的 —— 而使用者的
//  期待是「所有插入的東西都能調」。共用同一組欄位、同一份解析規則、
//  同一個選單。
//
//  # 為什麼用預設色而不是 ColorPicker
//
//  ColorPicker 需要額外的狀態與彈窗，在畫布上的小物件旁邊很難用。這裡給一組
//  夠用的預設色加上「透明」與「無邊框」，兩下就調完。需要精確色彩的場合
//  （文字方塊）另有完整的樣式面板。
//

import SwiftUI

struct ObjectFrameStyleMenu<Style: ObjectFrameStyled>: View {
    @Binding var style: Style
    @ObservedObject var localizationManager = LocalizationManager.shared
    /// 改完之後要落盤／廣播給協同對象。
    var onChange: () -> Void = {}

    /// 一組夠用的顏色。刻意不多 —— 選項太多的選單比沒有選單還難用。
    static var palette: [(key: String, hex: String)] {
        [
            ("color_white", "#FFFFFF"),
            ("color_yellow", "#FFF9C4"),
            ("color_blue", "#E3F2FD"),
            ("color_green", "#E8F5E9"),
            ("color_pink", "#FCE4EC"),
            ("color_gray", "#EEEEEE"),
            ("color_black", "#212121")
        ]
    }

    var body: some View {
        Menu(localizationManager.localized("object_frame_style")) {
            Toggle(isOn: Binding(
                get: { style.hasBorder },
                set: { style.hasBorder = $0; onChange() }
            )) {
                Label(localizationManager.localized("object_show_border"), systemImage: "square")
            }

            Menu(localizationManager.localized("object_border_color")) {
                ForEach(Self.palette, id: \.hex) { entry in
                    Button(localizationManager.localized(entry.key)) {
                        style.borderColorHex = entry.hex
                        style.hasBorder = true      // 挑了顏色卻沒有邊框，選單就白按了
                        onChange()
                    }
                }
                Divider()
                Button(localizationManager.localized("object_use_default")) {
                    style.borderColorHex = nil
                    onChange()
                }
            }

            Menu(localizationManager.localized("object_border_width")) {
                ForEach([1.0, 1.5, 2.5, 4.0], id: \.self) { width in
                    Button("\(Int(width * 10) / 10) pt") {
                        style.borderWidth = CGFloat(width)
                        style.hasBorder = true
                        onChange()
                    }
                }
            }

            Divider()

            Menu(localizationManager.localized("object_background_color")) {
                // 透明放在最前面：那是使用者最常想要、而原本完全做不到的一項。
                Button(localizationManager.localized("color_transparent")) {
                    style.backgroundColorHex = "clear"
                    onChange()
                }
                Divider()
                ForEach(Self.palette, id: \.hex) { entry in
                    Button(localizationManager.localized(entry.key)) {
                        style.backgroundColorHex = entry.hex
                        onChange()
                    }
                }
                Divider()
                Button(localizationManager.localized("object_use_default")) {
                    style.backgroundColorHex = nil
                    onChange()
                }
            }

            Menu(localizationManager.localized("object_corner_radius")) {
                ForEach([0.0, 4.0, 8.0, 12.0, 20.0], id: \.self) { radius in
                    Button(radius == 0
                           ? localizationManager.localized("object_corner_square")
                           : "\(Int(radius)) pt") {
                        style.cornerRadius = CGFloat(radius)
                        onChange()
                    }
                }
            }
        }
    }
}
