//
//  ImmersiveView.swift
//  myScene
//
//  Created by alya Alabdulrahim on 26/11/1447 AH.
//

//
//
//  ImmersiveView.swift
//  myScene

import SwiftUI
import RealityKit
import RealityKitContent

struct ImmersiveView: View {
    @Environment(AppModel.self) private var appModel
    @State private var signEntity: ModelEntity?
    @State private var sceneEntity: Entity?

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

            // Apply Deuteranomaly filter by tinting the scene
            if let scene = sceneEntity {
                if appModel.deuteranomalyActive {
                    // Simulate green-red color blindness with yellow-brown tint
                    scene.components[OpacityComponent.self] =
                        OpacityComponent(opacity: 0.85)
                } else {
                    scene.components[OpacityComponent.self] =
                        OpacityComponent(opacity: 1.0)
                }
            }
        }
        // This changes the surrounding passthrough tint
        .preferredSurroundingsEffect(
            appModel.deuteranomalyActive
            ? .colorMultiply(.init(red: 0.7, green: 0.65, blue: 0.0))
            : .none
        )
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
