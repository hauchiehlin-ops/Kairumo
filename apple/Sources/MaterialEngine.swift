//
//  MaterialEngine.swift
//  Kairumo
//
//  外觀材料屬性著色與渲染引擎
//  支援 3D 模型 SceneKit PBR 物理反射著色與 2D 圖片/物件材質濾鏡外觀
//

import SwiftUI
import SceneKit

public class MaterialEngine {

    /// 為 SceneKit 幾何體套用指定的 PBR 物理反射材質特性
    public static func applyMaterial(to geometry: SCNGeometry, materialType: MaterialType) {
        let material = createSCNMaterial(materialType: materialType)
        geometry.materials = [material]
    }

    /// 根據 MaterialType 建立對應的 SceneKit PBR 物理材質
    public static func createSCNMaterial(materialType: MaterialType) -> SCNMaterial {
        let mat = SCNMaterial()
        mat.lightingModel = .physicallyBased

        #if os(macOS)
        typealias PlatformColor = NSColor
        #else
        typealias PlatformColor = UIColor
        #endif

        switch materialType {
        case .plastic:
            mat.diffuse.contents = PlatformColor(red: 0.22, green: 0.55, blue: 0.95, alpha: 1.0)
            mat.metalness.contents = 0.05
            mat.roughness.contents = 0.18

        case .gold:
            mat.diffuse.contents = PlatformColor(red: 1.00, green: 0.84, blue: 0.12, alpha: 1.0)
            mat.metalness.contents = 1.0
            mat.roughness.contents = 0.16

        case .silver:
            mat.diffuse.contents = PlatformColor(white: 0.94, alpha: 1.0)
            mat.metalness.contents = 0.98
            mat.roughness.contents = 0.12

        case .copper:
            mat.diffuse.contents = PlatformColor(red: 0.88, green: 0.52, blue: 0.35, alpha: 1.0)
            mat.metalness.contents = 0.92
            mat.roughness.contents = 0.22

        case .iron:
            mat.diffuse.contents = PlatformColor(white: 0.42, alpha: 1.0)
            mat.metalness.contents = 0.85
            mat.roughness.contents = 0.50

        case .wood:
            mat.diffuse.contents = PlatformColor(red: 0.56, green: 0.36, blue: 0.20, alpha: 1.0)
            mat.metalness.contents = 0.0
            mat.roughness.contents = 0.78

        case .marble:
            mat.diffuse.contents = PlatformColor(white: 0.96, alpha: 1.0)
            mat.metalness.contents = 0.04
            mat.roughness.contents = 0.16

        case .granite:
            mat.diffuse.contents = PlatformColor(white: 0.55, alpha: 1.0)
            mat.metalness.contents = 0.02
            mat.roughness.contents = 0.84

        case .obsidian:
            mat.diffuse.contents = PlatformColor(white: 0.12, alpha: 1.0)
            mat.metalness.contents = 0.18
            mat.roughness.contents = 0.06
        }

        return mat
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
