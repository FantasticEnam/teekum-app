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
    var userBatteryLevel: Float?
    var members: [Member] = []
    var meetingPoint: MeetingPoint?
    var location: LocationPin?
    var heading: Double = 0
    var selectedTarget: Target?
    var isUserSOSActive = false
    var onSelectMeetingPoint: (MeetingPoint.ID) -> Void = { _ in }
    var onSelectMember: (Member.ID) -> Void = { _ in }

    @State private var zoom = 1.0
    @GestureState private var pinchMagnification = 1.0

    private var radarRange: Double {
        OrbitRingScale.defaultRange / boundedZoom(zoom * pinchMagnification)
    }

    var body: some View {
        GeometryReader { geometry in
            radar(bottomInset: geometry.safeAreaInsets.bottom)
                .ignoresSafeArea()
        }
        .background(.black)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Orbit radar")
        .accessibilityValue("Scale \(radarRange.formattedDistance())")
        .accessibilityAction(named: Text("Zoom in")) { zoom = boundedZoom(zoom * 1.25) }
        .accessibilityAction(named: Text("Zoom out")) { zoom = boundedZoom(zoom / 1.25) }
    }

    private func radar(bottomInset: CGFloat) -> some View {
        GeometryReader { geometry in
            let size = geometry.size
            let baseSize = min(size.width, size.height)
            // Reserve space below the rings for their labels and the bottom controls.
            let referenceRadius = min(baseSize * 1.55 / 2, max(1, size.height / 2 - bottomInset - 100))
            let backgroundRadius = referenceRadius * 1.12
            let scale = OrbitRingScale(range: radarRange, radius: referenceRadius)
            let markerRadius = scale.outerRadius
            let range = scale.outerDistance
            let userMarker = OrbitUserMarkerView(color: userColor, heading: .degrees(0),
                isEmergency: isUserSOSActive, isTargetSelected: selectedTarget != nil,
                batteryLevel: userBatteryLevel)
            
            RadialGradient(
                stops: [
                    .init(color: Color(hex: 0x131313), location: 0),
                    .init(color: Color(hex: 0x161616), location: 0.85),
                    .init(color: .black, location: 1)
                ],
                center: .center,
                startRadius: 0,
                endRadius: backgroundRadius
            )
            .frame(width: size.width, height: size.height)
            .overlay {
                ZStack {
                    OrbitDistanceRingsView(scale: scale)
                        .mask {
                            RadialGradient(
                                stops: [
                                    .init(color: .white, location: 0),
                                    .init(color: .white, location: 0.85),
                                    .init(color: .clear, location: 1)
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: backgroundRadius
                            )
                        }
                    
                    if let location {
                        ForEach(members) { member in
                            if let coordinate = member.coordinate {
                                let projection = OrbitProjection(from: location, to: coordinate, heading: heading,
                                                                 radius: markerRadius, range: range, overflowMargin: 20)
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
            .overlay { userMarker.allowsHitTesting(false) }
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
    }

    private func boundedZoom(_ scale: Double) -> Double {
        let baseRange = OrbitRingScale.defaultRange
        return min(max(scale, baseRange / 120), baseRange / 5)
    }
    
    private func memberMarker(_ member: Member, projection: OrbitProjection, isSelected: Bool) -> some View {
        let isStale = member.measurementTimestamp.map { Date.now.timeIntervalSince($0) > 30 } ?? true
        let lowBatteryPercentage = OrbitBatteryIndicatorView.percentage(for: member.batteryLevel)
        return Button {
            onSelectMember(member.id)
        } label: {
            OrbitMemberMarkerView(
                initials: member.initials,
                color: member.color.swiftUIColor,
                isSelected: isSelected,
                isEmergency: member.isEmergency,
                showsBloom: projection.isClamped,
                batteryLevel: member.batteryLevel,
                heading: member.heading.map { .degrees($0 - heading) }
            )
        }
        .buttonStyle(.plain)
        .opacity(isStale && !isSelected && !member.isEmergency ? 0.5 : 1)
        .frame(minWidth: 44, minHeight: 44)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Member \(member.initials), \(projection.distance.formattedDistance())")
        .accessibilityValue(member.isEmergency ? Text("SOS active") : member.heading.map {
            Text("Heading \($0, format: .number.precision(.fractionLength(0))) degrees")
        } ?? Text("Direction unavailable"))
        .accessibilityHint(lowBatteryPercentage.map { Text("Low battery, \($0)") } ?? Text(""))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .offset(x: projection.x, y: projection.y)
        .zIndex(isSelected ? 2 : 0)
    }
    
    private func meetingMarker(_ point: MeetingPoint, projection: OrbitProjection, isSelected: Bool) -> some View {
        Button { onSelectMeetingPoint(point.id) } label: {
            Image(.meetPoint)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(Color.buttonPrimary)
                .frame(width: 23, height: 34)
                .background {
                    if isSelected {
                        Circle()
                            .strokeBorder(Color.buttonPrimary, lineWidth: 2)
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
        .stroke(isEmergency ? Color.alertRedFire : Color.buttonPrimary, style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
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
            Member(id: "NIC", coordinate: .init(latitude: 0.00008, longitude: -0.00003), batteryLevel: 0.1,
                   heading: 315, color: .greenishTeal, measurementTimestamp: .now),
            Member(id: "ADI", coordinate: .init(latitude: -0.00064, longitude: 0.00002),
                   heading: 180, color: .apricot, measurementTimestamp: .now)
        ],
        location: location
    )
}

#Preview("YOU above overlapping friends") {
    let location = LocationPin(coordinate: .init(latitude: 0, longitude: 0), horizontalAccuracy: 5)
    OrbitSceneView(
        userColor: MemberColor.sandrift.swiftUIColor,
        members: [
            Member(id: "NIC", coordinate: .init(latitude: 0, longitude: 0.00004), heading: 240,
                color: .apricot, measurementTimestamp: .now),
            Member(id: "AYU", coordinate: .init(latitude: 0.00005, longitude: -0.00002), batteryLevel: 0.1,
                heading: 0, color: .yellow, measurementTimestamp: .now)
        ],
        location: location,
        selectedTarget: .member("NIC")
    )
}

#Preview("Selected friend") {
    let store = SessionStore.preview
    OrbitSceneView(
        userColor: .yellowProfile,
        members: store.members,
        meetingPoint: store.activeMeetingPoint,
        location: LocationPin(coordinate: .init(latitude: -6.1988, longitude: 106.8225), horizontalAccuracy: 5),
        selectedTarget: .member("ADI")
    )
}

#Preview("2. Friend SOS Active (Red)") {
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
        selectedTarget: .member("ADI")
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
