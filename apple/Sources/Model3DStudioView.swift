//
//  Model3DStudioView.swift
//  Kairumo
//
//  3D 模型插入面板與畫布互動展示卡片
//  支援球體、正方體、圓柱體、圓環、角錐、膠囊 6 種立體幾何
//  支援 9 大材質 PBR 即時反射著色、360° 手勢旋轉、縮放與自訂文字標題
//

import SwiftUI
import SceneKit

#if os(macOS) && !targetEnvironment(macCatalyst)
typealias SCNFloat = CGFloat
#else
typealias SCNFloat = Float
#endif

/// 3D 幾何模型型別定義
public enum Model3DType: String, CaseIterable, Identifiable {
    case sphere = "sphere"
    case cube = "cube"
    case cylinder = "cylinder"
    case torus = "torus"
    case pyramid = "pyramid"
    case capsule = "capsule"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .sphere: return "球體 (Sphere)"
        case .cube: return "立方體 (Cube)"
        case .cylinder: return "圓柱體 (Cylinder)"
        case .torus: return "甜甜圈環 (Torus)"
        case .pyramid: return "金字塔 (Pyramid)"
        case .capsule: return "膠囊 (Capsule)"
        }
    }

    public var iconName: String {
        switch self {
        case .sphere: return "circle.fill"
        case .cube: return "shippingbox.fill"
        case .cylinder: return "cylinder.fill"
        case .torus: return "circle.circle.fill"
        case .pyramid: return "pyramid.fill"
        case .capsule: return "capsule.fill"
        }
    }
}

/// 3D 輔助工具：建立 SceneKit 場景
public struct SceneKitHelper {
    public static func makeScene(
        modelTypeRaw: String,
        material: MaterialType,
        rotationX: Float,
        rotationY: Float,
        rotationZ: Float,
        scale: Float
    ) -> SCNScene {
        let scene = SCNScene()

        let geometry: SCNGeometry
        switch modelTypeRaw {
        case "cube":
            geometry = SCNBox(width: 1.4, height: 1.4, length: 1.4, chamferRadius: 0.08)
        case "sphere":
            geometry = SCNSphere(radius: 0.95)
        case "cylinder":
            geometry = SCNCylinder(radius: 0.75, height: 1.6)
        case "torus":
            geometry = SCNTorus(ringRadius: 0.85, pipeRadius: 0.32)
        case "pyramid":
            geometry = SCNPyramid(width: 1.5, height: 1.6, length: 1.5)
        case "capsule":
            geometry = SCNCapsule(capRadius: 0.55, height: 1.6)
        default:
            geometry = SCNSphere(radius: 0.95)
        }

        MaterialEngine.applyMaterial(to: geometry, materialType: material)

        let node = SCNNode(geometry: geometry)
        node.name = "targetModelNode"
        node.eulerAngles = SCNVector3(SCNFloat(rotationX), SCNFloat(rotationY), SCNFloat(rotationZ))
        node.scale = SCNVector3(SCNFloat(scale), SCNFloat(scale), SCNFloat(scale))
        scene.rootNode.addChildNode(node)

        // 主平行方向光（模擬太陽照射帶來立體高光）
        let dirLight = SCNLight()
        dirLight.type = .directional
        dirLight.intensity = 1100
        let dirNode = SCNNode()
        dirNode.light = dirLight
        dirNode.eulerAngles = SCNVector3(SCNFloat(-0.6), SCNFloat(0.7), SCNFloat(0))
        scene.rootNode.addChildNode(dirNode)

        // 環境光（提亮暗部）
        let ambLight = SCNLight()
        ambLight.type = .ambient
        ambLight.intensity = 400
        let ambNode = SCNNode()
        ambNode.light = ambLight
        scene.rootNode.addChildNode(ambNode)

        // 攝影機
        let camera = SCNCamera()
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(SCNFloat(0), SCNFloat(0), SCNFloat(3.8))
        scene.rootNode.addChildNode(cameraNode)

        return scene
    }
}

