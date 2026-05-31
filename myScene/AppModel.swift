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
    var signOpacity: Double = 1.0
    var signContrast: Double = 1.0
    var signColor: Color = .white

    // Color blindness filter
    var deuteranomalyActive: Bool = false
    var deuteranomalyIntensity: Float = 0.0
}
