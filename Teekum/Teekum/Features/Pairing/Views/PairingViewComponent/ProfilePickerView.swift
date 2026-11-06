//
//  ProfilePickerView.swift
//  Teekum
//
//  Created by Ari Hasan on 05/11/26.
//

import SwiftUI

struct ProfilePickerView: View {
    @Binding var selectedColor: Color

    private let colors: [(name: LocalizedStringKey, color: Color)] = [
        ("Red", .redProfile), ("Peach", .peachProfile),
        ("Orange", .orangeProfile), ("Cream", .creamProfile),
        ("Gray", .greyProfile), ("White", .whiteProfile),
        ("Blue", .blueProfile), ("Green", .greenProfile),
        ("Yellow", .yellowProfile)
    ]

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                ForEach(colors.indices, id: \.self) { index in
                    let swatch = colors[index]
                    Button {
                        selectedColor = swatch.color
                    } label: {
                        Circle()
                            .fill(swatch.color)
                            .shadow(color: swatch.color.opacity(0.6), radius: 4)
                            .frame(width: 40, height: 40)
                            .overlay {
                                if selectedColor == swatch.color {
                                    Circle().strokeBorder(.white, lineWidth: 2)
                                }
                            }
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel(Text(swatch.name))
                    .accessibilityAddTraits(selectedColor == swatch.color ? .isSelected : [])
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
    @Previewable @State var color = Color.yellowProfile

    ProfilePickerView(selectedColor: $color)
        .frame(width: 318)
        .padding()
        .background(.black)
}
