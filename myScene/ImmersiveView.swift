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
    var lastAppliedIntensity: Float = -1
}

struct ImmersiveView: View {
    @Environment(AppModel.self) private var appModel
    @State private var signEntity: ModelEntity?
    @State private var sceneEntity: Entity?
    @State private var tintCache = TintCache()

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

                    // Compute the sign's own bounding box in its local space so
                    // we can auto-center the overlay on the sign face without
                    // touching BigSign's transform at all.
                    let bounds = sign.visualBounds(recursive: true, relativeTo: sign)
                    let cx = (bounds.min.x + bounds.max.x) / 2
                    let cy = (bounds.min.y + bounds.max.y) / 2
                    let fz = bounds.max.z + 0.02  // 2 cm in front of the deepest face

                    board.position = SIMD3<Float>(cx, cy, fz)
                    board.orientation = .identity
                    print("SignBoard bounds: \(bounds), placed at (\(cx), \(cy), \(fz))")

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

            let intensity = Float(appModel.filterIntensity)
            if intensity != tintCache.lastAppliedIntensity {
                tintCache.lastAppliedIntensity = intensity
                if let scene = sceneEntity {
                    applyColorFilter(to: scene, intensity: intensity)
                }
            }
        }
        // NOTE: preferredSurroundingsEffect(.colorMultiply) has been removed.
        // A diagonal channel-scale CANNOT correctly simulate deuteranopia —
        // the correct Brettel/Machado transform mixes channels (R_out depends
        // on G_in, etc.) which colorMultiply is incapable of expressing.
        // Any diagonal values produce a heavy false tint (red, blue, etc.).
        //
        // The sign board (SignBoard entity) receives a fully accurate per-pixel
        // Machado matrix via CoreImage CIColorMatrix in updateSignTexture().
        // Accurate simulation of the full 3D scene requires a Metal post-process
        // compositor pass (CompositorLayer), which is a larger architecture change.
    }

    // MARK: - Material-level color filter

    /// Applies the Machado matrix to material tint colors.
    /// Exact for solid-color materials; for textured materials it applies
    /// the matrix to the tint (which starts as white — so no change for white
    /// tints, but correct for any material with a non-white tint color).
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

    /// Renders the sign and applies the full Machado CIColorMatrix per-pixel
    /// before uploading — true cross-channel transform on every pixel.
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
            material.faceCulling = .none   // visible from both sides
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
