//
//  ImmersiveView.swift
//  myScene

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
                    board.position = [1, 4.5, 0.01]  // moved left and higher
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

            // Apply per-pixel deuteranomaly color transform to all 3D scene entities
            let intensity = Float(appModel.filterIntensity)
            if intensity != lastAppliedIntensity {
                lastAppliedIntensity = intensity
                if let scene = sceneEntity {
                    applyColorFilter(to: scene, intensity: intensity)
                }
            }
        }
        // Gradually multiply passthrough camera pixels from neutral → deuteranomaly tint
        .preferredSurroundingsEffect(
            appModel.filterIntensity > 0
            ? .colorMultiply(deuteranomalyColor(intensity: appModel.filterIntensity))
            : .none
        )
    }

    // Interpolate surroundings colorMultiply from neutral (1,1,1) → deuteranomaly (0.7, 0.65, 0.0)
    func deuteranomalyColor(intensity: Double) -> Color {
        Color(
            red:   1.0 - 0.30 * intensity,
            green: 1.0 - 0.35 * intensity,
            blue:  1.0 - 1.00 * intensity
        )
    }

    // Walk every entity and multiply its material colors by the deuteranomaly tint.
    // This changes the actual pixel colors stored in each material rather than
    // placing a colored overlay on top.
    func applyColorFilter(to entity: Entity, intensity: Float) {
        guard entity.name != "SignBoard" else { return }  // sign manages its own texture

        if var model = entity.components[ModelComponent.self] {
            let r = CGFloat(1.0 - 0.30 * intensity)
            let g = CGFloat(1.0 - 0.35 * intensity)
            let b = CGFloat(1.0 - 1.00 * intensity)
            let tint = UIColor(red: r, green: g, blue: b, alpha: 1.0)

            model.materials = model.materials.map { material in
                if var mat = material as? PhysicallyBasedMaterial {
                    mat.baseColor.tint = tint
                    return mat
                } else if var mat = material as? UnlitMaterial {
                    mat.color.tint = tint
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

    func printAllEntities(_ entity: Entity, indent: Int) {
        let spacing = String(repeating: "  ", count: indent)
        print("\(spacing)→ '\(entity.name)'")
        for child in entity.children {
            printAllEntities(child, indent: indent + 1)
        }
    }

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
              let cgImage = uiImage.cgImage else {
            print("Failed to render SignView to image")
            return
        }

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
}
#Preview(immersionStyle: .full) {
    ImmersiveView()
        .environment(AppModel())
}
