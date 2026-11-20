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
    let userNickname: String
    var userBatteryLevel: Float?
    var members: [Member] = []
    var meetingPoint: MeetingPoint?
    var location: LocationPin?
    var nearbyPositions: [Member.ID: NearbyOrbitPosition] = [:]
    var heading: Double = 0
    var selectedTarget: Target?
    var isUserSOSActive = false
    var onSelectMeetingPoint: (MeetingPoint.ID) -> Void = { _ in }
    var onSelectMember: (Member.ID) -> Void = { _ in }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .caption) private var markerSize: CGFloat = 36
    @State private var expandedGroupID: Member.ID?
    @State private var zoom = 1.0
    @GestureState private var pinchZoom: Double?

    private var radarRange: Double {
        OrbitRingScale.defaultRange / (pinchZoom ?? zoom)
    }

    var body: some View {
        GeometryReader { geometry in
            radar(topInset: geometry.safeAreaInsets.top, bottomInset: geometry.safeAreaInsets.bottom)
                .ignoresSafeArea()
        }
        .background(.black)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Orbit radar")
        .accessibilityValue("Scale \(radarRange.formattedDistance())")
        .accessibilityAction(named: Text("Zoom in")) { zoom = boundedZoom(zoom * 1.25) }
        .accessibilityAction(named: Text("Zoom out")) { zoom = boundedZoom(zoom / 1.25) }
    }

    private func radar(topInset: CGFloat, bottomInset: CGFloat) -> some View {
        GeometryReader { geometry in
            let size = geometry.size
            let baseSize = min(size.width, size.height)
            // Reserve space below the rings for their labels and the bottom controls.
            let referenceRadius = min(baseSize * 1.55 / 2,
                max(1, size.height / 2 - bottomInset - OrbitFriendsPanel.height - 22))
            let backgroundRadius = referenceRadius * 1.12
            let scale = OrbitRingScale(range: radarRange, radius: referenceRadius)
            let markerRadius = scale.outerRadius
            let range = scale.outerDistance
            let groups = markerGroups(radius: markerRadius, range: range)
            let expandedGroup = groups.first { $0.id == expandedGroupID && $0.markers.count > 1 }
            let userMarker = OrbitUserMarkerView(color: userColor, nickname: userNickname, heading: .degrees(0),
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
            .onTapGesture { expandGroup(nil) }
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
                    
                    ForEach(groups) { group in
                        let isExpanded = expandedGroup?.id == group.id
                        let selected = group.markers.first { selectedTarget == .member($0.member.id) }
                        if let selected {
                            targetLine(to: selected.projection, in: size, isEmergency: selected.member.isEmergency)
                        }
                        if group.markers.count > 1 {
                            OrbitMarkerGroupView(group: group, canvasSize: size, topInset: topInset, markerSize: markerSize,
                                isExpanded: isExpanded, selectedTarget: selectedTarget, onToggle: {
                                    expandGroup(isExpanded ? nil : group.id)
                                }, onSelectMember: selectMember)
                                .zIndex(isExpanded ? 4 : (selected == nil ? 0 : 2))
                        } else if let marker = group.markers.first {
                            memberMarker(marker.member, projection: marker.projection, isSelected: selected != nil)
                        }
                    }

                    if let location, let meetingPoint {
                        let projection = OrbitProjection(from: location, to: meetingPoint.coordinate, heading: heading,
                            radius: markerRadius, range: range)
                        let isSelected = selectedTarget == .meetingPoint(meetingPoint.id)
                        if isSelected {
                            targetLine(to: projection, in: size)
                        }
                        meetingMarker(meetingPoint, projection: projection, isSelected: isSelected)
                    }

                    userMarker.allowsHitTesting(false).zIndex(3)
                }
                .frame(width: size.width, height: size.height)
            }
            .clipped()
            .contentShape(.rect)
            .onChange(of: expandedGroup?.id) { _, id in
                if id == nil { expandedGroupID = nil }
            }
            .simultaneousGesture(
                MagnifyGesture()
                    .updating($pinchZoom) { value, liveZoom, _ in
                        liveZoom = boundedZoom(zoom * Double(value.magnification))
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

    private func markerGroups(radius: Double, range: Double) -> [OrbitMarkerGroup] {
        let now = ContinuousClock.now
        let markers: [OrbitMarkerGroup.Marker] = members.compactMap { member in
            guard let projection = OrbitProjection(member: member, nearby: nearbyPositions[member.id],
                from: location, heading: heading, radius: radius, range: range, at: now) else { return nil }
            return (member, projection)
        }
        return OrbitMarkerGroup.make(from: markers, overlapDistance: markerSize)
    }

    private func expandGroup(_ id: Member.ID?) {
        guard expandedGroupID != id else { return }
        withAnimation(reduceMotion ? .easeInOut(duration: 0.18) : .smooth(duration: 0.3)) {
            expandedGroupID = id
        }
    }

    private func selectMember(_ id: Member.ID) {
        expandGroup(nil)
        onSelectMember(id)
    }
    
    private func memberMarker(_ member: Member, projection: OrbitProjection, isSelected: Bool) -> some View {
        let isStale = !projection.isNearby && (member.measurementTimestamp.map { Date.now.timeIntervalSince($0) > 30 } ?? true)
        let lowBatteryPercentage = OrbitBatteryIndicatorView.percentage(for: member.batteryLevel)
        return Button {
            selectMember(member.id)
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
        Button {
            expandGroup(nil)
            onSelectMeetingPoint(point.id)
        } label: {
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
        userNickname: "VAN",
        members: [
            Member(id: "NIC", coordinate: .init(latitude: 0.00008, longitude: -0.00003), batteryLevel: 0.1,
                   heading: 315, color: .greenishTeal, measurementTimestamp: .now),
            Member(id: "ADI", coordinate: .init(latitude: -0.00064, longitude: 0.00002),
                   heading: 180, color: .apricot, measurementTimestamp: .now)
        ],
        location: location
    )
}

#Preview("Nickname above overlapping friends") {
    let location = LocationPin(coordinate: .init(latitude: 0, longitude: 0), horizontalAccuracy: 5)
    OrbitSceneView(
        userColor: MemberColor.sandrift.swiftUIColor,
        userNickname: "VAN",
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
        userNickname: store.activeSession?.localMemberName ?? "",
        members: store.members,
        meetingPoint: store.activeMeetingPoint,
        location: LocationPin(coordinate: .init(latitude: -6.1988, longitude: 106.8225), horizontalAccuracy: 5),
        selectedTarget: .member("ADI")
    )
}

#Preview("Selectable overlapping friends") {
    @Previewable @State var selectedTarget: OrbitSceneView.Target?
    let location = LocationPin(coordinate: .init(latitude: 0, longitude: 0), horizontalAccuracy: 5)
    let sharedCoordinate = CLLocationCoordinate2D(latitude: -0.00004, longitude: -0.00007)
    OrbitSceneView(
        userColor: .purpleProfile,
        userNickname: "VAN",
        members: [
            Member(id: "AIR", coordinate: sharedCoordinate, color: .apricot, measurementTimestamp: .now),
            Member(id: "AYU", coordinate: sharedCoordinate, color: .greenishTeal, measurementTimestamp: .now),
            Member(id: "NIC", coordinate: sharedCoordinate, color: .yellow, measurementTimestamp: .now),
            Member(id: "ADI", coordinate: sharedCoordinate, color: .sandrift, measurementTimestamp: .now)
        ],
        location: location,
        selectedTarget: selectedTarget,
        onSelectMember: { selectedTarget = .member($0) }
    )
}

#Preview("Nearby markers without GPS") {
    OrbitSceneView(userColor: .purpleProfile, userNickname: "DAF",
        members: [Member(id: "AYU", color: .greenishTeal), Member(id: "NIC", color: .apricot)],
        nearbyPositions: [
            "AYU": NearbyOrbitPosition(distance: 2.4, bearing: 35, measuredAt: .now),
            "NIC": NearbyOrbitPosition(distance: 4.8, bearing: -20, measuredAt: .now)
        ])
        .preferredColorScheme(.dark)
}

#Preview("Marker grouping during zoom and rotation") {
    @Previewable @State var heading = 0.0
    let location = LocationPin(coordinate: .init(latitude: 0, longitude: 0), horizontalAccuracy: 5)

    OrbitSceneView(
        userColor: .purpleProfile,
        userNickname: "AIR",
        members: [
            Member(id: "AYU", coordinate: .init(latitude: 0.000025, longitude: 0.000018),
                heading: 0, color: .greenishTeal, measurementTimestamp: .now),
            Member(id: "DAF", coordinate: .init(latitude: 0.000025, longitude: 0.000031),
                heading: 45, color: .sandrift, measurementTimestamp: .now)
        ],
        location: location,
        heading: heading
    )
    .safeAreaInset(edge: .bottom) {
        Slider(value: $heading, in: 0...360) {
            Text("Heading")
        }
        .padding()
    }
    .preferredColorScheme(.dark)
}

#Preview("2. Friend SOS Active (Red)") {
    let store = SessionStore.preview
    var sosMembers = store.members
    if let index = sosMembers.firstIndex(where: { $0.id == "ADI" }) {
        sosMembers[index].isEmergency = true
    }
    
    return OrbitSceneView(
        userColor: .yellowProfile,
        userNickname: store.activeSession?.localMemberName ?? "",
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
        userNickname: store.activeSession?.localMemberName ?? "",
        members: store.members,
        meetingPoint: store.activeMeetingPoint,
        location: LocationPin(coordinate: .init(latitude: -6.1988, longitude: 106.8225), horizontalAccuracy: 5),
        isUserSOSActive: true // Titik tengah user sendiri berwarna merah
    )
}
