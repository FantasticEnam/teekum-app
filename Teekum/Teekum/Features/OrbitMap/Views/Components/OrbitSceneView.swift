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
    var onSelectMeetingPoint: (MeetingPoint.ID) -> Void = { _ in }
    var onSelectMember: (Member.ID) -> Void = { _ in }

    private static let ringDiameterScales = [0.55, 1.1, 1.55]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var zoom = 1.0
    @State private var isRulerVisible = false
    @GestureState private var pinchMagnification: Double?

    private var radarRange: Double {
        MeepoConfiguration.Navigation.tacticalRadarRangeMeters / boundedZoom(zoom * (pinchMagnification ?? 1))
    }

    var body: some View {
        GeometryReader { geometry in
            radar(bottomInset: geometry.safeAreaInsets.bottom)
                .ignoresSafeArea()
        }
        .background(.black)
        .task(id: pinchMagnification != nil) {
            if pinchMagnification != nil {
                isRulerVisible = true
            } else if isRulerVisible {
                do {
                    try await Task.sleep(for: .seconds(1.5))
                } catch {
                    return
                }
                withAnimation(.easeOut(duration: 0.25)) {
                    isRulerVisible = false
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Orbit radar")
        .accessibilityValue("Radius \(radarRange.formattedDistance())")
        .accessibilityAction(named: Text("Zoom in")) { zoom = boundedZoom(zoom * 1.25) }
        .accessibilityAction(named: Text("Zoom out")) { zoom = boundedZoom(zoom / 1.25) }
    }

    private func radar(bottomInset: CGFloat) -> some View {
        GeometryReader { geometry in
            let size = geometry.size
            let baseSize = min(size.width, size.height)
            let outerRadius = baseSize * 1.55 / 2
            let markerRadius = Double(baseSize * 0.42)
            let range = radarRange
            let userMarker = OrbitUserMarkerView(color: userColor, heading: .degrees(0),
                isEmergency: isUserSOSActive, isTargetSelected: selectedTarget != nil)
            
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
                    ForEach(Self.ringDiameterScales, id: \.self) { scale in
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
                    
                    userMarker.positionMarker
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
            .overlay { userMarker.directionArrow }
            .overlay(alignment: .bottomTrailing) {
                if isRulerVisible || pinchMagnification != nil, markerRadius > 0 {
                    let ringGap = baseSize * (Self.ringDiameterScales[1] - Self.ringDiameterScales[0]) / 2
                    let pointsPerMeter = OrbitProjection.screenPointsPerMeter(radius: markerRadius, range: range)
                    zoomRuler(maximumWidth: ringGap, pointsPerMeter: pointsPerMeter, range: range)
                        .padding(.trailing, 8)
                        .padding(.bottom, bottomInset + 82)
                        .transition(.opacity)
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
    }

    private func zoomRuler(maximumWidth: CGFloat, pointsPerMeter: Double, range: Double) -> some View {
        let scale = OrbitRulerScale(pointsPerMeter: pointsPerMeter, maximumWidth: maximumWidth)

        return VStack(alignment: .leading, spacing: 2) {
            Text(scale.distance.formattedDistance(spaced: false))
                .font(.caption.monospacedDigit())
                .frame(width: scale.width, alignment: .trailing)

            Rectangle()
                .frame(width: scale.width, height: 1)
                .overlay(alignment: .leading) {
                    Rectangle().frame(width: 1, height: 6).offset(y: 3)
                }
                .overlay {
                    Rectangle().frame(width: 1, height: 6).offset(y: -3)
                }
                .foregroundStyle(.white.opacity(0.55))
                .frame(height: 12)

            Text("Radius \(range.formattedDistance())")
                .font(.caption2.monospacedDigit())
        }
        .foregroundStyle(.white.opacity(0.75))
        .animation(reduceMotion ? nil : .interactiveSpring(response: 0.16, dampingFraction: 1), value: scale.width)
        .frame(width: maximumWidth, alignment: .leading)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
    
    private func boundedZoom(_ scale: Double) -> Double {
        let minimumRadius = 5.0
        let maximumZoom = MeepoConfiguration.Navigation.tacticalRadarRangeMeters / minimumRadius
        return min(max(scale, 0.5), maximumZoom)
    }
    
    private func memberMarker(_ member: Member, projection: OrbitProjection, isSelected: Bool) -> some View {
        let isStale = member.measurementTimestamp.map { Date.now.timeIntervalSince($0) > 30 } ?? true
        let lowBatteryPercentage = member.batteryLevel.flatMap { level in
            let threshold = Float(MeepoConfiguration.Battery.survivalThresholdPercent) / 100
            return (0...threshold).contains(level) ? level.formattedBatteryPercentage : nil
        }
        return Button {
            onSelectMember(member.id)
        } label: {
            OrbitMemberMarkerView(
                initials: member.initials,
                color: member.color.swiftUIColor,
                isSelected: isSelected,
                isEmergency: member.isEmergency,
                showsBloom: projection.isClamped,
                lowBatteryPercentage: lowBatteryPercentage
            )
            .overlay(alignment: .bottom) { distanceLabel(projection).offset(y: 18) }
        }
        .buttonStyle(.plain)
        .opacity(isStale && !isSelected && !member.isEmergency ? 0.5 : 1)
        .frame(minWidth: 44, minHeight: 44)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Member \(member.initials), \(projection.distance.formattedDistance())")
        .accessibilityValue(member.isEmergency ? Text("SOS active") : Text(""))
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
            Member(id: "NIC", coordinate: .init(latitude: 0.00025, longitude: -0.0001), batteryLevel: 0.2,
                   color: .greenishTeal, measurementTimestamp: .now),
            Member(id: "ADI", coordinate: .init(latitude: -0.0004, longitude: 0.0005),
                   color: .apricot, measurementTimestamp: .now)
        ],
        location: location
    )
}

#Preview("1. Selected Normal (Yellow)") {
    let store = SessionStore.preview
    OrbitSceneView(
        userColor: .yellowProfile,
        members: store.members,
        meetingPoint: store.activeMeetingPoint,
        location: LocationPin(coordinate: .init(latitude: -6.1988, longitude: 106.8225), horizontalAccuracy: 5),
        selectedTarget: .member("ADI") // Kotak nama kuning, teks hitam, garis putus-putus kuning
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
