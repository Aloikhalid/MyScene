//
//  SignControlsView.swift
//  myScene
//
//  Created by alya Alabdulrahim on 14/12/1447 AH.
//

import SwiftUI
import RealityKit

struct SignControlsView: View {
    @Binding var opacity: Double
    @Binding var contrast: Double
    @Binding var color: Color
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Sign Controls")
                .font(.title2)
                .bold()
            
            // Opacity Slider
            VStack(alignment: .leading) {
                Text("Opacity: \(Int(opacity * 100))%")
                Slider(value: $opacity, in: 0...1)
                    .tint(.blue)
            }
            
            // Contrast Slider
            VStack(alignment: .leading) {
                Text("Contrast: \(Int(contrast * 100))%")
                Slider(value: $contrast, in: 0...2)
                    .tint(.orange)
            }
            
            // Color Picker
            ColorPicker("Sign Color", selection: $color)
        }
        .padding(30)
        .glassBackgroundEffect() // visionOS glass look
    }
}
