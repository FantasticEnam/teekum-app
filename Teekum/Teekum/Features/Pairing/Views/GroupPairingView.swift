//
//  GroupPairingView.swift
//  Teekum
//
//  Created by Ari Hasan on 02/11/26.
//

import SwiftUI

struct GroupPairingView: View {
    @State private var viewModel: PairingViewModel
    @State private var isShowingAgreement = false
    @State private var isProfilePickerVisible = false
    @FocusState private var focusedField: PairingField?

    init(sessionStore: SessionStore) {
        _viewModel = State(initialValue: PairingViewModel(sessionStore: sessionStore))
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    Text("ORBIT")
                        .font(.custom("Charter-Bold", size: 20, relativeTo: .title3))
                        .padding(.top, 10)
                        .padding(.bottom, 30)

                    GroupPairingProfileView(
                        profileColor: $viewModel.form.profileColor,
                        initials: $viewModel.form.initials,
                        isProfilePickerVisible: $isProfilePickerVisible,
                        focusedField: $focusedField
                    )
                        .padding(.bottom, 20)
                    
                    // Segmented Controls using Native Apple

                    Picker("Group action", selection: $viewModel.mode) {
                        Text("Create Group").tag(PairingMode.create)
                        Text("Join Group").tag(PairingMode.join)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .controlSize(.large)
                    .font(.custom("Charter-Bold", size: 14, relativeTo: .subheadline))
                    .frame(minHeight: 44)
                    .padding(.bottom, 24)

                    if viewModel.mode == .join {
                        Text("Align QR code in frame")
                            .font(.custom("Charter-Bold", size: 22, relativeTo: .title2))
                            .padding(.bottom, 10)
                        QRScannerView(isEnabled: viewModel.form.hasValidInitials && !isShowingAgreement)
                    } else if viewModel.isShowingQR {
                        GroupQRCodeView(sessionName: viewModel.form.trimmedSessionName)
                    } else {
                        Text("Group Name")
                            .font(.custom("Charter-Black", size: 22, relativeTo: .title2))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.bottom, 10)
                        GroupNameField(
                            groupName: $viewModel.form.sessionName,
                            focusedField: $focusedField
                        )
                    }

                    Spacer(minLength: 28)

                    PrimaryButtonView(
                        title: viewModel.mode == .join ? "Join Group" :
                            (viewModel.isShowingQR ? "Create Group" : "Generate QR"),
                        action: performPrimaryAction
                    )
                    .disabled(!viewModel.canPerformPrimaryAction)
                    .opacity(
                        viewModel.canPerformPrimaryAction ? 1 : 0.9
                    )

                }
                .frame(maxWidth: 400, minHeight: geometry.size.height)
                .padding(.horizontal, 42)
                .frame(maxWidth: .infinity)
                .background {
                    Color.clear
                        .contentShape(.rect)
                        .onTapGesture(perform: dismissEditing)
                }
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .background {
            Color.black
                .ignoresSafeArea()
                .onTapGesture(perform: dismissEditing)
        }
        .preferredColorScheme(.dark)
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: viewModel.mode, dismissEditing)
        .onChange(of: focusedField) {
            if focusedField != nil { isProfilePickerVisible = false }
        }
        .navigationDestination(isPresented: $isShowingAgreement) {
            AgreementView(
                form: viewModel.form,
                mode: viewModel.mode,
                onAgree: viewModel.activateLocalSession
            )
            .navigationTitle("Group Agreement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.visible, for: .navigationBar)
        }
    }

    private func performPrimaryAction() {
        guard viewModel.canPerformPrimaryAction else { return }
        dismissEditing()
        if viewModel.mode == .join || viewModel.isShowingQR {
            isShowingAgreement = true
        } else {
            viewModel.showQRPreview()
        }
    }

    private func dismissEditing() {
        focusedField = nil
        isProfilePickerVisible = false
    }
}

#Preview {
    NavigationStack {
        GroupPairingView(sessionStore: SessionStore())
    }
}
