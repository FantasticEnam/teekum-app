//
//  GroupPairingView.swift
//  Teekum
//
//  Created by Ari Hasan on 02/11/26.
//

import SwiftUI

struct GroupPairingView: View {
    @State private var isCreatingGroup = true
    @State private var groupName = ""

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    Text("ORBIT")
                        .font(.custom("Charter-Bold", size: 20, relativeTo: .title3))
                        .padding(.top, 10)
                        .padding(.bottom, 30)

                    GroupPairingProfileView()
                        .padding(.bottom, 30)
                    
                    // Segmented Controls using Native Apple

                    Picker("Group action", selection: $isCreatingGroup) {
                        Text("Create Group").tag(true)
                        Text("Join Group").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .controlSize(.large)
                    .font(.custom("Charter-Bold", size: 14, relativeTo: .subheadline))
                    .frame(minHeight: 44)
                    .padding(.bottom, 24)

                    // Text Field Group Name
                    HStack {
                        Text("Group Name")
                            .font(.custom("Charter-Black", size: 22, relativeTo: .title2))
                            .bold()
                            .padding(.bottom, 10)
                            .padding(.leading, 5)
                        Spacer()
                    }
                    
                    GroupNameField(groupName: $groupName)

                    Spacer(minLength: 28)

                    PrimaryButtonView(
                        title: "Generate QR",
                        action: createQRAction
                    )
                }
                .frame(maxWidth: 400, minHeight: geometry.size.height)
                .padding(.horizontal, 42)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .background(.black)
        .preferredColorScheme(.dark)
    }

    private func performPrimaryAction() {
        // UI only. Group creation and joining will be connected separately.
    }
    
    private func createQRAction() {
        // Will be creating a QR CODE when user tap it
    }
}

#Preview {
    GroupPairingView()
}
