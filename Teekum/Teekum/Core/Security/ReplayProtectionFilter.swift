////
////  ReplayProtectionFilter.swift
////  Teekum
////
////  Created by Nicho on 05/11/26.
////
//
//import Foundation
//
///// Thread-safe in-memory sliding window filter enforcing:
///// 1. Exact packet deduplication (5-minute sliding window)
///// 2. Per-sender monotonic sequence number advancement
///// 3. Timestamp sanity check (clock skew guard)
///// 4. Stale state replacement rejection for coordinates
//public actor ReplayProtectionFilter {
//    private struct PacketKey: Hashable {
//        let sessionId: UInt16
//        let sequenceNumber: UInt32
//    }
//    
//    /// Maximum age of entries in the duplicate cache (5 minutes = 300 seconds).
//    private let deduplicationWindow: TimeInterval
//    
//    /// Maximum allowed clock skew for future timestamps (5 minutes = 300 seconds).
//    private let maxClockSkew: TimeInterval
//    
//    /// Map of recently seen (sessionId, sequenceNumber) -> arrival time.
//    private var seenPackets: [PacketKey: Date] = [:]
//    
//    /// Highest seen sequence number per member initials.
//    private var highestSequencePerSender: [String: UInt32] = [:]
//    
//    /// Timestamp of freshest location measurement per member initials.
//    private var latestTimestampPerSender: [String: Date] = [:]
//    
//    public init(
//        deduplicationWindow: TimeInterval = 300.0,
//        maxClockSkew: TimeInterval = 300.0
//    ) {
//        self.deduplicationWindow = deduplicationWindow
//        self.maxClockSkew = maxClockSkew
//    }
//    
//    /// Returns true if the packet (sessionId, sequenceNumber) has already been seen
//    /// within the active deduplication window.
//    public func isDuplicate(sessionId: UInt16, sequenceNumber: UInt32, now: Date = Date()) -> Bool {
//        evictExpiredEntries(now: now)
//        let key = PacketKey(sessionId: sessionId, sequenceNumber: sequenceNumber)
//        guard let arrival = seenPackets[key] else { return false }
//        return now.timeIntervalSince(arrival) < deduplicationWindow
//    }
//    
//    /// Records a verified packet into the duplicate cache.
//    public func recordPacket(sessionId: UInt16, sequenceNumber: UInt32, now: Date = Date()) {
//        let key = PacketKey(sessionId: sessionId, sequenceNumber: sequenceNumber)
//        seenPackets[key] = now
//    }
//    
//    /// Validates whether a packet's measurement timestamp is plausible:
//    /// - Rejects timestamps > 5 minutes in the future (clock skew guard).
//    /// - Rejects timestamps older than the active deduplication window.
//    public func isTimestampValid(_ timestamp: Date, now: Date = Date()) -> Bool {
//        let delta = timestamp.timeIntervalSince(now)
//        if delta > maxClockSkew {
//            // Timestamp is too far in the future
//            return false
//        }
//        if now.timeIntervalSince(timestamp) > (deduplicationWindow * 12) { // 1 hour max session live age
//            return false
//        }
//        return true
//    }
//    
//    /// Validates and records per-sender sequence monotonicity.
//    /// Returns false if sequenceNumber <= highest seen sequence number for this sender.
//    public func checkAndRecordSenderSequence(senderInitials: String, sequenceNumber: UInt32) -> Bool {
//        let clean = InitialsCodec.sanitize(senderInitials)
//        if let highest = highestSequencePerSender[clean] {
//            guard sequenceNumber > highest else {
//                return false
//            }
//        }
//        highestSequencePerSender[clean] = sequenceNumber
//        return true
//    }
//    
//    /// Validates whether an incoming location measurement is strictly newer than
//    /// the freshest recorded measurement for that sender.
//    /// Prevents delayed, out-of-order packets from overwriting fresher friend pins.
//    public func checkAndRecordLocationFreshness(senderInitials: String, timestamp: Date) -> Bool {
//        let clean = InitialsCodec.sanitize(senderInitials)
//        if let latest = latestTimestampPerSender[clean] {
//            guard timestamp > latest else {
//                return false
//            }
//        }
//        latestTimestampPerSender[clean] = timestamp
//        return true
//    }
//    
//    /// Wipes all cached sequences and packet keys for session teardown.
//    public func purge() {
//        seenPackets.removeAll()
//        highestSequencePerSender.removeAll()
//        latestTimestampPerSender.removeAll()
//    }
//    
//    private func evictExpiredEntries(now: Date) {
//        let cutoff = now.addingTimeInterval(-deduplicationWindow)
//        seenPackets = seenPackets.filter { $0.value >= cutoff }
//    }
//}
