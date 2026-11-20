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
    @State private var viewModel: PairingViewModel
    @State private var homeOnboarding: HomeOBViewModels
    @State private var isProfilePickerVisible = false
    @FocusState private var focusedField: PairingField?

    private var isShowingDraftQR: Bool {
        viewModel.mode == .create && viewModel.isShowingQR
    }

    init(
        sessionStore: SessionStore,
        homeOnboarding: HomeOBViewModels = HomeOBViewModels(),
        onActivate: (@MainActor (GroupSession) -> Void)? = nil
    ) {
        self.sessionStore = sessionStore
        _viewModel = State(initialValue: PairingViewModel(sessionStore: sessionStore, onActivate: onActivate))
        _homeOnboarding = State(initialValue: homeOnboarding)
    }

    var body: some View {
        // Keep the form anchored when the keyboard changes the safe area.
        GeometryReader { _ in
            pairingContent
                .accessibilityHidden(homeOnboarding.step != nil)
                .overlayPreferenceValue(HomeOnBoarding.TargetBounds.self) { targets in
                    if let step = homeOnboarding.step, let anchor = targets[step] {
                        GeometryReader { geometry in
                            HomeOnBoarding(
                                step: step,
                                targetFrame: geometry[anchor],
                                onAdvance: {
                                    homeOnboarding.advance(showsGroupName: targets[.groupName] != nil)
                                },
                                onDismiss: homeOnboarding.dismiss
                            )
                        }
                        .ignoresSafeArea(.container)
                    }
                }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .background {
            Color.black
                .ignoresSafeArea()
                .onTapGesture(perform: dismissEditing)
        }
        .preferredColorScheme(.dark)
        .toolbarVisibility(.hidden, for: .navigationBar)
        .onAppear(perform: homeOnboarding.showIfNeeded)
        .onChange(of: viewModel.mode) { _, mode in
            dismissEditing()
            if mode == .join, homeOnboarding.step == .groupName {
                homeOnboarding.advance(showsGroupName: false)
            }
        }
        .onChange(of: sessionStore.pendingInvite, initial: true) { _, invite in
            if let invite { viewModel.receiveInvite(invite) }
        }
        .onChange(of: viewModel.isShowingAgreement) { _, showing in
            if showing {
                dismissEditing()
            }
        }
        .navigationDestination(isPresented: $viewModel.isShowingAgreement) {
            AgreementView(
                form: viewModel.form,
                mode: viewModel.mode,
                errorMessage: viewModel.errorMessage,
                isPublicFestivalMesh: viewModel.isPublicFestivalMesh,
                onAgree: viewModel.activateLocalSession
            )
            .navigationTitle("Group Agreement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Group Agreement")
                        .font(.custom("Helvetica-Bold", size: 17, relativeTo: .headline))
                        .accessibilityAddTraits(.isHeader)
                }
            }
            .toolbarVisibility(.visible, for: .navigationBar)
        }
    }

    private var pairingContent: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                Image("Meepo_logo")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(Color.buttonPrimary)
                    .frame(height: 20)
                    .frame(width: 70)
                    .padding(.top, 10)
                    .padding(.bottom, 14)

                GroupPairingProfileView(
                    profileColor: $viewModel.form.profileColor,
                    initials: $viewModel.form.initials,
                    isProfilePickerVisible: $isProfilePickerVisible,
                    focusedField: $focusedField
                )
                    .padding(.bottom, 10)

                Text("Keep it unique within your group.")
                    .font(.custom("Helvetica", size: 11, relativeTo: .caption2))
                    .padding(.bottom, 10)


                Picker("Group action", selection: $viewModel.mode) {
                    Text("Create Group").tag(PairingMode.create)
                    Text("Join Group").tag(PairingMode.join)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .controlSize(.large)
                .font(.custom("Helvetica", size: 14, relativeTo: .subheadline))
                .frame(minHeight: 44)
                .anchorPreference(key: HomeOnBoarding.TargetBounds.self, value: .bounds) { [.groupAction: $0] }
                .padding(.bottom ,18)
            }
            .fixedSize(horizontal: false, vertical: true)
            .layoutPriority(1)

            VStack(spacing: 0) {
                if viewModel.mode == .join {
                    Text("Align QR code in frame")
                        .font(.custom("Helvetica", size: 20, relativeTo: .title3))
                        .bold()
                        .padding(.bottom, 10)
                    QRScannerView(
                        isEnabled: viewModel.form.hasValidInitials && !viewModel.isShowingAgreement,
                        isScanned: viewModel.scannedInvite != nil,
                        onCodeScanned: viewModel.handleScannedCode
                    )
                    if let invite = viewModel.scannedInvite {
                        Label(invite.sessionName, systemImage: "checkmark.circle")
                            .font(.custom("Helvetica", size: 15, relativeTo: .subheadline))
                            .padding(.top, 12)
                    }
                } else if let session = viewModel.draftSession {
                    GroupQRCodeView(session: session, isDraft: true)
                } else {
                    VStack(spacing: 10) {
                        Text("Group Name")
                            .font(.custom("Helvetica", size: 20, relativeTo: .title3))
                            .bold()
                            .frame(maxWidth: .infinity, alignment: .leading)
                        GroupNameField(
                            groupName: $viewModel.form.sessionName,
                            focusedField: $focusedField,
                            onSubmit: performPrimaryAction
                        )
                    }
                    .anchorPreference(key: HomeOnBoarding.TargetBounds.self, value: .bounds) { [.groupName: $0] }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.bottom, viewModel.mode == .join || isShowingDraftQR ? 16 : 12)

            VStack(spacing: 0) {
                if let message = viewModel.errorMessage {
                    Text(message)
                        .font(.custom("Helvetica", size: 13, relativeTo: .footnote))
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 12)
                }

                if viewModel.mode == .join {
                    Button(action: pasteInviteFromClipboard) {
                        HStack(spacing: 8) {
                            Text("Paste link or shared message…")
                                .font(.custom("Helvetica", size: 13, relativeTo: .caption))
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
                        (viewModel.isShowingQR ? "Join Group" : "Create Group"),
                    action: performPrimaryAction
                )
                .disabled(!viewModel.canPerformPrimaryAction)
                .opacity(
                    viewModel.canPerformPrimaryAction ? 1 : 0.9
                )
                .anchorPreference(key: HomeOnBoarding.TargetBounds.self, value: .bounds) { [.primaryAction: $0] }
                .padding(.bottom, 10)

                if viewModel.mode == .create && !isShowingDraftQR {
//                    Button("Join Public Mesh", action: preparePublicFestivalMesh)
//                        .font(.custom("Helvetica", size: 15, relativeTo: .subheadline))
//                        .foregroundStyle(Color.yellowProfile)
//                        .frame(minHeight: 34)
//                        .disabled(!viewModel.form.hasValidInitials)
                    Text("Group participants can read messages and locations shared in this group.")
                        .font(.custom("Helvetica", size: 12, relativeTo: .caption))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.bottom, 16)
            .fixedSize(horizontal: false, vertical: true)
            .layoutPriority(1)
        }
        .frame(maxWidth: 400)
        .padding(.horizontal, 42)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background {
            Color.clear
                .contentShape(.rect)
                .onTapGesture(perform: dismissEditing)
        }
    }

    private func performPrimaryAction() {
        guard viewModel.canPerformPrimaryAction else { return }
        dismissEditing()
        if viewModel.mode == .join || viewModel.isShowingQR {
            viewModel.isShowingAgreement = true
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
        viewModel.isShowingAgreement = true
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
            viewModel.isShowingAgreement = true
        }
    }
}

#Preview {
    NavigationStack {
        GroupPairingView(sessionStore: SessionStore())
    }
}
