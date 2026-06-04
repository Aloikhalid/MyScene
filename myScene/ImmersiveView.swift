//
//  ImmersiveView.swift
//  myScene
//
//  Created by alya Alabdulrahim on 26/11/1447 AH.
//

import SwiftUI
import RealityKit
import RealityKitContent

/// Reference-type container so the tint cache can be mutated inside
/// RealityView's update closure without triggering a SwiftUI state change.
private final class TintCache {
    var storage: [ObjectIdentifier: [UIColor]] = [:]
}

/// Full-scene warm overlay that mimics the perceptual appearance of deuteranopia.
/// Based on the same approach as the Sighted reference app:
/// a warm yellow tint layer + a desaturation layer, both faded in with `intensity`.
/// This avoids the colorMultiply-diagonal problem (which makes everything look blue).
private struct DeuteranomalyOverlay: View {
    var intensity: Double

    var body: some View {
        ZStack {
            // Warm amber tint — deuteranopia shifts greens toward orange/yellow
            Rectangle()
                .fill(Color(red: 0.68, green: 0.62, blue: 0.32))
                .opacity(intensity * 0.30)

            // Desaturation layer — reduces the vivid green/red contrast
            Rectangle()
                .fill(Color.gray)
                .blendMode(.saturation)
                .opacity(intensity * 0.45)
        }
        .frame(width: 1500, height: 1500)
    }
}

struct ImmersiveView: View {
    @Environment(AppModel.self) private var appModel
    @State private var signEntity: ModelEntity?
    @State private var sceneEntity: Entity?
    @State private var lastAppliedIntensity: Float = -1
    // Reference type — mutating .storage never triggers a re-render.
    @State private var tintCache = TintCache()

    var body: some View {
        RealityView { content, attachments in
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

            // Place the full-scene overlay as a large plane in front of the user.
            // It uses SwiftUI blend modes so it tints the whole virtual world
            // without flattening it to a solid colour.
            if let overlay = attachments.entity(for: "deuteranomalyOverlay") {
                overlay.position = [0, 1.5, -2.5]
                content.add(overlay)
            }

        } update: { content, attachments in
            if let sign = signEntity {
                updateSignTexture(entity: sign)
            }

            // Re-apply material-level Machado transform only when intensity changes
            let intensity = Float(appModel.filterIntensity)
            if intensity != lastAppliedIntensity {
                lastAppliedIntensity = intensity
                if let scene = sceneEntity {
                    applyColorFilter(to: scene, intensity: intensity)
                }
            }
        } attachments: {
            // The overlay view reactively updates whenever filterIntensity changes.
            Attachment(id: "deuteranomalyOverlay") {
                DeuteranomalyOverlay(intensity: appModel.filterIntensity)
            }
        }
        // colorMultiply is removed — its diagonal (0.367, 0.673, 0.969) made the
        // whole scene look dark blue in full immersion mode because it doesn't
        // include the off-diagonal G→R contribution. The SwiftUI overlay above
        // gives a better perceptual approximation.
    }

    // MARK: - Scene entity filter

    /// Walks every entity in the subtree and applies the interpolated Machado
    /// matrix to its material tint colors.
    /// For solid-color materials this is fully accurate. For texture-mapped
    /// materials the tint scales channels (no cross-channel mix), but it still
    /// correctly warms/shifts the hue.
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

    /// Renders the sign, applies the full Machado CIColorMatrix per-pixel
    /// (true cross-channel transform), then uploads as a texture.
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
