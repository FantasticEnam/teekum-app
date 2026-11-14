//
//  GroupNameField.swift
//  Teekum
//
//  Created by Ari Hasan on 05/11/26.
//

import SwiftUI

struct GroupNameField: View {
    @Binding var groupName: String
    var focusedField: FocusState<PairingField?>.Binding
    @State private var isHovered = false

    private var isFocused: Bool {
        focusedField.wrappedValue == .groupName
    }
    
    var body: some View {
        VStack{
            TextField(
                "GroupName",
                text: $groupName,
                prompt: Text(isFocused || isHovered ? "" : "Enter your group name...").foregroundStyle(.white.opacity(0.3))
            )
            .focused(focusedField, equals: .groupName)
            .submitLabel(.done)
            .onSubmit { focusedField.wrappedValue = nil }
            .textFieldStyle(.plain)
            .font(.custom("Futura", size: 16, relativeTo: .body))
            .foregroundStyle(.white)
            .textInputAutocapitalization(.words)
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .frame(minHeight: 54)
            .background(Color(white: 0.17), in: RoundedRectangle(cornerRadius: 17))
            .onHover { isHovered = $0 }
        }
        
    }
}

#Preview("Group Name") {
    @Previewable @State var groupName = ""
    @Previewable @FocusState var focusedField: PairingField?

    GroupNameField(groupName: $groupName, focusedField: $focusedField)
        .padding(24)
        .background(.black)
        .preferredColorScheme(.dark)
}
