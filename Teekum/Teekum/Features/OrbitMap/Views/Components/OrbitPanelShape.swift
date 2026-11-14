//
//  OrbitPanelShape.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 06/11/26.
//

import SwiftUI

struct OrbitPanelShape: Shape {
    var cornerRadius: CGFloat = 40
    var crestHeight: CGFloat? = 44
    var crestWidth: CGFloat = 144

    func path(in rect: CGRect) -> Path {
        let crest = min(crestHeight ?? rect.height, rect.height)
        let radius = min(
            cornerRadius,
            rect.width / 2,
            (rect.height - crest) / 2
        )
        let halfCrest = min(
            crestWidth / 2,
            max(0, rect.width / 2 - radius)
        )
        let mid = rect.midX
        let shoulderY = rect.minY + crest

        return Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(
                to: CGPoint(x: rect.minX, y: shoulderY + radius)
            )
            path.addQuadCurve(
                to: CGPoint(x: rect.minX + radius, y: shoulderY),
                control: CGPoint(x: rect.minX, y: shoulderY)
            )

            path.addLine(
                to: CGPoint(x: mid - halfCrest, y: shoulderY)
            )
            path.addCurve(
                to: CGPoint(x: mid, y: rect.minY),
                control1: CGPoint(
                    x: mid - halfCrest * 0.7,
                    y: shoulderY
                ),
                control2: CGPoint(
                    x: mid - halfCrest * 0.65,
                    y: rect.minY
                )
            )
            path.addCurve(
                to: CGPoint(x: mid + halfCrest, y: shoulderY),
                control1: CGPoint(
                    x: mid + halfCrest * 0.65,
                    y: rect.minY
                ),
                control2: CGPoint(
                    x: mid + halfCrest * 0.7,
                    y: shoulderY
                )
            )

            path.addLine(
                to: CGPoint(x: rect.maxX - radius, y: shoulderY)
            )
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: shoulderY + radius),
                control: CGPoint(x: rect.maxX, y: shoulderY)
            )
            path.addLine(
                to: CGPoint(x: rect.maxX, y: rect.maxY)
            )
            path.closeSubpath()
        }
    }
}

#Preview("Sheet and collapsed handle") {
    VStack(spacing: 32) {
        OrbitPanelShape()
            .fill(Color.blackCard)
            .frame(height: 280)
            .overlay(alignment: .top) {
                Image(systemName: "chevron.down")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .frame(height: 44)
            }

        OrbitPanelShape(cornerRadius: 0, crestHeight: nil, crestWidth: 176)
            .fill(Color.blackCard)
            .frame(width: 176, height: 88)
            .overlay(alignment: .top) {
                Image(systemName: "chevron.up")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .frame(height: 54)
            }
    }
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(.black)
    .preferredColorScheme(.dark)
}
