//
//  ContentView.swift
//  myScene
//
//  Created by alya Alabdulrahim on 26/11/1447 AH.
//

import SwiftUI
import RealityKit

struct ContentView: View {

    var body: some View {
        VStack {
            ToggleImmersiveSpaceButton()
        }
    }
}

#Preview(windowStyle: .automatic) {
    ContentView()
        .environment(AppModel())
}
