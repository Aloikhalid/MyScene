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

    // Manual placement for the editable SwiftUI sign layer in BigSign's local space.
    // Tune only these numbers after each run until the overlay sits perfectly on the base sign.
    private let editableSignPosition = SIMD3<Float>(0.08, 2.43, 0.0)
    private let editableSignSize = SIMD2<Float>(10.52, 4.58)
    private let editableSignForwardOffset: Float = 0.020

    var body: some View {
        RealityView { content, attachments in
            if let scene = try? await Entity(named: "Immersive",
                                             in: realityKitContentBundle) {
                content.add(scene)
                sceneEntity = scene

                printAllEntities(scene, indent: 0)

                if let sign = scene.findEntity(named: "BigSign") {

                    // ── SignBoard overlay ──────────────────────────────────
                    // Build the editable layer as a second skin over the existing highway sign.
                    // It is parented to the same parent as BigSign so its transform can match the
                    // sign face directly instead of drifting inside BigSign's nested local axes.
                    let board = ModelEntity(
                        mesh: .generatePlane(width: editableSignSize.x, height: editableSignSize.y),
                        materials: [UnlitMaterial()]
                    )
                    board.name = "SignBoard"

                    let signBounds = sign.visualBounds(recursive: true, relativeTo: sign.parent)
                    let signCenter = (signBounds.min + signBounds.max) * 0.5

                    // RealityKit's generated plane already lives in the X/Y plane, which matches
                    // the highway sign face. Rotate it 180° so we see the textured front side
                    // from the street/camera side instead of the mirrored back side.
                    let signFaceRotation = simd_quatf(angle: .pi, axis: SIMD3<Float>(0, 1, 0))

                    if let signParent = sign.parent {
                        signParent.addChild(board)

                        // Place the editable layer on the front face of the base sign instead of
                        // through its middle. This creates the desired two stacked layers:
                        // base sign behind, editable SwiftUI texture slightly in front.
                        board.setPosition(
                            SIMD3<Float>(
                                signCenter.x + editableSignPosition.x,
                                signCenter.y + editableSignPosition.y,
                                signBounds.min.z - editableSignForwardOffset
                            ),
                            relativeTo: signParent
                        )

                        // Do not multiply by BigSign's nested orientation here; that rotated the
                        // overlay sideways so it cut through the sign. Keep the generated plane
                        // upright in the same front-facing plane as the sign artwork.
                        board.setOrientation(signFaceRotation, relativeTo: signParent)
                    } else {
                        sign.addChild(board)
                        board.position = SIMD3<Float>(
                            editableSignPosition.x,
                            editableSignPosition.y,
                            editableSignPosition.z - editableSignForwardOffset
                        )
                        board.orientation = signFaceRotation
                    }

                    signEntity = board
                    board.components.set(HoverEffectComponent())
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
                        return mat.baseColor.tint
                    } else if let mat = material as? UnlitMaterial {
                        return mat.color.tint
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

        for child in entity.children where child.name != "SignBoard" {
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
            // Render the editable skin from both sides while we align it exactly over the
            // original sign; the duplicate was a placement issue, not the texture itself.
            material.faceCulling = .back
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
}

#Preview(immersionStyle: .full) {
    ImmersiveView()
        .environment(AppModel())
}
