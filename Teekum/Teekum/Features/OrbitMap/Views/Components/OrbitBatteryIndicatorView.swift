//
//  OrbitBatteryIndicatorView.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 17/11/26.
//

import SwiftUI

struct OrbitBatteryIndicatorView: View {
    let batteryLevel: Float?

    var body: some View {
        if let percentage = Self.percentage(for: batteryLevel) {
            Label(percentage, systemImage: "bolt.fill")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.yellow)
                .fixedSize()
        }
    }

    static func percentage(for level: Float?) -> String? {
        guard let level, (0...Float(0.1)).contains(level) else { return nil }
        return level.formattedBatteryPercentage
    }
}

#Preview("10 percent battery and below") {
    HStack(spacing: 24) {
        OrbitBatteryIndicatorView(batteryLevel: 0.1)
        OrbitBatteryIndicatorView(batteryLevel: 0.05)
        OrbitBatteryIndicatorView(batteryLevel: 0)
    }
    .padding()
    .background(.black)
}
