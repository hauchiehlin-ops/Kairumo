//
//  MaterialEngine.swift
//  Kairumo
//
//  外觀材料屬性著色與渲染引擎
//  支援 3D 模型 SceneKit PBR 物理反射著色與 2D 圖片/物件材質濾鏡外觀
//

import SwiftUI
import UIKit
import SceneKit

public class MaterialEngine {

    /// 為 SceneKit 幾何體套用指定的 PBR 物理反射材質特性
    public static func applyMaterial(to geometry: SCNGeometry, materialType: MaterialType) {
        let material = createSCNMaterial(materialType: materialType)
        geometry.materials = [material]
    }

    /// 根據 MaterialType 建立對應的 SceneKit PBR 物理材質。
    ///
    /// **顏色與粗糙度來自核心** `model3dMaterialLook()`。原本這裡是一份寫死的
    /// switch，Android 沒有對應品；下沉之後同一個「黃金」在兩台裝置上是同一個
    /// 金色 —— 材質是會落盤、會同步的資料，兩邊不一致等於同一份筆記長得不一樣。
    public static func createSCNMaterial(materialType: MaterialType) -> SCNMaterial {
        let mat = SCNMaterial()
        mat.lightingModel = .physicallyBased

        // Mac 版走 Mac Catalyst，所以三個平台都是 UIKit —— 不需要 NSColor 分支。
        let look = model3dMaterialLook(material: ffiMaterial(materialType))
        mat.diffuse.contents = UIColor(hexString: look.hex) ?? UIColor.gray
        mat.metalness.contents = CGFloat(look.metalness)
        mat.roughness.contents = CGFloat(look.roughness)

        return mat
    }

    /// `MaterialType` → 核心的列舉。
    ///
    /// 用 rawValue 對照而不是逐一硬寫：rawValue 就是落盤字串，核心那邊也記著
    /// 同一份，對不上才是真的有問題，不該被一個 `default:` 靜靜吞掉。
    /// 材質的基本色（`#RRGGBB`）。給不走 SceneKit 的那條路用
    /// （匯入的模型是自己填多邊形的，沒有 SCNMaterial 可以掛）。
    static func hex(for type: MaterialType) -> String {
        model3dMaterialLook(material: ffiMaterial(type)).hex
    }

    private static func ffiMaterial(_ type: MaterialType) -> FfiMaterial {
        for candidate in model3dMaterials() where model3dMaterialLook(material: candidate).raw == type.rawValue {
            return candidate
        }
        return .gold
    }
}

/// 2D 物件/圖片材質特性 SwiftUI ViewModifier
public struct ObjectMaterialModifier: ViewModifier {
    public var material: MaterialType?

    public init(material: MaterialType?) {
        self.material = material
    }

    public func body(content: Content) -> some View {
        if let material = material {
            applyMaterialEffect(to: content, material: material)
        } else {
            content
        }
    }

    @ViewBuilder
    private func applyMaterialEffect(to content: Content, material: MaterialType) -> some View {
        switch material {
        case .plastic:
            content
                .saturation(1.25)
                .contrast(1.1)
                .overlay(
                    LinearGradient(
                        colors: [Color.white.opacity(0.18), Color.clear, Color.white.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .allowsHitTesting(false)
                )

        case .gold:
            content
                .colorMultiply(Color(red: 1.0, green: 0.90, blue: 0.65))
                .contrast(1.18)
                .saturation(1.3)
                .overlay(
                    LinearGradient(
                        colors: [Color.yellow.opacity(0.25), Color.clear, Color.orange.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .allowsHitTesting(false)
                )

        case .silver:
            content
                .grayscale(0.95)
                .contrast(1.25)
                .brightness(0.08)
                .overlay(
                    LinearGradient(
                        colors: [Color.white.opacity(0.3), Color.clear, Color.white.opacity(0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .allowsHitTesting(false)
                )

        case .copper:
            content
                .colorMultiply(Color(red: 0.95, green: 0.72, blue: 0.55))
                .contrast(1.15)
                .saturation(1.2)
                .overlay(
                    LinearGradient(
                        colors: [Color.orange.opacity(0.2), Color.clear, Color.red.opacity(0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .allowsHitTesting(false)
                )

        case .iron:
            content
                .grayscale(0.85)
                .contrast(1.3)
                .brightness(-0.06)
                .overlay(
                    LinearGradient(
                        colors: [Color.black.opacity(0.12), Color.clear, Color.white.opacity(0.1)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .allowsHitTesting(false)
                )

        case .wood:
            content
                .colorMultiply(Color(red: 0.85, green: 0.68, blue: 0.50))
                .contrast(1.12)
                .saturation(0.9)
                .overlay(
                    LinearGradient(
                        colors: [Color.brown.opacity(0.18), Color.clear, Color.brown.opacity(0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .allowsHitTesting(false)
                )

        case .marble:
            content
                .brightness(0.06)
                .contrast(1.1)
                .saturation(0.7)
                .overlay(
                    LinearGradient(
                        colors: [Color.white.opacity(0.22), Color.gray.opacity(0.06), Color.white.opacity(0.18)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .allowsHitTesting(false)
                )

        case .granite:
            content
                .grayscale(0.65)
                .contrast(1.35)
                .overlay(
                    LinearGradient(
                        colors: [Color.gray.opacity(0.15), Color.clear, Color.black.opacity(0.12)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .allowsHitTesting(false)
                )

        case .obsidian:
            content
                .brightness(-0.15)
                .contrast(1.4)
                .saturation(0.5)
                .overlay(
                    LinearGradient(
                        colors: [Color.white.opacity(0.22), Color.black.opacity(0.4), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .allowsHitTesting(false)
                )
        }
    }
}

public extension View {
    func objectMaterial(_ material: MaterialType?) -> some View {
        self.modifier(ObjectMaterialModifier(material: material))
    }
}
