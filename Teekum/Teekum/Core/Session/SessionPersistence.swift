//
//  SessionPersistence.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 11/11/26.
//

import CryptoKit
import Foundation

@MainActor
final class SessionPersistence {
    private let defaults: UserDefaults
    private let keys: KeychainStore
    private let storageKey = "com.teekum.sessionMetadata"

    init(defaults: UserDefaults = .standard, keys: KeychainStore = KeychainStore()) {
        self.defaults = defaults
        self.keys = keys
    }

    func save(_ session: GroupSession) async throws {
        let data = try JSONEncoder().encode(SessionRecord(session))
        try await keys.storeKeyInKeychain(SymmetricKey(data: session.symmetricKeyData), forSessionId: session.sessionId)
        defaults.set(data, forKey: storageKey)
    }

    func load() async throws -> GroupSession? {
        guard let data = defaults.data(forKey: storageKey) else { return nil }
        let record = try JSONDecoder().decode(SessionRecord.self, from: data)
        guard let key = try await keys.loadKeyFromKeychain(forSessionId: record.sessionId) else {
            defaults.removeObject(forKey: storageKey)
            return nil
        }
        return record.session(key: key.withUnsafeBytes { Data($0) })
    }

    func clear() async throws {
        let record = defaults.data(forKey: storageKey).flatMap { try? JSONDecoder().decode(SessionRecord.self, from: $0) }
        defaults.removeObject(forKey: storageKey)
        if let record { try await keys.purgeKeyFromKeychain(forSessionId: record.sessionId) }
    }
}
