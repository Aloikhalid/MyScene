//
//  ImmersiveView.swift
//  myScene
//
//  Created by alya Alabdulrahim on 26/11/1447 AH.
//

import SwiftUI
import RealityKit
import RealityKitContent

struct ImmersiveView: View {
    @Environment(AppModel.self) private var appModel
    @State private var signEntity: ModelEntity?
    @State private var sceneEntity: Entity?
    @State private var lastAppliedIntensity: Float = -1
    // Stores each entity's original material tints so repeated calls always
    // transform from the source value instead of compounding.
    @State private var originalTints: [ObjectIdentifier: [UIColor]] = [:]

    var body: some View {
        RealityView { content in
            if let scene = try? await Entity(named: "Immersive",
                                             in: realityKitContentBundle) {
                content.add(scene)
                sceneEntity = scene

                printAllEntities(scene, indent: 0)

                if let sign = scene.findEntity(named: "BigSign") {
                    let board = ModelEntity(
                        mesh: .generatePlane(width: 7, height: 3.5),
                        materials: [UnlitMaterial()]
                    )
                    board.name = "SignBoard"
                    board.position = [1, 4.5, 0.01]
                    board.orientation = simd_quatf(angle: .pi / 1, axis: [1, 0, 0])
                    sign.addChild(board)
                    signEntity = board
                    sign.components.set(HoverEffectComponent())

                    updateSignTexture(entity: board)
                }
            }
        } update: { content in
            if let sign = signEntity {
                updateSignTexture(entity: sign)
            }

            // Re-apply color filter only when intensity actually changes
            let intensity = Float(appModel.filterIntensity)
            if intensity != lastAppliedIntensity {
                lastAppliedIntensity = intensity
                if let scene = sceneEntity {
                    applyColorFilter(to: scene, intensity: intensity)
                }
            }
        }
        // Passthrough camera pixels are multiplied channel-by-channel.
        // Full cross-channel mixing is not possible via colorMultiply;
        // we use the Machado diagonal so blue is correctly preserved.
        .preferredSurroundingsEffect(
            appModel.filterIntensity > 0
            ? .colorMultiply(passthroughColor(intensity: appModel.filterIntensity))
            : .none
        )
    }

    // MARK: - Color helpers

    private func passthroughColor(intensity: Double) -> Color {
        let c = machadoPassthroughApprox(intensity: intensity)
        return Color(red: c.red, green: c.green, blue: c.blue)
    }

    // MARK: - Scene entity filter

    /// Walks every entity in the subtree and applies the interpolated Machado
    /// matrix to its material tint colors.
    ///
    /// For solid-color materials this is fully accurate (the matrix is applied
    /// directly to the stored color). For texture-mapped materials the tint
    /// multiplies every texel — this preserves all texture detail while
    /// applying the best scaling approximation available through the tint API.
    /// True per-pixel cross-channel mixing on loaded .usdz textures requires a
    /// custom ShaderGraph material; the sign board uses CIColorMatrix for that.
    func applyColorFilter(to entity: Entity, intensity: Float) {
        guard entity.name != "SignBoard" else { return }  // sign handles its own pixels

        if var model = entity.components[ModelComponent.self] {
            let key = ObjectIdentifier(entity)

            // Snapshot original tints once so we always transform from the source,
            // not from a previously transformed value.
            if originalTints[key] == nil {
                originalTints[key] = model.materials.map { material in
                    if let mat = material as? PhysicallyBasedMaterial {
                        return mat.baseColor.tint ?? .white
                    } else if let mat = material as? UnlitMaterial {
                        return mat.color.tint ?? .white
                    }
                    return .white
                }
            }
            let baseTints = originalTints[key]!

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

    /// Renders the sign view to a CGImage, applies the full Machado CIColorMatrix
    /// per-pixel (true cross-channel transform), then uploads as a texture.
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

        // Full per-pixel Machado matrix via CoreImage CIColorMatrix:
        // each output pixel's red is 0.367·R + 0.861·G − 0.228·B, etc.
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
        print("\(spacing)→ '\(entity.name)'")
        for child in entity.children {
            printAllEntities(child, indent: indent + 1)
        }
    }
}

#Preview(immersionStyle: .full) {
    ImmersiveView()
        .environment(AppModel())
}
