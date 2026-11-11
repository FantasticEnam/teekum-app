//
//  ChatViewModel.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 11/11/26.
//

import Foundation
import Observation

@MainActor
@Observable
final class ChatViewModel {
    private let service: any ChatMessagingService
    private let sessionProvider: @MainActor () -> GroupSession?
    private var generation = UUID()
    private var sendTask: Task<Void, Never>?
    private var cooldownTask: Task<Void, Never>?

    private(set) var messages: [ChatMessage] = []
    var draftText = ""
    private(set) var unreadCount = 0
    var isChatSheetPresented = false {
        didSet { if isChatSheetPresented { unreadCount = 0 } }
    }
    private(set) var isSending = false
    private(set) var cooldownRemaining: TimeInterval = 0
    private(set) var isSurvivalMode = false
    var errorMessage: String?

    init(service: any ChatMessagingService, sessionProvider: @escaping @MainActor () -> GroupSession?) {
        self.service = service
        self.sessionProvider = sessionProvider
    }

    var byteCount: Int { draftText.utf8.count }
    var canSend: Bool {
        sessionProvider() != nil && !isSending && !isSurvivalMode && cooldownRemaining <= 0
            && !draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && byteCount <= ChatMessagePayload.maxTextBytes
    }

    func start() async {
        generation = UUID()
        let current = generation
        await service.setOnMessageUpdated { [weak self] message in
            Task { @MainActor [weak self] in
                guard let self, self.generation == current else { return }
                self.receive(message)
            }
        }
        let initial = await service.activeMessages()
        guard generation == current else { return }
        messages = initial
    }

    func stop() async {
        generation = UUID()
        sendTask?.cancel()
        sendTask = nil
        cooldownTask?.cancel()
        cooldownTask = nil
        messages.removeAll()
        draftText = ""
        unreadCount = 0
        cooldownRemaining = 0
        isSending = false
        isChatSheetPresented = false
        errorMessage = nil
        await service.setOnMessageUpdated(nil)
    }

    func updateDraft(_ text: String) {
        draftText = ChatMessagePayload.clampTo20Bytes(text)
    }

    func updateBattery(level: Float, isLowPower: Bool) {
        isSurvivalMode = level < 0.20 || isLowPower
    }

    func sendDraft() {
        guard canSend else { return }
        let text = draftText
        let current = generation
        isSending = true
        errorMessage = nil
        sendTask = Task { [weak self] in
            guard let self else { return }
            do {
                let message = try await service.sendMessage(text: text, targetRecipients: nil)
                guard !Task.isCancelled, generation == current else { return }
                receive(message)
                draftText = ""
                isSending = false
                let duration = await service.timingConfig.chatUserCooldown
                guard generation == current else { return }
                startCooldown(duration: duration)
            } catch {
                guard !Task.isCancelled, generation == current else { return }
                isSending = false
                errorMessage = error.localizedDescription
            }
        }
    }

    private func receive(_ message: ChatMessage) {
        if let index = messages.firstIndex(where: {
            $0.sequenceNumber == message.sequenceNumber && $0.senderInitials == message.senderInitials
        }) {
            messages[index] = message
        } else {
            messages.append(message)
            if messages.count > 50 { messages.removeFirst(messages.count - 50) }
            if !message.isLocalSender && !isChatSheetPresented { unreadCount += 1 }
        }
    }

    private func startCooldown(duration: TimeInterval) {
        cooldownTask?.cancel()
        cooldownRemaining = duration
        let deadline = Date.now.addingTimeInterval(duration)
        cooldownTask = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .milliseconds(100)) } catch { break }
                guard let self else { return }
                cooldownRemaining = max(0, deadline.timeIntervalSinceNow)
                if cooldownRemaining == 0 { break }
            }
        }
    }
}
