//
//  ImmersiveView.swift
//  myScene
//
//  Created by alya Alabdulrahim on 26/11/1447 AH.
//

//
//  ImmersiveView.swift
//  myScene

//
//  ImmersiveView.swift
//  myScene

import SwiftUI
import RealityKit
import RealityKitContent

struct ImmersiveView: View {
    @Environment(AppModel.self) private var appModel
    @State private var signEntity: ModelEntity?
    @State private var filterIntensity: Float = 0.0

    var body: some View {
        RealityView { content in
            if let scene = try? await Entity(named: "Immersive",
                                             in: realityKitContentBundle) {
                content.add(scene)

                if let sign = scene.findEntity(named: "BigSign") {
                    let board = ModelEntity(
                        mesh: .generatePlane(width: 2.0, height: 0.8),
                        materials: [SimpleMaterial(color: .white, isMetallic: false)]
                    )
                    board.name = "SignBoard"
                    board.position = [0, 0, 0.01]
                    sign.addChild(board)
                    signEntity = board
                    sign.components.set(HoverEffectComponent())
                }
            }
        } update: { content in
            // Update sign material
            if let sign = signEntity {
                let uiColor = UIColor(appModel.signColor)
                    .withAlphaComponent(appModel.signOpacity)
                var material = SimpleMaterial()
                material.color = .init(tint: uiColor, texture: nil)
                sign.model?.materials = [material]
                sign.components[OpacityComponent.self] =
                    OpacityComponent(opacity: Float(appModel.signOpacity))
            }
        }
        .preferredSurroundingsEffect(.none)

        // Deuteranomaly color filter overlay
        if appModel.deuteranomalyActive {
            Color.clear
                .colorEffect(
                    ShaderLibrary.deuteranomaly(.float(filterIntensity))
                )
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 2.0), value: filterIntensity)
        }
    }
}
#Preview(immersionStyle: .full) {
    ImmersiveView()
        .environment(AppModel())
}
