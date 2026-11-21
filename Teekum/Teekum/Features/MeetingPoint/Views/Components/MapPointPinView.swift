//
//  MapPointPinView.swift
//  Teekum
//
//  Created by Adiat Rahman on 06/11/26.
//

import SwiftUI

public struct MapPointPinView: View {
    public var title: String
    public var confirmedMembers: [String]
    public var rejectedMembers: [String]
    public var showsInfo: Bool
    public var onTapPin: (() -> Void)?
    
    @State private var isShowingStatusCard: Bool = false
    
    public init(
        title: String = "Meeting Point",
        confirmedMembers: [String] = [],
        rejectedMembers: [String] = [],
        showsInfo: Bool = false,
        onTapPin: (() -> Void)? = nil
    ) {
        self.title = title
        self.confirmedMembers = confirmedMembers
        self.rejectedMembers = rejectedMembers
        self.showsInfo = showsInfo
        self.onTapPin = onTapPin
    }
    
    public var body: some View {
        VStack(spacing: 3) {
            HStack(spacing: 6) {
                // Title Bubble & Arrow Pointer
                VStack(spacing: -3) {
                    Text(title)
                        .font(.custom("Helvetica", size: 14).weight(.bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Color.buttonPrimary)
                        .clipShape(Capsule())
                    
                    Image(systemName: "arrowtriangle.down.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.buttonPrimary)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if showsInfo {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            isShowingStatusCard.toggle()
                        }
                    }
                }
                
                // Info Circle Button
                if showsInfo {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            isShowingStatusCard.toggle()
                        }
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Toggle attendance status")
                }
            }
            
            // Pin Icon (tappable for RSVP / Stop action)
            Image(systemName: "mappin.and.ellipse")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .shadow(color: .black.opacity(0.1), radius: 3)
                .contentShape(Rectangle())
                .onTapGesture {
                    onTapPin?()
                }
        }
        .overlay(alignment: .topTrailing) {
            if isShowingStatusCard {
                statusCard
                    .offset(y: -140)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.85, anchor: .bottomTrailing).combined(with: .opacity),
                        removal: .scale(scale: 0.85, anchor: .bottomTrailing).combined(with: .opacity)
                    ))
            }
        }
    }
    
    private var statusCard: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 12) {
                if !confirmedMembers.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Confirmed:")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color(red: 0.65, green: 0.82, blue: 0.95))
                        
                        ForEach(confirmedMembers, id: \.self) { initials in
                            Text(initials)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                }
                
                if !rejectedMembers.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Rejected:")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color(red: 0.65, green: 0.82, blue: 0.95))
                        
                        ForEach(rejectedMembers, id: \.self) { initials in
                            Text(initials)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                }
                
                if confirmedMembers.isEmpty && rejectedMembers.isEmpty {
                    Text("No responses yet")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .frame(width: 140, height: 130)
        .background(Color(red: 0.16, green: 0.18, blue: 0.20).opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.4), radius: 10, x: 0, y: 4)
        .contentShape(Rectangle())
        .scrollIndicators(.visible)
    }
}

#Preview("Crowded List (Scrollable)") {
    ZStack {
        Color.black.ignoresSafeArea()
        MapPointPinView(
            title: "VAN's Meeting Point",
            confirmedMembers: ["ADY", "NIC", "DIM", "HAS", "VAN", "RAF", "KEN", "LEO"],
            rejectedMembers: ["AYU", "SIT", "BUD"],
            showsInfo: true
        )
    }
}
