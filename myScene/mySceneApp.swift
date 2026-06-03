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

                    // Gradually increase filter over 10 seconds
                    let steps = 20
                    let interval = 10.0 / Double(steps)

                    for i in 1...steps {
                        DispatchQueue.main.asyncAfter(deadline: .now() + interval * Double(i)) {
                            withAnimation(.linear(duration: interval)) {
                                appModel.filterIntensity = Double(i) / Double(steps)
                                if i == steps {
                                    appModel.deuteranomalyActive = true
                                }
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
