//
//  NeighborTableRegistry.swift
//  Teekum
//
//  Created by Nicho on 08/11/26.
//

import Foundation

// MARK: - Neighbor Discovery, Registration & State Transitions

extension NeighborTable {
    
    /// Returns all currently tracked neighbors that are not stale.
    public func activeNeighbors() async -> [NeighborInfo] {
        entries.values
            .map { $0.info }
            .filter { $0.state != .stale }
            .sorted { (lhs: NeighborInfo, rhs: NeighborInfo) in
                // Sort connected before degraded, then fresher lastSeen
                if lhs.state == .connected && rhs.state != .connected { return true }
                if lhs.state != .connected && rhs.state == .connected { return false }
                return lhs.lastSeen > rhs.lastSeen
            }
    }
    
    /// Updates neighbor telemetry upon packet arrival, ping, or keep-alive tick.
    public func recordNeighborActivity(peerId: String, rssi: Int8?, isGroupMember: Bool) async {
        let now = clock.now()
        
        if var existing = entries[peerId] {
            let previousState = existing.info.state
            let newState: NeighborState
            if case .degraded(let loss) = previousState {
                newState = .degraded(packetLossRatio: loss)
            } else {
                newState = .connected
            }
            
            let updatedInfo = NeighborInfo(
                id: peerId,
                displayName: existing.info.displayName,
                state: newState,
                rssi: rssi ?? existing.info.rssi,
                lastSeen: now,
                roundTripTimeMs: existing.info.roundTripTimeMs,
                isGroupMember: isGroupMember,
                capabilities: existing.info.capabilities
            )
            existing.info = updatedInfo
            entries[peerId] = existing
            
            if previousState != newState {
                emitEvent(.stateChanged(peerId: peerId, oldState: previousState, newState: newState))
            }
        } else {
            // New neighbor discovered
            enforceCapacityLimit()
            
            let newInfo = NeighborInfo(
                id: peerId,
                displayName: nil,
                state: .connected,
                rssi: rssi,
                lastSeen: now,
                roundTripTimeMs: nil,
                isGroupMember: isGroupMember,
                capabilities: .standardMesh
            )
            entries[peerId] = NeighborEntry(info: newInfo)
            emitEvent(.discovered(newInfo))
            emitEvent(.connected(newInfo))
        }
    }
    
    /// Explicitly updates neighbor connection state.
    public func setNeighborState(peerId: String, state: NeighborState) async {
        guard var entry = entries[peerId] else { return }
        let oldState = entry.info.state
        guard oldState != state else { return }
        
        let updatedInfo = NeighborInfo(
            id: peerId,
            displayName: entry.info.displayName,
            state: state,
            rssi: entry.info.rssi,
            lastSeen: entry.info.lastSeen,
            roundTripTimeMs: entry.info.roundTripTimeMs,
            isGroupMember: entry.info.isGroupMember,
            capabilities: entry.info.capabilities
        )
        entry.info = updatedInfo
        entries[peerId] = entry
        
        emitEvent(.stateChanged(peerId: peerId, oldState: oldState, newState: state))
    }
    
    /// Registers or updates full neighbor metadata including display name and capabilities.
    public func registerOrUpdateNeighbor(
        id: String,
        displayName: String?,
        state: NeighborState = .connected,
        rssi: Int8? = nil,
        isGroupMember: Bool,
        capabilities: TransportCapabilities = .standardMesh
    ) async {
        let now = clock.now()
        
        if var existing = entries[id] {
            let oldState = existing.info.state
            let updated = NeighborInfo(
                id: id,
                displayName: displayName ?? existing.info.displayName,
                state: state,
                rssi: rssi ?? existing.info.rssi,
                lastSeen: now,
                roundTripTimeMs: existing.info.roundTripTimeMs,
                isGroupMember: isGroupMember,
                capabilities: capabilities
            )
            existing.info = updated
            entries[id] = existing
            
            if oldState != state {
                emitEvent(.stateChanged(peerId: id, oldState: oldState, newState: state))
            }
        } else {
            enforceCapacityLimit()
            let newInfo = NeighborInfo(
                id: id,
                displayName: displayName,
                state: state,
                rssi: rssi,
                lastSeen: now,
                roundTripTimeMs: nil,
                isGroupMember: isGroupMember,
                capabilities: capabilities
            )
            entries[id] = NeighborEntry(info: newInfo)
            emitEvent(.discovered(newInfo))
            if state == .connected {
                emitEvent(.connected(newInfo))
            }
        }
    }
    
    /// Removes a neighbor upon socket disconnection or keep-alive expiry.
    public func removeNeighbor(peerId: String) async {
        guard entries.removeValue(forKey: peerId) != nil else { return }
        emitEvent(.disconnected(peerId: peerId))
    }
}
