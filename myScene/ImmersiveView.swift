//
//  ImmersiveView.swift
//  myScene

//  Created by alya Alabdulrahim on 26/11/1447 AH.
//
//
//
//  ImmersiveView.swift
//  myScene
//
//  Created by alya Alabdulrahim on 26/11/1447 AH.
import SwiftUI
import RealityKit
import RealityKitContent

/// Reference-type container so the tint cache can be mutated inside
/// RealityView's update closure without triggering a SwiftUI state change.
private final class TintCache {
    var storage: [ObjectIdentifier: [UIColor]] = [:]
    var lastAppliedIntensity: Float = -1
}

/// Controls panel shown floating above the sign inside the immersive space.
private struct ControlsPanel: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        @Bindable var appModel = appModel

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                Text("Sign Controls")
                    .font(.title2).bold()

                ColorPicker("Sign Color",  selection: $appModel.signColor)
                ColorPicker("Text Color",  selection: $appModel.textColor)

                VStack(alignment: .leading) {
                    Text("Saturation: \(Int(appModel.signSaturation * 100))%")
                    Slider(value: $appModel.signSaturation, in: 0...2).tint(.purple)
                }
                VStack(alignment: .leading) {
                    Text("Contrast: \(Int(appModel.signContrast * 100))%")
                    Slider(value: $appModel.signContrast, in: 0...2).tint(.orange)
                }
                VStack(alignment: .leading) {
                    Text("Opacity: \(Int(appModel.signOpacity * 100))%")
                    Slider(value: $appModel.signOpacity, in: 0...1).tint(.blue)
                }

                Divider()

                Toggle("Deuteranomaly Filter", isOn: $appModel.deuteranomalyActive)
                    .tint(.green)
            }
            .padding(20)
        }
        .frame(width: 360, height: 420)
        .glassBackgroundEffect()
    }
}

struct ImmersiveView: View {
    @Environment(AppModel.self) private var appModel
    @State private var signEntity: ModelEntity?
    @State private var sceneEntity: Entity?
    @State private var tintCache = TintCache()

    var body: some View {
        RealityView { content, attachments in
            if let scene = try? await Entity(named: "Immersive",
                                             in: realityKitContentBundle) {
                content.add(scene)
                sceneEntity = scene

                printAllEntities(scene, indent: 0)

                if let sign = scene.findEntity(named: "BigSign") {

                    // ── SignBoard overlay ──────────────────────────────────
                    let panelEntity = signPanelEntity(in: sign) ?? sign
                    let panelBounds = panelEntity.visualBounds(recursive: true, relativeTo: sign)
                    let fullBounds  = sign.visualBounds(recursive: true, relativeTo: sign)

                    let w  = panelBounds.max.x - panelBounds.min.x
                    let h  = panelBounds.max.y - panelBounds.min.y
                    let cx = (panelBounds.min.x + panelBounds.max.x) / 2
                    let cy = (panelBounds.min.y + panelBounds.max.y) / 2

                    let board = ModelEntity(
                        mesh: .generatePlane(width: w, height: h),
                        materials: [UnlitMaterial()]
                    )
                    board.name = "SignBoard"

                    // 1. Add as child so it inherits the sign's scene graph.
                    sign.addChild(board)

                    // 2. Compute sign face center in world space.
                    //    Use fullBounds.max.z (the front face in local space)
                    //    so the starting point is already at the sign surface.
                    let signWorldRot = sign.orientation(relativeTo: nil)
                    let signMatrix   = sign.transformMatrix(relativeTo: nil)
                    let faceLocal    = SIMD4<Float>(cx, cy, fullBounds.max.z, 1)
                    let faceWorld4   = signMatrix * faceLocal
                    let faceWorld    = SIMD3<Float>(faceWorld4.x, faceWorld4.y, faceWorld4.z)

                    // 3. Push 0.08 m toward the viewer along the world direction
                    //    sign → origin, completely avoiding local-axis drift.
                    let signWorldPos = sign.position(relativeTo: nil)
                    let toViewer     = normalize(-signWorldPos)
                    let boardWorldPos = faceWorld + toViewer * 0.08

                    // 4. Set world-space position & orientation via relativeTo:nil.
                    board.setPosition(boardWorldPos, relativeTo: nil)
                    let uprightRot = simd_quatf(angle: -.pi / 2, axis: SIMD3<Float>(1, 0, 0))
                    board.setOrientation(signWorldRot * uprightRot, relativeTo: nil)

                    signEntity = board
                    sign.components.set(HoverEffectComponent())
                    updateSignTexture(entity: board)

                    // ── Controls panel above the sign ──────────────────────
                    if let panel = attachments.entity(for: "controlPanel") {
                        // Get the sign's world-space position and place the panel
                        // 5.5 m above it and 0.5 m toward the viewer.
                        let signWorld = sign.position(relativeTo: nil)
                        panel.setPosition(
                            SIMD3<Float>(signWorld.x,
                                         signWorld.y + 5.5,
                                         signWorld.z + 0.5),
                            relativeTo: nil
                        )
                        content.add(panel)
                    }
                }
            }
        } update: { content, attachments in
            if let sign = signEntity {
                updateSignTexture(entity: sign)
            }

            let intensity = Float(appModel.filterIntensity)
            if intensity != tintCache.lastAppliedIntensity {
                tintCache.lastAppliedIntensity = intensity
                if let scene = sceneEntity {
                    applyColorFilter(to: scene, intensity: intensity)
                }
            }
        } attachments: {
            Attachment(id: "controlPanel") {
                ControlsPanel()
                    .environment(appModel)
            }
        }
    }

