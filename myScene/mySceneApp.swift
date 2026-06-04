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
                    appModel.deuteranomalyActive = false
                    appModel.filterIntensity = 0.0

                    // Filter starts at 5 seconds and is fully applied at 10 seconds
                    let steps = 100
                    let startDelay = 5.0
                    let duration = 5.0
                    let interval = duration / Double(steps)

                    for i in 1...steps {
                        DispatchQueue.main.asyncAfter(deadline: .now() + startDelay + interval * Double(i)) {
                            appModel.filterIntensity = Double(i) / Double(steps)
                            if i == steps {
                                appModel.deuteranomalyActive = true
                            }
                        }
                    }
                }
                .onDisappear {
                    appModel.immersiveSpaceState = .closed
                    appModel.deuteranomalyActive = false
                    appModel.filterIntensity = 0.0
                }
        }
        .immersionStyle(selection: .constant(.full), in: .full)
    }
}
