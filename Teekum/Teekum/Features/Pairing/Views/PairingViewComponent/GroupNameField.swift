//
//  GroupNameField.swift
//  Teekum
//
//  Created by Ari Hasan on 05/11/26.
//

import SwiftUI

struct GroupNameField: View {
    @Binding var groupName: String
    
    var body: some View {
        VStack{
            TextField(
                "GroupName",
                text: $groupName,
                prompt: Text("....").foregroundStyle(Color.white)
            )
            .textFieldStyle(.plain)
            .font(.custom("Charter-Roman", size: 16, relativeTo: .body))
            .foregroundStyle(.white)
            .textInputAutocapitalization(.words)
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .frame(minHeight: 54)
            .background(Color(white: 0.17), in: RoundedRectangle(cornerRadius: 17))
        }
        
    }
}

#Preview("Group Name") {
    @Previewable @State var groupName = ""

    GroupNameField(groupName: $groupName)
        .padding(24)
        .background(.black)
        .preferredColorScheme(.dark)
}
