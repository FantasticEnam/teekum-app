//
//  ProfilePickerView.swift
//  Teekum
//
//  Created by Ari Hasan on 05/11/26.
//

import SwiftUI

struct ProfilePickerView: View {
    @Binding var selectedColor: PairingProfileColor

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                ForEach(PairingProfileColor.allCases) { swatch in
                    Button {
                        selectedColor = swatch
                    } label: {
                        Circle()
                            .fill(swatch.color)
                            .shadow(color: swatch.color.opacity(0.6), radius: 4)
                            .frame(width: 40, height: 40)
                            .overlay {
                                if selectedColor == swatch {
                                    Circle().strokeBorder(.white, lineWidth: 2)
                                }
                            }
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel(Text(swatch.rawValue.capitalized))
                    .accessibilityAddTraits(selectedColor == swatch ? .isSelected : [])
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 15)
        }
        .buttonStyle(.plain)
        .background(alignment: .top) {
            RoundedRectangle(cornerRadius: 13)
                .fill(Color(white: 0.17))
                .overlay(alignment: .top) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(white: 0.17))
                        .frame(width: 22, height: 22)
                        .rotationEffect(.degrees(45))
                        .offset(y: -7)
                }
        }
        .padding(.top, 15)
    }
}

#Preview {
    @Previewable @State var color = PairingProfileColor.yellow

    ProfilePickerView(selectedColor: $color)
        .frame(width: 318)
        .padding()
        .background(.black)
}
