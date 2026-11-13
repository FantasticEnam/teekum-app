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
    var bloomRotation: Angle = .zero
    var members: [Member] = []
    var meetingPoint: MeetingPoint?
    var location: LocationPin?
    var heading: Double = 0
    var selectedTarget: Target?
    var isUserSOSActive = false
    var onSelectMember: (Member) -> Void = { _ in }
    var onSelectMeetingPoint: (MeetingPoint.ID) -> Void = { _ in }
    
    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let baseSize = min(size.width, size.height)
            let outerRadius = baseSize * 1.55 / 2
            let markerRadius = Double(baseSize * 0.42)
            
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
                    
                    OrbitBloomView(
                        radius: outerRadius,
                        rotation: bloomRotation
                    )
                    
                    OrbitUserMarkerView(color: userColor, heading: .degrees(0), isEmergency: isUserSOSActive)
                        .allowsHitTesting(false)

                    if let location {
                        ForEach(members) { member in
                            if let coordinate = member.coordinate {
                                let projection = OrbitProjection(from: location, to: coordinate, heading: heading, radius: markerRadius)
                                let isSelected = selectedTarget == .member(member.id)
                                if isSelected {
                                    targetLine(to: projection, in: size)
                                }
                                memberMarker(member, projection: projection, isSelected: isSelected)
                            }
                        }

                        if let meetingPoint {
                            let projection = OrbitProjection(from: location, to: meetingPoint.coordinate, heading: heading, radius: markerRadius)
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
        }
        .background(.black)
    }

    private func memberMarker(_ member: Member, projection: OrbitProjection, isSelected: Bool) -> some View {
        let isStale = member.measurementTimestamp.map { Date.now.timeIntervalSince($0) > 30 } ?? true
        return Button { onSelectMember(member) } label: {
            OrbitMemberMarkerView(initials: member.initials,
                color: member.color.swiftUIColor, isSelected: isSelected,
                isEmergency: member.isEmergency)
                .overlay(alignment: .bottom) { distanceLabel(projection).offset(y: 18) }
                .opacity(isStale && !isSelected && !member.isEmergency ? 0.5 : 1)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Find \(member.initials), \(projection.distance.formattedDistance())")
        .accessibilityValue(member.isEmergency ? Text("SOS active") : Text(""))
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

    private func targetLine(to projection: OrbitProjection, in size: CGSize) -> some View {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        return Path { path in
            path.move(to: center)
            path.addLine(to: CGPoint(x: center.x + projection.x, y: center.y + projection.y))
        }
        .stroke(Color.yellowProfile, style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
        .frame(width: size.width, height: size.height)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .zIndex(-1)
    }
}

#Preview {
    let store = SessionStore.preview
    OrbitSceneView(userColor: .yellowProfile, members: store.members, meetingPoint: store.activeMeetingPoint,
        location: LocationPin(coordinate: .init(latitude: -6.1988, longitude: 106.8225), horizontalAccuracy: 5),
        selectedTarget: .member("ADI"))
}
