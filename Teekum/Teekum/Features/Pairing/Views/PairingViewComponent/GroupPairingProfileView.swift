//
//  GroupPairingProfileView.swift
//  Teekum
//
//  Created by Ari Hasan on 05/11/26.
//

import SwiftUI

struct GroupPairingProfileView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var profileColor = Color.yellowProfile
    @State private var isProfilePickerVisible = false
    @State private var initials = ""
    @State private var initialsSelection: TextSelection?
    @State private var isCursorVisible = true
    @FocusState private var isEditingInitials: Bool

    private var activeInitialIndex: Int {
        min(initials.count, 2)
    }

    var body: some View {
        VStack(spacing: 0) {
            Circle()
                .fill(profileColor)
                .frame(width: 116, height: 116)
                .shadow(color: profileColor.opacity(0.45), radius: 8)
                .overlay(alignment: .bottomTrailing) {
                    Button("Edit profile color", systemImage: "square.and.pencil", action: editProfilePhoto)
                        .labelStyle(.iconOnly)
                        .font(.system(size: 18))
                        .bold()
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                        .offset(x: 18, y: 14)
                }

            if isProfilePickerVisible {
                ProfilePickerView(selectedColor: $profileColor)
            } else {
                Text("Your Initial")
                    .padding(.top, 20)
                    .font(.custom("Charter-Black", size: 17, relativeTo: .title))
                    .bold()
                    .foregroundStyle(Color.white)
                    .padding(.bottom, 15)

                ZStack {
                    HStack(spacing: 5) {
                        ForEach(0..<3) { index in
                            Text(initial(at: index))
                                .font(.custom("Charter-Bold", size: 20, relativeTo: .title3))
                                .foregroundStyle(.white)
                                .frame(width: 45, height: 50)
                                .background {
                                    RoundedRectangle(cornerRadius: 14)
                                        .strokeBorder(Color(white: 0.8), lineWidth: 1)
                                }
                                .overlay {
                                    if isEditingInitials && index == activeInitialIndex {
                                        Capsule()
                                            .fill(.white)
                                            .frame(width: 2, height: 22)
                                            .offset(x: initials.count == 3 ? 13 : 0)
                                            .opacity(isCursorVisible ? 1 : 0)
                                    }
                                }
                        }
                    }
                    .accessibilityHidden(true)

                    // A shared input lets backspace work even when the next box is empty.
                    TextField("", text: $initials, selection: $initialsSelection)
                        .textFieldStyle(.plain)
                        .foregroundStyle(.clear)
                        .tint(.clear)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .focused($isEditingInitials)
                        .submitLabel(.done)
                        .accessibilityLabel("Your initials")
                        .accessibilityHint("Enter up to three characters")
                        .onChange(of: initials) { _, value in
                            updateInitials(value)
                        }
                        .onSubmit(finishEditingInitials)

                    Button(action: focusInitials) {
                        Color.clear
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHidden(true)
                }
                .frame(width: 116, height: 40)
                .task(id: isEditingInitials && !reduceMotion) {
                    await blinkCursor()
                }
            }
        }
    }

    private func initial(at index: Int) -> String {
        let characters = Array(initials)
        return index < characters.count ? String(characters[index]) : ""
    }

    private func updateInitials(_ value: String) {
        initials = String(value.uppercased().prefix(3))
        initialsSelection = TextSelection(insertionPoint: initials.endIndex)
        isCursorVisible = true
    }

    private func focusInitials() {
        isEditingInitials = true
        initialsSelection = TextSelection(insertionPoint: initials.endIndex)
    }

    private func finishEditingInitials() {
        isEditingInitials = false
    }

    private func blinkCursor() async {
        isCursorVisible = true
        guard isEditingInitials, !reduceMotion else { return }

        while !Task.isCancelled {
            do {
                try await Task.sleep(for: .milliseconds(500))
            } catch {
                return
            }
            isCursorVisible.toggle()
        }
    }

    private func editProfilePhoto() {
        isEditingInitials = false
        isProfilePickerVisible.toggle()
    }
}

#Preview {
    GroupPairingProfileView()
        .padding(40)
        .background(.black)
        .preferredColorScheme(.dark)
}
