//
//  SOSStatusDropdownView.swift
//  Teekum
//
//  Created by Adiat Rahman on 20/11/26.
//

import SwiftUI

public struct SOSStatusDropdownView: View {
    public let onTheirWay: [String]
    public let cantGoNow: [String]
    
    @State private var isExpanded: Bool = false
    
    public init(onTheirWay: [String] = [], cantGoNow: [String] = [], initiallyExpanded: Bool = false) {
        self.onTheirWay = onTheirWay
        self.cantGoNow = cantGoNow
        self._isExpanded = State(initialValue: initiallyExpanded)
    }
    
    public var body: some View {
        VStack(spacing: 8) {
            // Header button (toggles dropdown)
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Text("Help is on their way")
                        .font(.custom("Helvetica", size: 14).weight(.bold))
                        .foregroundStyle(.white)
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Toggle helper status dropdown")
            
            if isExpanded {
                // Divider line
                Rectangle()
                    .fill(Color.white.opacity(0.2))
                    .frame(height: 1)
                    .padding(.horizontal, 4)
                
                // Scrollable helper response list
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 14) {
                        // 1. On their way section
                        VStack(alignment: .leading, spacing: 4) {
                            Text("On their way:")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Color(red: 0.96, green: 0.78, blue: 0.25))
                            
                            if !onTheirWay.isEmpty {
                                ForEach(onTheirWay, id: \.self) { initials in
                                    Text(initials)
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                            } else {
                                Text("-")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                        }
                        
                        // 2. Can't go now section
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Can’t go now:")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Color(red: 0.96, green: 0.78, blue: 0.25))
                            
                            if !cantGoNow.isEmpty {
                                ForEach(cantGoNow, id: \.self) { initials in
                                    Text(initials)
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                            } else {
                                Text("-")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
                    .padding(.top, 4)
                    .padding(.bottom, 6)
                }
                .frame(maxHeight: 140)
                .contentShape(Rectangle())
                .scrollIndicators(.visible)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, isExpanded ? 14 : 10)
        .background(Color(red: 0.60, green: 0.08, blue: 0.08).opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: isExpanded ? 18 : 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: isExpanded ? 18 : 20, style: .continuous)
                .stroke(Color.white.opacity(0.15), lineWidth: 0.8)
        )
        .shadow(color: .black.opacity(0.35), radius: 10, x: 0, y: 4)
        .fixedSize(horizontal: !isExpanded, vertical: true)
        .frame(width: isExpanded ? 200 : nil)
    }
}

#Preview("Collapsed") {
    ZStack {
        Color.black.ignoresSafeArea()
        SOSStatusDropdownView(
            onTheirWay: ["ADY", "NIC"],
            cantGoNow: ["AYU"],
            initiallyExpanded: false
        )
    }
}

#Preview("Expanded") {
    ZStack {
        Color.black.ignoresSafeArea()
        SOSStatusDropdownView(
            onTheirWay: ["ADY", "NIC"],
            cantGoNow: ["AYU"],
            initiallyExpanded: true
        )
    }
}

#Preview("Expanded Crowded (Scrollable)") {
    ZStack {
        Color.black.ignoresSafeArea()
        SOSStatusDropdownView(
            onTheirWay: ["ADY", "NIC", "DIM", "HAS", "VAN", "KEN"],
            cantGoNow: ["AYU", "SIT", "BUD", "RAF"],
            initiallyExpanded: true
        )
    }
}
