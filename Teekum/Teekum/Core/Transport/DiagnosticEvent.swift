//
//  DiagnosticEvent.swift
//  Teekum
//
//  Created by Nicho on 06/11/26.
//

import Foundation

/// A timestamped diagnostic event recording transport-level operations.
public struct DiagnosticEvent: Identifiable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let message: String
    public let level: EventLevel
    
    public enum EventLevel: String, Sendable {
        case info
        case warning
        case error
    }
    
    public init(id: UUID = UUID(), timestamp: Date = Date(), message: String, level: EventLevel = .info) {
        self.id = id
        self.timestamp = timestamp
        self.message = message
        self.level = level
    }
}
