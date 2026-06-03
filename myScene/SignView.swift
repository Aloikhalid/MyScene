//
//  SignView.swift
//  myScene
//
//  Created by alya Alabdulrahim on 16/12/1447 AH.
//

import SwiftUI

struct SignView: View {
    var signColor: Color = Color(red: 0.2, green: 0.5, blue: 0.3)
    var textColor: Color = .white
    var saturation: Double = 1.0
    var contrast: Double = 1.0
    var opacity: Double = 1.0

    var body: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: 8)
                .fill(signColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white, lineWidth: 3)
                )

            HStack(spacing: 0) {
                // Left side - West
                VStack(spacing: 8) {
                    HStack {
                        ZStack {
                            Circle()
                                .fill(Color(red: 0.3, green: 0.3, blue: 0.7))
                                .frame(width: 44, height: 44)
                            Text("76")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(textColor)
                        }
                        Text("WEST")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(textColor)
                    }

                    Text("Sighted")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(textColor)

                    Image(systemName: "arrow.turn.up.left")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(textColor)
                }
                .frame(maxWidth: .infinity)

                // Divider
                Rectangle()
                    .fill(textColor)
                    .frame(width: 2)
                    .padding(.vertical, 16)

                // Right side - North
                VStack(spacing: 8) {
                    HStack {
                        ZStack {
                            Circle()
                                .fill(Color(red: 0.3, green: 0.3, blue: 0.7))
                                .frame(width: 44, height: 44)
                            Text("43")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(textColor)
                        }
                        Text("NORTH")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(textColor)
                    }

                    Text("Street no 6")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(textColor)

                    Text("2 kilometres")
                        .font(.system(size: 18))
                        .foregroundColor(textColor)

                    HStack(spacing: 12) {
                        // Exit button
                        ZStack {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.yellow)
                            Text("EXIT")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.black)
                        }
                        .frame(width: 60, height: 28)

                        // Only button
                        ZStack {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.yellow)
                            Text("ONLY")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.black)
                        }
                        .frame(width: 60, height: 28)
                    }

                    Image(systemName: "arrow.turn.up.right")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(textColor)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(20)
        }
        .frame(width: 600, height: 300)
        .saturation(saturation)
        .contrast(contrast)
        .opacity(opacity)
    }
}
