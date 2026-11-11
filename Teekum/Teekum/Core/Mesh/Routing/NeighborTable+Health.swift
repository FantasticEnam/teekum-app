//
//  NeighborTable+Health.swift
//  Teekum
//
//  Created by Nicho on 08/11/26.
//

import Foundation

// MARK: - Link Health, Candidate Selection & Eviction

extension NeighborTable {
    
    /// Selects the healthiest neighbor link for a given candidate set, excluding specified peers.
    public func selectBestNextHop(excluding: Set<String>) async -> String? {
        let candidates = entries.values.filter { entry in
            guard !excluding.contains(entry.info.id) else { return false }
            switch entry.info.state {
            case .connected, .degraded:
                return true
            case .connecting, .stale:
                return false
            }
        }
        
        guard !candidates.isEmpty else { return nil }
        
        // Sorting metric:
        // 1. .connected ranked higher than .degraded
        // 2. Degraded ranked by lower packetLossRatio
        // 3. Stronger RSSI (higher dBm, e.g. -45 dBm > -85 dBm)
        // 4. Fresher lastSeen date
        let sorted = candidates.sorted { (lhs: NeighborEntry, rhs: NeighborEntry) in
            let lhsConnected = lhs.info.state == .connected
            let rhsConnected = rhs.info.state == .connected
            if lhsConnected != rhsConnected {
                return lhsConnected
            }
            
            // If both degraded, compare loss ratio
            if case .degraded(let lLoss) = lhs.info.state, case .degraded(let rLoss) = rhs.info.state {
                if abs(lLoss - rLoss) > 0.05 {
                    return lLoss < rLoss
                }
            }
            
            // Compare RSSI if available
            if let lRssi = lhs.info.rssi, let rRssi = rhs.info.rssi, lRssi != rRssi {
                return lRssi > rRssi
            }
            
            return lhs.info.lastSeen > rhs.info.lastSeen
        }
        
        return sorted.first?.info.id
    }
    
    /// Updates packet transmission outcome to evaluate link degradation.
    public func recordTransmissionOutcome(peerId: String, success: Bool) async {
        guard var entry = entries[peerId] else { return }
        let now = clock.now()
        entry.lastPacketSentAt = now
        
        if success {
            entry.packetsSent += 1
            // If degraded, recover to connected if loss ratio drops below 10%
            if case .degraded = entry.info.state, entry.packetLossRatio < 0.10 {
                let oldState = entry.info.state
                let updatedInfo = NeighborInfo(
                    id: peerId,
                    displayName: entry.info.displayName,
                    state: .connected,
                    rssi: entry.info.rssi,
                    lastSeen: now,
                    roundTripTimeMs: entry.info.roundTripTimeMs,
                    isGroupMember: entry.info.isGroupMember,
                    capabilities: entry.info.capabilities
                )
                entry.info = updatedInfo
                entries[peerId] = entry
                emitEvent(.stateChanged(peerId: peerId, oldState: oldState, newState: .connected))
                return
            }
        } else {
            entry.packetsFailed += 1
            let lossRatio = entry.packetLossRatio
            // If loss ratio >= 20% over at least 3 attempts, mark degraded
            let totalAttempts = entry.packetsSent + entry.packetsFailed
            if totalAttempts >= 3 && lossRatio >= 0.20 {
                let oldState = entry.info.state
                let newState = NeighborState.degraded(packetLossRatio: lossRatio)
                if oldState != newState {
                    let updatedInfo = NeighborInfo(
                        id: peerId,
                        displayName: entry.info.displayName,
                        state: newState,
                        rssi: entry.info.rssi,
                        lastSeen: now,
                        roundTripTimeMs: entry.info.roundTripTimeMs,
                        isGroupMember: entry.info.isGroupMember,
                        capabilities: entry.info.capabilities
                    )
                    entry.info = updatedInfo
                    entries[peerId] = entry
                    emitEvent(.stateChanged(peerId: peerId, oldState: oldState, newState: newState))
                    return
                }
            }
        }
        
        entries[peerId] = entry
    }
    
    /// Evicts neighbors whose keep-alive has lapsed beyond the timeout threshold.
    /// - Stage 1 (> threshold): Transition to .stale
    /// - Stage 2 (> 2 * threshold): Removed entirely
    public func evictStaleNeighbors(thresholdSeconds: TimeInterval) async {
        let now = clock.now()
        var peersToRemove: [String] = []
        
        for (peerId, var entry) in entries {
            let elapsed = now.timeIntervalSince(entry.info.lastSeen)
            if elapsed > thresholdSeconds * 2.0 {
                peersToRemove.append(peerId)
            } else if elapsed > thresholdSeconds {
                if entry.info.state != .stale {
                    let oldState = entry.info.state
                    let updatedInfo = NeighborInfo(
                        id: peerId,
                        displayName: entry.info.displayName,
                        state: .stale,
                        rssi: entry.info.rssi,
                        lastSeen: entry.info.lastSeen,
                        roundTripTimeMs: entry.info.roundTripTimeMs,
                        isGroupMember: entry.info.isGroupMember,
                        capabilities: entry.info.capabilities
                    )
                    entry.info = updatedInfo
                    entries[peerId] = entry
                    emitEvent(.stateChanged(peerId: peerId, oldState: oldState, newState: .stale))
                }
            }
        }
        
        for peerId in peersToRemove {
            entries.removeValue(forKey: peerId)
            emitEvent(.evicted(peerId: peerId))
        }
    }
}
