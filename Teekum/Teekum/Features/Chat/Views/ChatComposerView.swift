//
//  ChatComposerView.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 11/11/26.
//

import SwiftUI

struct ChatComposerView: View {
    @Bindable var viewModel: ChatViewModel
    let isFocused: FocusState<Bool>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if viewModel.isSurvivalMode {
                Text("Chat paused in Low Power Mode or below 20% battery.")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
            if let error = viewModel.errorMessage {
                Text(error).foregroundStyle(Color.redProfile).font(.caption)
            }
            HStack(alignment: .bottom, spacing: 12) {
                TextField("Message", text: $viewModel.draftText, axis: .vertical)
                    .focused(isFocused)
                    .lineLimit(1...3)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(Color.blackCard, in: .rect(cornerRadius: 16))
                    .onChange(of: viewModel.draftText) { _, text in viewModel.updateDraft(text) }
                    .onSubmit(viewModel.sendDraft)
                Button("Send", systemImage: "arrow.up", action: viewModel.sendDraft)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderedProminent)
                    .tint(.yellowProfile)
                    .foregroundStyle(.black)
                    .disabled(!viewModel.canSend)
                    .frame(minWidth: 44, minHeight: 44)
            }
            HStack {
                Text("\(viewModel.byteCount)/20 bytes")
                Spacer()
                if viewModel.cooldownRemaining > 0 {
                    Text("Wait \(Int(viewModel.cooldownRemaining.rounded(.up)))s")
                }
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
            .contentShape(.rect)
            .onTapGesture { isFocused.wrappedValue = false }
        }
        .padding()
        .background {
            Color.clear
                .contentShape(.rect)
                .onTapGesture { isFocused.wrappedValue = false }
        }
    }
}

#if DEBUG
#Preview("Draft message") {
    @Previewable @State var viewModel = ChatViewModel.preview(draft: "Meet at Gate 2")
    @Previewable @FocusState var isFocused: Bool

    ChatComposerView(viewModel: viewModel, isFocused: $isFocused)
        .background(.black)
        .preferredColorScheme(.dark)
}
#endif
