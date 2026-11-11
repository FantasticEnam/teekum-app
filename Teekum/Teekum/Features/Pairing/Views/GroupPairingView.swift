//
//  GroupPairingView.swift
//  Teekum
//
//  Created by Ari Hasan on 02/11/26.
//

import SwiftUI

struct GroupPairingView: View {
    private let sessionStore: SessionStore
    @State private var viewModel: PairingViewModel
    @State private var isShowingAgreement = false
    @State private var isProfilePickerVisible = false
    @FocusState private var focusedField: PairingField?

    init(sessionStore: SessionStore, onActivate: (@MainActor (GroupSession) -> Void)? = nil) {
        self.sessionStore = sessionStore
        _viewModel = State(initialValue: PairingViewModel(sessionStore: sessionStore, onActivate: onActivate))
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    Text("meepo")
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
                        QRScannerView(
                            isEnabled: viewModel.form.hasValidInitials && !isShowingAgreement,
                            onCodeScanned: viewModel.handleScannedCode
                        )
                        TextField("Paste invite link or message", text: $viewModel.inviteText)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                            .submitLabel(.go)
                            .onSubmit(viewModel.useInviteLink)
                            .padding(.vertical, 12)
                        Button("Use Invite Link", action: viewModel.useInviteLink)
                            .foregroundStyle(Color.yellowProfile)
                            .frame(minHeight: 44)
                        if let invite = viewModel.scannedInvite {
                            Label(invite.sessionName, systemImage: "checkmark.circle")
                                .font(.subheadline)
                        }
                    } else if let session = viewModel.draftSession {
                        GroupQRCodeView(session: session)
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

                    if let message = viewModel.errorMessage {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.bottom, 12)
                    }

                    PrimaryButtonView(
                        title: viewModel.mode == .join ? "Join Group" :
                            (viewModel.isShowingQR ? "Create Group" : "Generate QR"),
                        action: performPrimaryAction
                    )
                    .disabled(!viewModel.canPerformPrimaryAction)
                    .opacity(
                        viewModel.canPerformPrimaryAction ? 1 : 0.9
                    )

                    Button("Join Public Festival Mesh", action: preparePublicFestivalMesh)
                        .font(.subheadline)
                        .foregroundStyle(Color.yellowProfile)
                        .frame(minHeight: 44)
                        .disabled(!viewModel.form.hasValidInitials)
                    Text("Public festival participants can read messages and locations shared in this group.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 16)

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
        .toolbarVisibility(.hidden, for: .navigationBar)
        .onChange(of: viewModel.mode, dismissEditing)
        .onChange(of: focusedField) {
            if focusedField != nil { isProfilePickerVisible = false }
        }
        .onChange(of: sessionStore.pendingInvite, initial: true) { _, invite in
            if let invite { viewModel.receiveInvite(invite) }
        }
        .onChange(of: viewModel.scannedInvite) { _, invite in
            if invite != nil, viewModel.form.hasValidInitials {
                dismissEditing()
                isShowingAgreement = true
            }
        }
        .onChange(of: isShowingAgreement) { _, showing in
            if !showing { viewModel.cancelPublicFestivalAgreement() }
        }
        .navigationDestination(isPresented: $isShowingAgreement) {
            AgreementView(
                form: viewModel.form,
                mode: viewModel.mode,
                errorMessage: viewModel.errorMessage,
                isPublicFestivalMesh: viewModel.isPublicFestivalMesh,
                onAgree: viewModel.activateLocalSession
            )
            .navigationTitle("Group Agreement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarVisibility(.visible, for: .navigationBar)
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

    private func preparePublicFestivalMesh() {
        dismissEditing()
        viewModel.preparePublicFestivalMesh()
        isShowingAgreement = true
    }
}

#Preview {
    NavigationStack {
        GroupPairingView(sessionStore: SessionStore())
    }
}
