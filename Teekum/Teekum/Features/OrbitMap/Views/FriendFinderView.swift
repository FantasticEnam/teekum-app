//
//  FriendFinderView.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 11/11/26.
//

import SwiftUI

struct FriendFinderView: View {
    let member: Member
    let location: LocationService?
    @Environment(\.dismiss) private var dismiss
    @ScaledMetric(relativeTo: .largeTitle) private var arrowSize = 80

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text(member.initials).font(.largeTitle.bold()).foregroundStyle(member.color.swiftUIColor)
                if let local = location?.currentLocation, let target = member.coordinate {
                    let distance = local.distance(to: target)
                    let angle = local.bearing(to: target) - (location?.currentHeading ?? 0)
                    Image(systemName: "location.north.fill")
                        .font(.system(size: arrowSize))
                        .rotationEffect(.degrees(angle))
                        .accessibilityLabel("Direction to \(member.initials)")
                    Text(distance.formattedDistance()).font(.title.bold())
                } else { ContentUnavailableView("Location unavailable", systemImage: "location.slash") }
                if let timestamp = member.measurementTimestamp {
                    Text("Location measured \(timestamp, style: .relative) ago").font(.caption)
                }
                if let accuracy = member.horizontalAccuracy { Text("Accuracy ±\(Int(accuracy)) m").font(.caption) }
                if let battery = member.batteryLevel { Label(battery.formattedBatteryPercentage, systemImage: battery.batterySystemImage) }
                Text("GPS and compass guidance").font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.black)
            .navigationTitle("Find friend")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close", systemImage: "xmark", action: dismiss.callAsFunction) } }
        }
        .onAppear { location?.setTacticalRadarActive(true) }
        .onDisappear { location?.setTacticalRadarActive(false) }
    }
}

#Preview("Direction to a friend") {
    @Previewable @State var location = {
        let location = LocationService(isLiveSharingEnabled: false)
        location.currentLocation = LocationPin(
            coordinate: .init(latitude: -6.1988, longitude: 106.8225),
            horizontalAccuracy: 5
        )
        location.currentHeading = 30
        return location
    }()

    FriendFinderView(member: SessionStore.preview.members[0], location: location)
        .preferredColorScheme(.dark)
}
