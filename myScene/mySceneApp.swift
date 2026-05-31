//
//  mySceneApp.swift
//  myScene
//
//  Created by alya Alabdulrahim on 26/11/1447 AH.
//

import SwiftUI

@main
struct mySceneApp: App {
    @State private var appModel = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appModel)
        }

        ImmersiveSpace(id: appModel.immersiveSpaceID) {
            ImmersiveView()
                .environment(appModel)
                .onAppear {
                    appModel.immersiveSpaceState = .open

                    // ⏱ Trigger Deuteranomaly filter after 10 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                        withAnimation(.easeInOut(duration: 2.0)) {
                            appModel.deuteranomalyActive = true
                        }
                    }
                }
                .onDisappear {
                    appModel.immersiveSpaceState = .closed
                    appModel.deuteranomalyActive = false
                }
        }
        .immersionStyle(selection: .constant(.full), in: .full)
    }
}
