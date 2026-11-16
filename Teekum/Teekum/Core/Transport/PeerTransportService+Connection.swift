//
//  PeerTransportService+Connection.swift
//  Teekum
//
//  Created by Nicho on 06/11/26.
//

import Foundation
import Network
import WiFiAware

extension PeerTransportService {
    @discardableResult
    func attach(
        _ connection: NetworkConnection<TCP>,
        token: UUID,
        dialedDeviceID: WAPairedDevice.ID?,
        generation: UUID
    ) -> Task<Void, Never> {
        let task = Task { [weak self] in
            guard let self else { return }
            await runLink(connection, token: token, dialedDeviceID: dialedDeviceID, generation: generation)
        }
        linkTasks[token] = task
        return task
    }

    private func runLink(
        _ connection: NetworkConnection<TCP>,
        token: UUID,
        dialedDeviceID: WAPairedDevice.ID?,
        generation: UUID
    ) async {
        defer {
            linkTasks.removeValue(forKey: token)
            if let dialedDeviceID, dialAttempts[dialedDeviceID] == token {
                dialAttempts.removeValue(forKey: dialedDeviceID)
                nextDial[dialedDeviceID] = .now.advanced(by: .seconds(2))
            }
        }
        guard let session = activeSession, isCurrentGeneration(generation), !Task.isCancelled else { return }
        let local = WiFiAwareLinkHello(attemptOrder: generation, sessionID: session.sessionId,
                                      initials: session.localInitials, relayEnabled: isRelayEnabled)
        var installedPeerID: String?
        let handshakeDeadline = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(8)) } catch { return }
            await self?.linkTasks[token]?.cancel()
        }
        defer { handshakeDeadline.cancel() }

        do {
            try await connection.send(local.encode())
            let (data, metadata) = try await connection.receive(exactly: WiFiAwareLinkHello.byteCount)
            guard !metadata.endOfStream else { throw TransportError.handshakeFailed("Peer closed the connection.") }
            let remote = try WiFiAwareLinkHello.decode(data)
            let deviceID: WAPairedDevice.ID?
            if let id = dialedDeviceID ?? connection.remoteEndpoint?.wifiAware?.device.id {
                deviceID = id
            } else {
                let path = try await connection.currentPath?.wifiAware
                deviceID = path?.endpoint.device.id
            }
            guard isCurrentGeneration(generation), !Task.isCancelled else { return }
            guard let deviceID, pairedDeviceIDs.contains(deviceID) else {
                throw TransportError.handshakeFailed("Wi-Fi Aware peer is no longer paired.")
            }
            guard local.attemptOrder != remote.attemptOrder,
                  local.sessionID != remote.sessionID || local.initials != remote.initials else {
                throw TransportError.handshakeFailed("Peer has the same initials in this group.")
            }
            let peer = PeerConnection(token: token, deviceID: deviceID, remote: remote, local: local,
                                      connection: connection, isOutbound: dialedDeviceID != nil)
            if peer.isGroupMember || local.relayEnabled == isRelayEnabled,
               await install(peer, generation: generation) {
                installedPeerID = peer.peerId
                handshakeDeadline.cancel()
                try await receiveFrames(on: connection, peerID: peer.peerId, token: token, generation: generation)
            }
        } catch {
            if isCurrentGeneration(generation), !Task.isCancelled {
                reportRadioFailure(.connectionFailed(error.localizedDescription))
            }
        }
        if let installedPeerID {
            await removeLink(peerID: installedPeerID, token: token, generation: generation)
        }
    }

    private func install(_ peer: PeerConnection, generation: UUID) async -> Bool {
        if let existing = connections[peer.peerId] {
            guard existing.deviceID == peer.deviceID, !existing.preferredDirection, peer.preferredDirection else {
                return false
            }
            linkTasks[existing.token]?.cancel()
        }
        connections[peer.peerId] = peer
        if peer.isReady {
            await neighborTable.registerOrUpdateNeighbor(id: peer.peerId, displayName: peer.displayName,
                state: .connected, rssi: nil, isGroupMember: peer.isGroupMember, capabilities: .standardMesh)
        }
        guard isCurrentGeneration(generation), connections[peer.peerId] === peer else { return false }
        logEvent("Wi-Fi Aware peer \(peer.peerId) \(peer.isReady ? "connected" : "waiting for relay participation").", level: .info)
        lastErrorMessage = nil
        refreshConnectionState()
        emitPeerUpdates()
        if peer.isReady { triggerOutboxFlush() }
        return true
    }

    func removeLink(peerID: String, token: UUID, generation: UUID) async {
        guard isCurrentGeneration(generation), let peer = connections[peerID], peer.token == token else { return }
        connections.removeValue(forKey: peerID)
        carryStore.disconnected(peerID)
        if peer.isReady { await neighborTable.removeNeighbor(peerId: peerID) }
        guard isCurrentGeneration(generation) else { return }
        logEvent("Wi-Fi Aware peer \(peerID) disconnected.", level: .info)
        refreshConnectionState()
        emitPeerUpdates()
    }
}
