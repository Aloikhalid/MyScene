//
//  ContentView.swift
//  myScene
//
//  Created by alya Alabdulrahim on 26/11/1447 AH.
//

import SwiftUI
import RealityKit


struct ContentView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        @Bindable var appModel = appModel

        VStack(spacing: 20) {
            ToggleImmersiveSpaceButton()

            Divider()

            VStack(alignment: .leading, spacing: 16) {
                Text("Sign Controls")
                    .font(.title2).bold()

                VStack(alignment: .leading) {
                    Text("Opacity: \(Int(appModel.signOpacity * 100))%")
                    Slider(value: $appModel.signOpacity, in: 0...1)
                        .tint(.blue)
                }

                VStack(alignment: .leading) {
                    Text("Brightness: \(Int(appModel.signContrast * 100))%")
                    Slider(value: $appModel.signContrast, in: 0...2)
                        .tint(.orange)
                }

                ColorPicker("Sign Color", selection: $appModel.signColor)

                Divider()

                // Color blindness toggle
                Toggle("Deuteranomaly Filter", isOn: $appModel.deuteranomalyActive)
                    .tint(.green)
            }
            .padding()
            .glassBackgroundEffect()
        }
        .padding()
    }
}
#Preview(windowStyle: .automatic) {
    ContentView()
        .environment(AppModel())
}
