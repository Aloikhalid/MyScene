//
//  DeuteranopiaMath.swift
//  myScene
//
//  Created by alya Alabdulrahim on 18/12/1447 AH.
//

//
//  DeuteranopiaMath.swift
//  myScene
//
//  Machado, G.M., Oliveira, M.M., Fernandes, L.A.F. (2009)
//  "A Physiologically-based Model for Simulation of Color Vision Deficiency"
//  IEEE Transactions on Visualization and Computer Graphics.
//
//  The matrix M transforms linear RGB such that the result matches what a
//  deuteranope (no functioning M-cones / green receptors) perceives.
//
//  output = M × input:
//    R' = 0.367322·R + 0.860646·G − 0.227968·B
//    G' = 0.280085·R + 0.672501·G + 0.047413·B
//    B' = −0.011820·R + 0.042940·G + 0.968881·B
//
//  All three functions accept an `intensity` in [0, 1] that linearly
//  interpolates between the identity matrix (0) and the full Machado
//  matrix (1), so the filter can be faded in gradually.


import CoreImage
import UIKit

// Row vectors of the Machado deuteranopia matrix (R,G,B → output channel)
private let mR = (r: 0.367322, g: 0.860646, b: -0.227968)
private let mG = (r: 0.280085, g: 0.672501, b:  0.047413)
private let mB = (r: -0.011820, g: 0.042940, b:  0.968881)

/// Applies the interpolated Machado matrix to a solid UIColor.
/// Accurate for any color defined as a solid value (e.g. material tints).
func machadoTransform(_ color: UIColor, intensity: Float) -> UIColor {
    guard intensity > 0 else { return color }
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    color.getRed(&r, green: &g, blue: &b, alpha: &a)

    let t = Double(intensity)
    // Each output channel = lerp(identity row, Machado row) · input
    let rOut = (1 - (1 - mR.r)*t)*r +        mR.g*t*g +        mR.b*t*b
    let gOut =        mG.r*t*r + (1 - (1 - mG.g)*t)*g +        mG.b*t*b
    let bOut =        mB.r*t*r +        mB.g*t*g + (1 - (1 - mB.b)*t)*b

    return UIColor(
        red:   CGFloat(max(0, min(1, rOut))),
        green: CGFloat(max(0, min(1, gOut))),
        blue:  CGFloat(max(0, min(1, bOut))),
        alpha: a
    )
}

/// Applies the interpolated Machado matrix to every pixel of a CGImage using
/// CoreImage CIColorMatrix. This is a true cross-channel transform: each output
/// pixel's red value, for example, is computed from ALL three input channels —
/// not just scaled in isolation. This is the only way to fully reproduce the
/// green-to-red confusion characteristic of deuteranopia.
func machadoTransform(_ image: CGImage, intensity: Float) -> CGImage? {
    guard intensity > 0 else { return image }
    let t = Double(intensity)
    let ci = CIImage(cgImage: image)

    guard let filter = CIFilter(name: "CIColorMatrix") else { return nil }
    filter.setValue(ci, forKey: kCIInputImageKey)

    // CIVector(x:y:z:w:) maps to (R,G,B,A) coefficients for one output channel.
    // Interpolated rows: lerp(identity, Machado) row by row.
    filter.setValue(CIVector(x: 1-(1-mR.r)*t, y: mR.g*t,         z: mR.b*t,         w: 0), forKey: "inputRVector")
    filter.setValue(CIVector(x: mG.r*t,        y: 1-(1-mG.g)*t,  z: mG.b*t,         w: 0), forKey: "inputGVector")
    filter.setValue(CIVector(x: mB.r*t,        y: mB.g*t,         z: 1-(1-mB.b)*t,  w: 0), forKey: "inputBVector")
    filter.setValue(CIVector(x: 0, y: 0, z: 0, w: 1), forKey: "inputAVector")
    filter.setValue(CIVector(x: 0, y: 0, z: 0, w: 0), forKey: "inputBiasVector")

    guard let output = filter.outputImage else { return nil }
    let colorSpace = image.colorSpace ?? CGColorSpaceCreateDeviceRGB()
    let ctx = CIContext(options: [.workingColorSpace: colorSpace as Any])
    return ctx.createCGImage(output, from: output.extent)
}
