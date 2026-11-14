//
//  OrbitSceneView.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 05/11/26.
//

import SwiftUI
import CoreLocation

struct OrbitSceneView: View {
    enum Target: Equatable {
        case member(Member.ID)
        case meetingPoint(MeetingPoint.ID)
    }

    let userColor: Color
    var members: [Member] = []
    var meetingPoint: MeetingPoint?
    var location: LocationPin?
    var heading: Double = 0
    var selectedTarget: Target?
    var isUserSOSActive = false
    var onSelectMember: (Member) -> Void = { _ in }
    var onSelectMeetingPoint: (MeetingPoint.ID) -> Void = { _ in }

    @State private var zoom = 1.0
    @GestureState private var pinchMagnification = 1.0

    private var radarRange: Double {
        MeepoConfiguration.Navigation.tacticalRadarRangeMeters / boundedZoom(zoom * pinchMagnification)
    }
    
    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let baseSize = min(size.width, size.height)
            let outerRadius = baseSize * 1.55 / 2
            let markerRadius = Double(baseSize * 0.42)
            let range = radarRange
            
            RadialGradient(
                stops: [
                    .init(color: Color(hex: 0x131313), location: 0),
                    .init(color: Color(hex: 0x161616), location: 0.85),
                    .init(color: .black, location: 1)
                ],
                center: .center,
                startRadius: 0,
                endRadius: outerRadius * 1.12
            )
            .frame(width: size.width, height: size.height)
            .overlay {
                ZStack {
                    ForEach([0.55, 1.1, 1.55], id: \.self) { scale in
                        Circle()
                            .stroke(
                                .white.opacity(0.4),
                                lineWidth: 0.5
                            )
                            .frame(
                                width: baseSize * scale,
                                height: baseSize * scale
                            )
                    }
                    
                    OrbitUserMarkerView(color: userColor, heading: .degrees(0), isEmergency: isUserSOSActive, isTargetSelected: selectedTarget != nil)
                        .allowsHitTesting(false)

                    if let location {
                        ForEach(members) { member in
                            if let coordinate = member.coordinate {
                                let projection = OrbitProjection(from: location, to: coordinate, heading: heading,
                                    radius: markerRadius, range: range)
                                let isSelected = selectedTarget == .member(member.id)
                                if isSelected {
                                    targetLine(to: projection, in: size, isEmergency: member.isEmergency)
                                }
                                memberMarker(member, projection: projection, isSelected: isSelected)
                            }
                        }

                        if let meetingPoint {
                            let projection = OrbitProjection(from: location, to: meetingPoint.coordinate, heading: heading,
                                radius: markerRadius, range: range)
                            let isSelected = selectedTarget == .meetingPoint(meetingPoint.id)
                            if isSelected {
                                targetLine(to: projection, in: size)
                            }
                            meetingMarker(meetingPoint, projection: projection, isSelected: isSelected)
                        }
                    }
                }
            }
            .clipped()
            .contentShape(.rect)
            .simultaneousGesture(
                MagnifyGesture()
                    .updating($pinchMagnification) { value, magnification, _ in
                        magnification = Double(value.magnification)
                    }
                    .onEnded { value in
                        zoom = boundedZoom(zoom * Double(value.magnification))
                    }
            )
        }
        .background(.black)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Orbit radar")
        .accessibilityAction(named: Text("Zoom in")) { zoom = boundedZoom(zoom * 1.25) }
        .accessibilityAction(named: Text("Zoom out")) { zoom = boundedZoom(zoom / 1.25) }
    }

    private func boundedZoom(_ scale: Double) -> Double {
        min(max(scale, 0.5), 2)
    }

    private func memberMarker(_ member: Member, projection: OrbitProjection, isSelected: Bool) -> some View {
        let isStale = member.measurementTimestamp.map { Date.now.timeIntervalSince($0) > 30 } ?? true
        let lowBatteryPercentage = member.batteryLevel.flatMap { level in
            let threshold = Float(MeepoConfiguration.Battery.survivalThresholdPercent) / 100
            return (0...threshold).contains(level) ? level.formattedBatteryPercentage : nil
        }
        return Button { onSelectMember(member) } label: {
            OrbitMemberMarkerView(initials: member.initials,
                color: member.color.swiftUIColor, isSelected: isSelected,
                isEmergency: member.isEmergency, showsBloom: projection.isClamped,
                lowBatteryPercentage: lowBatteryPercentage)
                .overlay(alignment: .bottom) { distanceLabel(projection).offset(y: 18) }
                .opacity(isStale && !isSelected && !member.isEmergency ? 0.5 : 1)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Find \(member.initials), \(projection.distance.formattedDistance())")
        .accessibilityValue(member.isEmergency ? Text("SOS active") : Text(""))
        .accessibilityHint(lowBatteryPercentage.map { Text("Low battery, \($0)") } ?? Text(""))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .offset(x: projection.x, y: projection.y)
        .zIndex(isSelected ? 2 : 0)
    }

    private func meetingMarker(_ point: MeetingPoint, projection: OrbitProjection, isSelected: Bool) -> some View {
        Button { onSelectMeetingPoint(point.id) } label: {
            Image(.meetPoint)
                .resizable()
                .scaledToFit()
                .frame(width: 23, height: 34)
                .background {
                    if isSelected {
                        Circle()
                            .strokeBorder(Color.yellowProfile, lineWidth: 2)
                            .frame(width: 42, height: 42)
                    }
                }
                .overlay(alignment: .bottom) { distanceLabel(projection).offset(y: 18) }
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Meeting point, \(point.name), \(projection.distance.formattedDistance())")
        .accessibilityHint("Select as your radar target")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .offset(x: projection.x, y: projection.y)
        .zIndex(isSelected ? 2 : 1)
    }

    private func distanceLabel(_ projection: OrbitProjection) -> some View {
        Text("\(projection.isClamped ? "↗ " : "")\(projection.distance.formattedDistance())")
            .font(.caption2)
            .foregroundStyle(.white)
            .fixedSize()
    }

    private func targetLine(to projection: OrbitProjection, in size: CGSize, isEmergency: Bool = false) -> some View {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        return Path { path in
            path.move(to: center)
            path.addLine(to: CGPoint(x: center.x + projection.x, y: center.y + projection.y))
        }
        .stroke(isEmergency ? Color.alertRedFire : Color.yellowProfile, style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
        .frame(width: size.width, height: size.height)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .zIndex(-1)
    }
}

#Preview("Near and distant friends with low battery") {
    let location = LocationPin(coordinate: .init(latitude: 0, longitude: 0), horizontalAccuracy: 5)

    OrbitSceneView(
        userColor: .yellowProfile,
        members: [
            Member(id: "NIC", coordinate: .init(latitude: 0.00025, longitude: -0.0001), batteryLevel: 0.2,
                color: .greenishTeal, measurementTimestamp: .now),
            Member(id: "ADI", coordinate: .init(latitude: -0.0004, longitude: 0.0005),
                color: .apricot, measurementTimestamp: .now)
        ],
        location: location
    )
}

#Preview("1. Selected Normal (Kuning)") {
    let store = SessionStore.preview
    OrbitSceneView(
        userColor: .yellowProfile,
        members: store.members,
        meetingPoint: store.activeMeetingPoint,
        location: LocationPin(coordinate: .init(latitude: -6.1988, longitude: 106.8225), horizontalAccuracy: 5),
        selectedTarget: .member("ADI") // Kotak nama kuning, teks hitam, garis putus-putus kuning
    )
}

#Preview("2. Friend SOS Active (Merah)") {
    let store = SessionStore.preview
    var sosMembers = store.members
    if let index = sosMembers.firstIndex(where: { $0.id == "ADI" }) {
        sosMembers[index].isEmergency = true
    }

    return OrbitSceneView(
        userColor: .yellowProfile,
        members: sosMembers,
        meetingPoint: store.activeMeetingPoint,
        location: LocationPin(coordinate: .init(latitude: -6.1988, longitude: 106.8225), horizontalAccuracy: 5),
        selectedTarget: .member("ADI") // Kotak merah, teks putih (bukan hitam), panah merah
    )
}

#Preview("3. My SOS Active") {
    let store = SessionStore.preview
    OrbitSceneView(
        userColor: .yellowProfile,
        members: store.members,
        meetingPoint: store.activeMeetingPoint,
        location: LocationPin(coordinate: .init(latitude: -6.1988, longitude: 106.8225), horizontalAccuracy: 5),
        isUserSOSActive: true // Titik tengah user sendiri berwarna merah
    )
}
