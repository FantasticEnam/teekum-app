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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isBeaconActive = false
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
                Button(isBeaconActive ? "Stop visual beacon" : "Show visual beacon") { isBeaconActive.toggle() }
                    .buttonStyle(.borderedProminent)
                Text("GPS and compass guidance").font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.black)
            .navigationTitle("Find friend")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close", systemImage: "xmark", action: dismiss.callAsFunction) } }
        }
        .fullScreenCover(isPresented: $isBeaconActive) {
            TimelineView(.periodic(from: .now, by: 0.2)) { timeline in
                let lit = reduceMotion || Int(timeline.date.timeIntervalSince1970 * 5).isMultiple(of: 2)
                Button { isBeaconActive = false } label: {
                    VStack(spacing: 20) {
                        Text("HERE").font(.largeTitle.bold())
                        Text("Tap to close beacon")
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(lit ? Color.yellow : .black)
                    .foregroundStyle(lit ? .black : .white)
                }
                .buttonStyle(.plain)
                .ignoresSafeArea()
            }
        }
        .onAppear { location?.setTacticalRadarActive(true) }
        .onDisappear { location?.setTacticalRadarActive(false) }
    }
}
