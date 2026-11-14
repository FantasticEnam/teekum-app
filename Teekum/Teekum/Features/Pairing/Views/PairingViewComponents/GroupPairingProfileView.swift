//
//  GroupPairingProfileView.swift
//  Teekum
//
//  Created by Ari Hasan on 05/11/26.
//

import SwiftUI

struct GroupPairingProfileView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var profileColor: PairingProfileColor
    @Binding var initials: String
    @Binding var isProfilePickerVisible: Bool
    var focusedField: FocusState<PairingField?>.Binding
    @State private var initialsSelection: TextSelection?
    @State private var isCursorVisible = true

    private var isEditingInitials: Bool {
        focusedField.wrappedValue == .initials
    }

    private var activeInitialIndex: Int {
        min(initials.count, 2)
    }

    var body: some View {
        VStack(spacing: 0) {
            Circle()
                .fill(profileColor.color)
                .frame(width: 116, height: 116)
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
                    .font(.custom("Helvetica", size: 17, relativeTo: .headline))
                    .bold()
                    .foregroundStyle(Color.white)
                    .padding(.bottom, 6)

                ZStack {
                    HStack(spacing: 4) {
                        ForEach(0..<3) { index in
                            Text(initial(at: index))
                                .font(.custom("Helvetica", size: 20, relativeTo: .title3))
                                .foregroundStyle(.white)
                                .frame(width: 36, height: 40)
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
                        .focused(focusedField, equals: .initials)
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
        initials = String(value.uppercased().filter { $0 >= "A" && $0 <= "Z" }.prefix(3))
        initialsSelection = TextSelection(insertionPoint: initials.endIndex)
        isCursorVisible = true
    }

    private func focusInitials() {
        focusedField.wrappedValue = .initials
        initialsSelection = TextSelection(insertionPoint: initials.endIndex)
    }

    private func finishEditingInitials() {
        focusedField.wrappedValue = nil
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
        focusedField.wrappedValue = nil
        isProfilePickerVisible.toggle()
    }
}

#Preview {
    @Previewable @State var form = PairingForm()
    @Previewable @State var isProfilePickerVisible = false
    @Previewable @FocusState var focusedField: PairingField?

    GroupPairingProfileView(
        profileColor: $form.profileColor,
        initials: $form.initials,
        isProfilePickerVisible: $isProfilePickerVisible,
        focusedField: $focusedField
    )
        .padding(40)
        .background(.black)
        .preferredColorScheme(.dark)
}
