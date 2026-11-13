//
//  GroupPairingView.swift
//  Teekum
//
//  Created by Ari Hasan on 02/11/26.
//

import SwiftUI
import UIKit

struct GroupPairingView: View {
    private let sessionStore: SessionStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var viewModel: PairingViewModel
    @State private var isShowingAgreement = false
    @State private var isProfilePickerVisible = false
    @FocusState private var focusedField: PairingField?

    private var isShowingDraftQR: Bool {
        viewModel.mode == .create && viewModel.isShowingQR
    }

    private var isEditingCreateForm: Bool {
        viewModel.mode == .create && !isShowingDraftQR && focusedField != nil
    }

    private var shouldRaiseGenerateQR: Bool {
        viewModel.mode == .create && !isShowingDraftQR &&
            (isEditingCreateForm || viewModel.form.canGenerateQR)
    }

    init(sessionStore: SessionStore, onActivate: (@MainActor (GroupSession) -> Void)? = nil) {
        self.sessionStore = sessionStore
        _viewModel = State(initialValue: PairingViewModel(sessionStore: sessionStore, onActivate: onActivate))
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                Image("Meepo_logo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 20)
                    .frame(width: 70)
                    .padding(.top, 10)
                    .padding(.bottom, 34)

                GroupPairingProfileView(
                    profileColor: $viewModel.form.profileColor,
                    initials: $viewModel.form.initials,
                    isProfilePickerVisible: $isProfilePickerVisible,
                    focusedField: $focusedField
                )
                    .padding(.bottom, 20)

                Picker("Group action", selection: $viewModel.mode) {
                    Text("Create Group").tag(PairingMode.create)
                    Text("Join Group").tag(PairingMode.join)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .controlSize(.large)
                .font(.custom("Charter-Bold", size: 14, relativeTo: .subheadline))
                .frame(minHeight: 44)
                .padding(.bottom, isEditingCreateForm ? 12 : 24)
            }
            .fixedSize(horizontal: false, vertical: true)
            .layoutPriority(1)

            VStack(spacing: 0) {
                if viewModel.mode == .join {
                    Text("Align QR code in frame")
                        .font(.custom("Charter-Bold", size: 22, relativeTo: .title2))
                        .padding(.bottom, 10)
                    QRScannerView(
                        isEnabled: viewModel.form.hasValidInitials && !isShowingAgreement,
                        onCodeScanned: viewModel.handleScannedCode
                    )
                    if let invite = viewModel.scannedInvite {
                        Label(invite.sessionName, systemImage: "checkmark.circle")
                            .font(.subheadline)
                            .padding(.top, 12)
                    }
                } else if let session = viewModel.draftSession {
                    GroupQRCodeView(session: session, isDraft: true)
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
            }
            .frame(maxWidth: .infinity, maxHeight: shouldRaiseGenerateQR ? nil : .infinity, alignment: .top)
            .padding(.bottom, viewModel.mode == .join || isShowingDraftQR ? 16 : 12)

            VStack(spacing: 0) {
                if let message = viewModel.errorMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 12)
                }

                if viewModel.mode == .join {
                    Button(action: pasteInviteFromClipboard) {
                        HStack(spacing: 8) {
                            Text("Paste link or shared message…")
                                .font(.custom("Charter-Roman", size: 13, relativeTo: .caption))
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                            Image(systemName: "doc.on.clipboard")
                                .font(.subheadline)
                                .accessibilityHidden(true)
                        }
                        .foregroundStyle(Color(white: 0.68))
                        .padding(.horizontal, 20)
                        .frame(minHeight: 36)
                        .background(Color(white: 0.17), in: Capsule())
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                    }
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

                if viewModel.mode == .create && !isShowingDraftQR && !isEditingCreateForm {
                    Button("Join Public Mesh", action: preparePublicFestivalMesh)
                        .font(.subheadline)
                        .foregroundStyle(Color.yellowProfile)
                        .frame(minHeight: 34)
                        .disabled(!viewModel.form.hasValidInitials)
                    Text("Group participants can read messages and locations shared in this group.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.bottom, isEditingCreateForm ? 0 : 16)
            .fixedSize(horizontal: false, vertical: true)
            .layoutPriority(1)

            if shouldRaiseGenerateQR {
                Spacer(minLength: 0)
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: shouldRaiseGenerateQR)
        .frame(maxWidth: 400)
        .padding(.horizontal, 42)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background {
            Color.clear
                .contentShape(.rect)
                .onTapGesture(perform: dismissEditing)
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

    private func pasteInviteFromClipboard() {
        var candidates: [String] = []
        if UIPasteboard.general.hasStrings, let text = UIPasteboard.general.string {
            candidates.append(text)
        }
        if UIPasteboard.general.hasURLs, let urlString = UIPasteboard.general.url?.absoluteString {
            candidates.append(urlString)
        }
        viewModel.pasteInvite(candidates: candidates)
        if viewModel.scannedInvite != nil, viewModel.errorMessage == nil, viewModel.form.hasValidInitials {
            dismissEditing()
            isShowingAgreement = true
        }
    }
}

#Preview {
    NavigationStack {
        GroupPairingView(sessionStore: SessionStore())
    }
}
