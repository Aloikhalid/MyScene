//
//  ContentView.swift
//  myScene
//
//  Created by alya Alabdulrahim on 26/11/1447 AH.
//

import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        @Bindable var appModel = appModel

        ScrollView {
            VStack(spacing: 20) {
                ToggleImmersiveSpaceButton()

                Divider()

                VStack(alignment: .leading, spacing: 16) {
                    Text("Sign Controls")
                        .font(.title2).bold()

                    // Sign background color
                    ColorPicker("Sign Color", selection: $appModel.signColor)

                    // Text color
                    ColorPicker("Text Color", selection: $appModel.textColor)

                    // Saturation
                    VStack(alignment: .leading) {
                        Text("Saturation: \(Int(appModel.signSaturation * 100))%")
                        Slider(value: $appModel.signSaturation, in: 0...2)
                            .tint(.purple)
                    }

                    // Contrast
                    VStack(alignment: .leading) {
                        Text("Contrast: \(Int(appModel.signContrast * 100))%")
                        Slider(value: $appModel.signContrast, in: 0...2)
                            .tint(.orange)
                    }

                    // Opacity
                    VStack(alignment: .leading) {
                        Text("Opacity: \(Int(appModel.signOpacity * 100))%")
                        Slider(value: $appModel.signOpacity, in: 0...1)
                            .tint(.blue)
                    }

                    Divider()

                    // Preview of the sign
                    Text("Preview")
                        .font(.headline)

                    SignView(
                        signColor: appModel.signColor,
                        textColor: appModel.textColor,
                        saturation: appModel.signSaturation,
                        contrast: appModel.signContrast,
                        opacity: appModel.signOpacity
                    )
                    .scaleEffect(0.4)
                    .frame(height: 120)

                    Divider()

                    Toggle("Deuteranomaly Filter", isOn: $appModel.deuteranomalyActive)
                        .tint(.green)
                }
                .padding()
                .glassBackgroundEffect()
            }
            .padding()
        }
    }
}
#Preview(windowStyle: .automatic) {
    ContentView()
        .environment(AppModel())
}