/// 3D 模型插入配置彈出視窗
public struct Model3DStudioView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var localizationManager = LocalizationManager.shared

    var onInsert: (Note3DAttachment) -> Void

    @State private var selectedModelType: Model3DType = .sphere
    @State private var selectedMaterial: MaterialType = .gold
    @State private var title: String = "3D 幾何模型"
    @State private var previewRotationY: Float = 0.5
    @State private var previewRotationX: Float = 0.3

    public init(onInsert: @escaping (Note3DAttachment) -> Void) {
        self.onInsert = onInsert
    }

    public var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                // 左側：3D 即時動態預覽
                VStack(spacing: 12) {
                    Text(title.isEmpty ? "3D 預覽" : title)
                        .font(.headline)
                        .padding(.top, 16)

                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(UIColor.secondarySystemBackground))
                            .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)

                        SceneView(
                            scene: SceneKitHelper.makeScene(
                                modelTypeRaw: selectedModelType.rawValue,
                                material: selectedMaterial,
                                rotationX: previewRotationX,
                                rotationY: previewRotationY,
                                rotationZ: 0,
                                scale: 1.0
                            ),
                            options: [.allowsCameraControl, .autoenablesDefaultLighting]
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                        // 旋轉指示文字
                        VStack {
                            Spacer()
                            HStack {
                                Image(systemName: "hand.draw")
                                Text(localizationManager.localized("rotate_hint"))
                                    .font(.caption2)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(.ultraThinMaterial)
                            .cornerRadius(10)
                            .padding(.bottom, 12)
                        }
                    }
                    .frame(minWidth: 260, minHeight: 280)
                    .padding()
                }
                .frame(maxWidth: .infinity)

                Divider()

                // 右側：參數配置
                Form {
                    Section(header: Text(localizationManager.localized("model_title"))) {
                        TextField(localizationManager.localized("model_title"), text: $title)
                    }

                    Section(header: Text("幾何形狀")) {
                        Picker("幾何形狀", selection: $selectedModelType) {
                            ForEach(Model3DType.allCases) { type in
                                HStack {
                                    Image(systemName: type.iconName)
                                    Text(type.displayName)
                                }
                                .tag(type)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    Section(header: Text(localizationManager.localized("material_style"))) {
                        Picker(localizationManager.localized("material_style"), selection: $selectedMaterial) {
                            ForEach(MaterialType.allCases) { mat in
                                Text(localizationManager.localized(mat.localizationKey))
                                    .tag(mat)
                            }
                        }
                        .pickerStyle(.menu)

                        // 材質特性簡介
                        Text(materialDescription(selectedMaterial))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Section {
                        Button {
                            let newAttachment = Note3DAttachment(
                                id: UUID().uuidString,
                                pageIndex: 0,
                                title: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "3D 物件" : title,
                                modelTypeRaw: selectedModelType.rawValue,
                                materialType: selectedMaterial,
                                rotationX: previewRotationX,
                                rotationY: previewRotationY,
                                rotationZ: 0,
                                scale: 1.0,
                                x: 100,
                                y: 150,
                                width: 280,
                                height: 260
                            )
                            onInsert(newAttachment)
                            dismiss()
                        } label: {
                            HStack {
                                Spacer()
                                Image(systemName: "cube.transparent")
                                Text(localizationManager.localized("insert_3d"))
                                    .fontWeight(.bold)
                                Spacer()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .frame(width: 320)
            }
            .navigationTitle(localizationManager.localized("insert_3d"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizationManager.localized("cancel")) {
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 620, minHeight: 460)
    }

    private func materialDescription(_ mat: MaterialType) -> String {
        switch mat {
        case .plastic: return "經典平滑合成塑膠，色彩飽和明亮，微帶柔和高光。"
        case .gold: return "尊榮奢華黃金，具備 100% 高度金屬性與溫潤鏡面高光反射。"
        case .silver: return "冷冽純銀，超高反射度與亮白金屬光澤。"
        case .copper: return "溫潤紅銅，帶有暖紅金屬反光質感。"
        case .iron: return "工藝鋼鐵，深灰亞光金屬質感與堅固沉穩外觀。"
        case .wood: return "自然原木，零金屬度，呈現大地溫暖漫反射與粗糙度。"
        case .marble: return "典雅大理石，微透白皙，高拋光細膩石材反射。"
        case .granite: return "質樸花崗岩，粗糙顆粒感石材，漫反射自然陰影。"
        case .obsidian: return "深邃黑曜石，火山玻璃鏡面反射，深黑高對比亮澤。"
        }
    }
}

/// 畫布上的 3D 模型互動卡片
public struct Model3DInteractiveCardView: View {
    @Binding var attachment: Note3DAttachment
    var onDelete: () -> Void
    @ObservedObject var localizationManager = LocalizationManager.shared

    @State private var isDraggingRotation = false
    @State private var lastDragLocation: CGPoint = .zero
    @State private var isEditingTitle = false

    public init(attachment: Binding<Note3DAttachment>, onDelete: @escaping () -> Void) {
        self._attachment = attachment
        self.onDelete = onDelete
    }

    public var body: some View {
        VStack(spacing: 0) {
            cardHeader
            cardViewport
            cardFooter
        }
        .frame(width: max(180, attachment.width), height: max(180, attachment.height))
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.accentColor.opacity(0.4), lineWidth: 1.5)
        )
        .shadow(color: Color.black.opacity(0.16), radius: 8, x: 0, y: 4)
    }

    private var cardHeader: some View {
        HStack(spacing: 6) {
            Image(systemName: "cube.transparent.fill")
                .foregroundColor(.accentColor)
                .font(.caption)

            if isEditingTitle {
                TextField(localizationManager.localized("model_title"), text: $attachment.title)
                    .font(.caption.bold())
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { isEditingTitle = false }
            } else {
                Text(attachment.title)
                    .font(.caption.bold())
                    .lineLimit(1)
                    .onTapGesture { isEditingTitle = true }
            }

            Spacer()

            // 材質快速切換選單
            Menu {
                ForEach(MaterialType.allCases) { mat in
                    Button {
                        attachment.materialType = mat
                    } label: {
                        HStack {
                            Text(localizationManager.localized(mat.localizationKey))
                            if attachment.materialType == mat {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 2) {
                    Text(localizationManager.localized(attachment.materialType.localizationKey))
                        .font(.system(size: 10, weight: .semibold))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.accentColor.opacity(0.15))
                .cornerRadius(6)
            }

            // 刪除按鈕
            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color(UIColor.secondarySystemBackground))
    }

    private var cardViewport: some View {
        ZStack {
            SceneView(
                scene: SceneKitHelper.makeScene(
                    modelTypeRaw: attachment.modelTypeRaw,
                    material: attachment.materialType,
                    rotationX: attachment.rotationX,
                    rotationY: attachment.rotationY,
                    rotationZ: attachment.rotationZ,
                    scale: attachment.scale
                ),
                options: [.autoenablesDefaultLighting]
            )

            // 覆蓋手勢層：360° 拖曳旋轉
            Color.clear
                .contentShape(Rectangle())
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if !isDraggingRotation {
                                isDraggingRotation = true
                                lastDragLocation = value.location
                            } else {
                                let deltaX = Float(value.location.x - lastDragLocation.x) * 0.015
                                let deltaY = Float(value.location.y - lastDragLocation.y) * 0.015
                                attachment.rotationY += deltaX
                                attachment.rotationX += deltaY
                                lastDragLocation = value.location
                            }
                        }
                        .onEnded { _ in
                            isDraggingRotation = false
                        }
                )

            // 旋轉與操作提示（右下角）
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("360°")
                    }
                    .font(.system(size: 9, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.ultraThinMaterial)
                    .cornerRadius(4)
                    .padding(6)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var cardFooter: some View {
        HStack(spacing: 12) {
            Button {
                attachment.scale = max(0.4, attachment.scale - 0.15)
            } label: {
                Image(systemName: "minus.magnifyingglass")
                    .font(.caption)
            }
            .buttonStyle(.borderless)

            Text("\(Int(attachment.scale * 100))%")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary)

            Button {
                attachment.scale = min(2.5, attachment.scale + 0.15)
            } label: {
                Image(systemName: "plus.magnifyingglass")
                    .font(.caption)
            }
            .buttonStyle(.borderless)

            Spacer()

            // 重置姿態
            Button {
                attachment.rotationX = 0.4
                attachment.rotationY = 0.6
                attachment.scale = 1.0
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.caption2)
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(UIColor.secondarySystemBackground).opacity(0.85))
    }
}
