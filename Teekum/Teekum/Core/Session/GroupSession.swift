//
//  GroupSession.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 03/11/26.
//

import Foundation
import CryptoKit

/// Active ephemeral group session model representing local participation.
/// Auto-mesh enabled: connects to nearby peers on a shared festival key.
public struct GroupSession: Identifiable, Equatable, Sendable, Codable {
    public var id: UInt32 { sessionId }
    
    /// 24-bit session hash identifying the active festival network.
    public let sessionId: UInt32
    
    /// Human-friendly name for the session (e.g., "Festival Mesh").
    public let sessionName: String
    
    /// 256-bit symmetric key bytes used for authenticated payload encryption.
    public let symmetricKeyData: Data
    
    /// Local user's 3-letter initials (e.g. "DNA").
    public var localInitials: String
    
    /// Local user's preferred 1-byte color code (MemberColor).
    public var localColorCode: UInt8
    
    /// Backward-compatibility alias for display name.
    public var localMemberName: String { localInitials }

    public var localMemberId: MemberID { .fromInitials(localInitials) }
    
    /// True if the user initiated the session (or host role).
    public let isHost: Bool
    
    /// Backward-compatibility slot calculation.
    public var memberSlot: UInt8 {
        let bytes = InitialsCodec.encode(localInitials) ?? [0, 0]
        return bytes[0] ^ bytes[1]
    }
    
    /// Timestamp when session was established.
    public let createdAt: Date
    
    /// Default shared festival key for auto-mesh.
    public static let defaultSymmetricKeyData: Data = {
        let seed = "TeeKum-Festival-AutoMesh-v2-SecretSeed"
        return Data(SHA256.hash(data: Data(seed.utf8)))
    }()
    
    /// Default 24-bit session identifier for the public Festival Mesh; matches the three-byte wire SID field.
    public static let defaultSessionId: UInt32 = 0x7E3AF5
    
    public init(
        sessionId: UInt32 = GroupSession.defaultSessionId,
        sessionName: String = "Festival Mesh",
        symmetricKeyData: Data = GroupSession.defaultSymmetricKeyData,
        localInitials: String,
        localColorCode: UInt8 = 0x00,
        memberSlot: UInt8? = nil,
        isHost: Bool = true,
        createdAt: Date = Date()
    ) {
        self.sessionId = sessionId & PacketConstants.sessionIdMask
        self.sessionName = sessionName
        self.symmetricKeyData = symmetricKeyData
        self.localInitials = InitialsCodec.sanitize(localInitials)
        self.localColorCode = localColorCode
        self.isHost = isHost
        self.createdAt = createdAt
    }
    
    // MARK: - Serverless Share Link & QR Encoding

    /// Short display fingerprint derived from the key's digest.
    var keyFingerprint: String {
        let prefix = SHA256.hash(data: symmetricKeyData).prefix(4)
        return "0x" + prefix.map { String(format: "%02X", $0) }.joined()
    }
    
    /// Generates a serverless invite URL where the 256-bit key is packed into the URL fragment (#).
    /// Using the URL fragment guarantees that if tapped on the web, the key is never transmitted
    /// to any remote HTTP web server.
    public func inviteURL() -> URL {
        var components = URLComponents()
        components.scheme = "meepo"
        components.host = "join"
        
        var payload = URLComponents()
        payload.queryItems = [
            URLQueryItem(name: "key", value: symmetricKeyData.base64EncodedString()),
            URLQueryItem(name: "sid", value: PacketConstants.formatSessionId(sessionId)),
            URLQueryItem(name: "name", value: sessionName)
        ]
        components.percentEncodedFragment = payload.percentEncodedQuery
        guard let url = components.url else {
            preconditionFailure("Unable to encode a Meepo invite URL.")
        }
        return url
    }
    
    /// Extracts a `meepo://join...` URL from any arbitrary string (e.g. copied share message, email, or chat).
    /// Uses regex matching to locate the offline link even when embedded inside boilerplate text such as:
    /// `"Join my offline concert group on Meepo: Festival Crew meepo://join#key=...&sid=...&name=..."`.
    public static func extractInviteURL(from text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        
        // Direct URL parse if the string itself is a clean teekum URL
        if let directURL = URL(string: trimmed),
           let scheme = directURL.scheme?.lowercased(),
           scheme == "meepo" {
            return directURL
        }
        
        // Regex extraction to find meepo:// URL inside any arbitrary text
        // Matches teekum://join followed by query or fragment parameters
        let pattern = #"(?i)meepo://join[^\s<>"'\(\)\[\]\{\}]+"#
        guard let range = text.range(of: pattern, options: .regularExpression) else {
            return nil
        }
        
        var rawMatched = String(text[range])
        
        // Trim trailing sentence punctuation if accidentally attached
        let trailingPunctuation = CharacterSet(charactersIn: ".,;:!?")
        while let last = rawMatched.unicodeScalars.last, trailingPunctuation.contains(last) {
            rawMatched.removeLast()
        }
        
        return URL(string: rawMatched)
    }
    
    /// Parses an incoming string (raw text, copied share message, or direct URL) into a `GroupSessionInvite`.
    public static func parseInvite(from text: String) -> GroupSessionInvite? {
        guard let url = extractInviteURL(from: text) else { return nil }
        return parseInvite(from: url)
    }
    
    /// Parses an incoming universal link or QR barcode string into a `GroupSessionInvite`.
    public static func parseInvite(from url: URL) -> GroupSessionInvite? {
        guard let scheme = url.scheme?.lowercased(), scheme == "meepo" else { return nil }
        let host = (url.host ?? "").lowercased()
        guard host == "join" || url.path.lowercased().contains("join") else { return nil }
        
        let rawPayload = (url.fragment?.isEmpty == false ? url.fragment : url.query) ?? ""
        guard !rawPayload.isEmpty else { return nil }
        
        var keyData: Data?
        var sessionId: UInt32?
        var sessionName: String?
        
        let pairs = rawPayload.split(separator: "&")
        for pair in pairs {
            let parts = pair.split(separator: "=", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let key = String(parts[0])
            let value = String(parts[1])
            
            switch key {
            case "key":
                let clean = value.removingPercentEncoding ?? value
                keyData = Data(base64Encoded: clean) ?? Data(base64Encoded: clean.replacingOccurrences(of: " ", with: "+"))
            case "sid":
                let clean = value.removingPercentEncoding ?? value
                sessionId = UInt32(clean, radix: 16) ?? UInt32(clean)
            case "name":
                sessionName = value.removingPercentEncoding ?? value
            default:
                break
            }
        }
        
        guard let validKey = keyData, validKey.count == 32,
              let validSid = sessionId, PacketConstants.isValidSessionId(validSid),
              let validName = sessionName else {
            return nil
        }
        
        return GroupSessionInvite(sessionId: validSid, sessionName: validName, keyData: validKey)
    }
}
