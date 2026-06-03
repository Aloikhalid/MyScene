//
//  AppModel.swift
//  myScene
//
//  Created by alya Alabdulrahim on 26/11/1447 AH.
//

import SwiftUI
import Observation

@MainActor
@Observable
class AppModel {
    let immersiveSpaceID = "ImmersiveSpace"

    enum ImmersiveSpaceState {
        case closed, inTransition, open
    }
    var immersiveSpaceState = ImmersiveSpaceState.closed

    // Sign controls
    var signColor: Color = Color(red: 0.2, green: 0.5, blue: 0.3)
    var textColor: Color = .white
    var signSaturation: Double = 1.0
    var signContrast: Double = 1.0
    var signOpacity: Double = 1.0

    // Filter
    var deuteranomalyActive: Bool = false
    var filterIntensity: Double = 0.0  // 0.0 = none, 1.0 = full
}
