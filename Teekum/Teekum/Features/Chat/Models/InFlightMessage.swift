//
//  InFlightMessage.swift
//  Teekum
//
//  Created by Nicho on 08/11/26.
//

import Foundation

struct InFlightMessage {
    var message: ChatMessage
    var rawWirePacket: RawWirePacket
    var wireData: Data
    var attemptCount: Int
    var maxRetries: Int
    var lastSentAt: Date
    var retryTask: Task<Void, Never>?
    var timeoutTask: Task<Void, Never>?
}