    // MARK: - Material-level color filter

    func applyColorFilter(to entity: Entity, intensity: Float) {
        guard entity.name != "SignBoard" else { return }

        if var model = entity.components[ModelComponent.self] {
            let key = ObjectIdentifier(entity)

            if tintCache.storage[key] == nil {
                tintCache.storage[key] = model.materials.map { material in
                    if let mat = material as? PhysicallyBasedMaterial {
                        return mat.baseColor.tint ?? .white
                    } else if let mat = material as? UnlitMaterial {
                        return mat.color.tint ?? .white
                    }
                    return .white
                }
            }
            guard let baseTints = tintCache.storage[key] else { return }

            model.materials = zip(model.materials, baseTints).map { material, baseTint in
                if var mat = material as? PhysicallyBasedMaterial {
                    mat.baseColor.tint = machadoTransform(baseTint, intensity: intensity)
                    return mat
                } else if var mat = material as? UnlitMaterial {
                    mat.color.tint = machadoTransform(baseTint, intensity: intensity)
                    return mat
                }
                return material
            }
            entity.components[ModelComponent.self] = model
        }

        for child in entity.children {
            applyColorFilter(to: child, intensity: intensity)
        }
    }

    // MARK: - Sign texture

    @MainActor
    func updateSignTexture(entity: ModelEntity) {
        let signView = SignView(
            signColor: appModel.signColor,
            textColor: appModel.textColor,
            saturation: appModel.signSaturation,
            contrast: appModel.signContrast,
            opacity: appModel.signOpacity
        )

        let renderer = ImageRenderer(content: signView)
        renderer.scale = 2.0

        guard let uiImage = renderer.uiImage,
              let rawCG = uiImage.cgImage else {
            print("Failed to render SignView to image")
            return
        }

        let intensity = Float(appModel.filterIntensity)
        let cgImage = machadoTransform(rawCG, intensity: intensity) ?? rawCG

        do {
            let texture = try TextureResource(
                image: cgImage,
                withName: "SignTexture",
                options: .init(semantic: .color)
            )
            var material = UnlitMaterial()
            material.color = .init(tint: .white, texture: .init(texture))
            material.faceCulling = .none
            entity.model?.materials = [material]
            entity.components[OpacityComponent.self] =
                OpacityComponent(opacity: Float(appModel.signOpacity))
        } catch {
            print("Texture error: \(error)")
        }
    }

    // MARK: - Utilities

    func printAllEntities(_ entity: Entity, indent: Int) {
        let spacing = String(repeating: "  ", count: indent)
        let b = entity.visualBounds(recursive: false, relativeTo: entity.parent)
        let xSpan = b.max.x - b.min.x
        let ySpan = b.max.y - b.min.y
        print("\(spacing)→ '\(entity.name)'  xSpan=\(String(format: "%.2f", xSpan))  ySpan=\(String(format: "%.2f", ySpan))")
        for child in entity.children {
            printAllEntities(child, indent: indent + 1)
        }
    }

    /// Walks the subtree rooted at `root` and returns the entity whose own
    /// (non-recursive) bounding box has the greatest X span — i.e. the widest
    /// flat panel rather than a narrow vertical pole.
    func signPanelEntity(in root: Entity) -> Entity? {
        var best: Entity? = nil
        var bestSpan: Float = 0
        func walk(_ e: Entity) {
            let b = e.visualBounds(recursive: false, relativeTo: e.parent)
            let xSpan = b.max.x - b.min.x
            if xSpan > bestSpan {
                bestSpan = xSpan
                best = e
            }
            for child in e.children { walk(child) }
        }
        walk(root)
        return best
    }
}

#Preview(immersionStyle: .full) {
    ImmersiveView()
        .environment(AppModel())
}
