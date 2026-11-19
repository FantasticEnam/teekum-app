//
//  OrbitMarkerGroupView.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 19/11/26.
//

import SwiftUI

struct OrbitMarkerGroupView: View {
    let group: OrbitMarkerGroup
    let canvasSize: CGSize
    let topInset: CGFloat
    let markerSize: CGFloat
    let isExpanded: Bool
    let selectedTarget: OrbitSceneView.Target?
    let onToggle: () -> Void
    let onSelectMember: (Member.ID) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var targetSize: CGFloat { max(44, markerSize + 8) }
    private var headerBottom: CGFloat { topInset + 60 }

    var body: some View {
        let arrowTop = OrbitUserMarkerView.arrowTopOffset(isTargetSelected: selectedTarget != nil)
        let offset = group.badgeOffset(clearingLocalMarkerBy: markerSize + 4, above: arrowTop + targetSize / 2)
        let rowHeight = targetSize + 12
        let rowWidth = max(1, min(canvasSize.width - 24, (targetSize + 6) * CGFloat(group.markers.count) + 6))
        let rowLimit = max(0, (canvasSize.width - rowWidth) / 2 - 12)
        let separation = targetSize / 2 + rowHeight / 2 + 14
        let opensAbove = canvasSize.height / 2 + offset.y - separation - rowHeight / 2 >= headerBottom
        let hasSOS = group.markers.contains { $0.member.isEmergency }

        ZStack {
            Button(action: onToggle) {
                Text("+\(group.markers.count)")
                    .font(.caption.bold())
                    .foregroundStyle(.black)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(width: markerSize, height: markerSize)
                    .background(Color.buttonPrimary, in: .circle)
                    .background {
                        Circle()
                            .strokeBorder(hasSOS ? Color.alertRedFire : Color.buttonPrimary, lineWidth: 1.5)
                            .padding(-4)
                    }
                    .overlay(alignment: .top) {
                        Image(systemName: "location.north.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white)
                            .rotationEffect(.degrees(isExpanded && opensAbove ? 180 : 0))
                            .offset(y: -15)
                            .accessibilityHidden(true)
                    }
                    .frame(width: targetSize, height: targetSize)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(group.markers.count) overlapping friends")
            .accessibilityValue(hasSOS ? Text("SOS active in group") : Text(""))
            .accessibilityHint(isExpanded ? Text("Hide friends") : Text("Show friends to follow"))
            .offset(x: offset.x, y: offset.y)

            if isExpanded {
                choices
                    .frame(width: rowWidth, height: rowHeight)
                    .background(Color.blackCard, in: .capsule)
                    .overlay { Capsule().strokeBorder(.white.opacity(0.18)) }
                    .accessibilityAction(.escape, onToggle)
                    .offset(
                        x: min(max(offset.x, -rowLimit), rowLimit),
                        y: offset.y + (opensAbove ? -separation : separation)
                    )
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .offset(y: opensAbove ? 12 : -12)))
            }
        }
        .frame(width: canvasSize.width, height: canvasSize.height)
    }

    private var choices: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                ForEach(group.markers.map(\.member)) { member in
                    let isSelected = selectedTarget == .member(member.id)
                    Button {
                        onSelectMember(member.id)
                    } label: {
                        OrbitMemberMarkerView(initials: member.initials, color: member.color.swiftUIColor,
                            isSelected: isSelected, isEmergency: member.isEmergency)
                            .frame(width: targetSize, height: targetSize)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Member \(member.initials)")
                    .accessibilityValue(member.isEmergency ? Text("SOS active") : Text(""))
                    .accessibilityHint(isSelected ? Text("Stop following") : Text("Follow"))
                }
            }
            .padding(6)
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
    }
}

#Preview("Expandable +4 marker") {
    @Previewable @State var isExpanded = true
    @Previewable @State var selectedTarget: OrbitSceneView.Target?
    let canvas = CGSize(width: 320, height: 300)
    let projection = OrbitProjection(distance: 5, bearing: 225, heading: 0, radius: 150, range: 15)
    let members = [
        Member(id: "ADI", color: .apricot),
        Member(id: "AIR", color: .sandrift),
        Member(id: "AYU", color: .greenishTeal),
        Member(id: "NIC", isEmergency: true, color: .yellow)
    ]
    let group = OrbitMarkerGroup(id: members[0].id, markers: members.map { ($0, projection) })

    OrbitMarkerGroupView(group: group, canvasSize: canvas, topInset: 0, markerSize: 36,
        isExpanded: isExpanded, selectedTarget: selectedTarget, onToggle: {
            withAnimation(.smooth(duration: 0.3)) { isExpanded.toggle() }
        }, onSelectMember: { selectedTarget = .member($0) })
        .background(Color.blackCard)
        .preferredColorScheme(.dark)
}
