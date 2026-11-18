//
//  NearbyRangingService.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 18/11/26.
//

import CryptoKit
import Foundation
import NearbyInteraction
import Observation

@MainActor
@Observable
final class NearbyRangingService: NSObject, @preconcurrency NISessionDelegate {
    private final class Peer {
        let radio = NISession()
        let linkId: String
        var authenticatedLinks: Set<String>
        let transfer = UInt32.random(in: .min ... .max)
        var assembly = NearbyTokenFragment.Assembly()
        var token: NIDiscoveryToken?
        var lastRange = ContinuousClock.now
        var lastSend: ContinuousClock.Instant?
        var sendTask: Task<Void, Never>?

        init(linkId: String) {
            self.linkId = linkId
            authenticatedLinks = [linkId]
        }
    }

    private let transport: PeerTransportService
    private let crypto: CryptoService
    private let sequences: PacketSequenceAllocator
    @ObservationIgnored private var group: GroupSession?
    @ObservationIgnored private var peers: [String: Peer] = [:]
    @ObservationIgnored private var retryAfter: [String: ContinuousClock.Instant] = [:]
    private var isForeground = false
    private var permissionDenied = false
    private(set) var positions: [Member.ID: NearbyOrbitPosition] = [:]

    init(transport: PeerTransportService, crypto: CryptoService, sequences: PacketSequenceAllocator) {
        self.transport = transport
        self.crypto = crypto
        self.sequences = sequences
    }

    var canRange: Bool {
        isForeground && !permissionDenied && NISession.deviceCapabilities.supportsDirectionMeasurement
    }

    func configure(_ group: GroupSession?) {
        clear()
        self.group = group
    }

    func setForeground(_ active: Bool) {
        guard active != isForeground else { return }
        isForeground = active
        if active {
            permissionDenied = false
        } else {
            clear()
        }
    }

    func observe(_ ping: LocationPingPayload, inbound: InboundPacket) {
        guard canRange, ping.supportsNearbyRanging, inbound.rawPacket.envelope.hopCount == 0 else { return }
        if let peer = peers[ping.senderInitials] {
            peer.authenticatedLinks.insert(inbound.sourcePeerId)
        } else {
            _ = startPeer(ping.senderInitials, linkId: inbound.sourcePeerId)
        }
    }

    private func startPeer(_ id: String, linkId: String) -> Peer? {
        // shortcut: Try two members at a time until field tests establish a useful crowd limit.
        guard group != nil, peers.count < 2, retryAfter[id].map({ $0 <= .now }) ?? true else { return nil }
        let peer = Peer(linkId: linkId)
        peer.radio.delegateQueue = .main
        peer.radio.delegate = self
        peers[id] = peer
        sendToken(to: id, peer: peer)
        return peer
    }

    func receive(_ fragment: NearbyTokenFragment, from linkId: String) {
        // An authenticated direct request can arrive before the remote phone's first GPS ping.
        guard canRange, let peer = peers[fragment.sender] ?? startPeer(fragment.sender, linkId: linkId),
              peer.authenticatedLinks.contains(linkId),
              let data = peer.assembly.receive(fragment),
              let token = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NIDiscoveryToken.self, from: data)
        else { return }
        if token != peer.token {
            peer.token = token
            peer.radio.run(NINearbyPeerConfiguration(peerToken: token))
        }
        sendToken(to: fragment.sender, peer: peer)
    }

    func refresh(connectedLinks: Set<String>) {
        let now = ContinuousClock.now
        for id in Array(positions.keys) where positions[id]?.isFresh(at: now) == false {
            positions.removeValue(forKey: id)
        }
        retryAfter = retryAfter.filter { $0.value > now }
        for (id, peer) in peers {
            peer.authenticatedLinks.formIntersection(connectedLinks)
            if !connectedLinks.contains(peer.linkId) || peer.lastRange.duration(to: now) > .seconds(15) {
                remove(id)
            } else if peer.lastRange.duration(to: now) > .seconds(3) {
                sendToken(to: id, peer: peer)
            }
        }
    }

    private func sendToken(to id: String, peer: Peer) {
        let now = ContinuousClock.now
        guard let group, peer.sendTask == nil,
              peer.lastSend.map({ $0.duration(to: now) >= .seconds(4) }) ?? true,
              let token = peer.radio.discoveryToken,
              let data = try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true)
        else { return }
        let payloads = NearbyTokenFragment.payloads(for: data, from: group.localInitials, to: id, transfer: peer.transfer)
        guard !payloads.isEmpty else { return }
        peer.lastSend = now
        peer.sendTask = Task { [weak self, weak peer] in
            guard let self, let peer else { return }
            defer { peer.sendTask = nil }
            let key = SymmetricKey(data: group.symmetricKeyData)
            var frames: [Data] = []
            do {
                for payload in payloads {
                    try Task.checkCancellation()
                    let sequence = try await sequences.next(for: group)
                    let header = CleartextEnvelope(type: .nearbyToken, hopLimit: 1,
                        sessionId: group.sessionId, sequenceNumber: sequence)
                    frames.append(try await crypto.sealToWireBytes(payload: payload, envelope: header, using: key))
                }
                guard !Task.isCancelled, peers[id] === peer else { return }
                await transport.sendNearbyTokens(frames, to: peer.linkId, session: group)
            } catch {
                // The next discovery attempt can retry while Orbit keeps using GPS.
            }
        }
    }

    private func remove(_ id: String) {
        guard let peer = peers.removeValue(forKey: id) else { return }
        positions.removeValue(forKey: id)
        retryAfter[id] = .now.advanced(by: .seconds(8))
        peer.sendTask?.cancel()
        peer.radio.invalidate()
    }

    private func clear() {
        for id in Array(peers.keys) { remove(id) }
        retryAfter.removeAll()
    }

    func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        guard let (id, peer) = peers.first(where: { $0.value.radio === session }),
              let object = nearbyObjects.first(where: { $0.discoveryToken == peer.token }),
              let distance = object.distance, distance.isFinite, distance >= 0 else { return }
        let now = ContinuousClock.now
        peer.lastRange = now
        guard let direction = object.direction, direction.x.isFinite else { return }
        // Nearby Interaction expresses the horizontal offset as the vector's x component.
        let bearing = asin(Double(max(-1, min(1, direction.x)))) * 180 / .pi
        positions[id] = NearbyOrbitPosition(distance: Double(distance), bearing: bearing, measuredAt: now)
    }

    func session(_ session: NISession, didRemove nearbyObjects: [NINearbyObject], reason: NINearbyObject.RemovalReason) {
        if let id = peers.first(where: { $0.value.radio === session })?.key { remove(id) }
    }

    func sessionWasSuspended(_ session: NISession) {
        if let id = peers.first(where: { $0.value.radio === session })?.key { positions.removeValue(forKey: id) }
    }

    func sessionSuspensionEnded(_ session: NISession) {
        guard canRange, peers.values.contains(where: { $0.radio === session }), let configuration = session.configuration else { return }
        session.run(configuration)
    }

    func session(_ session: NISession, didInvalidateWith error: Error) {
        guard let id = peers.first(where: { $0.value.radio === session })?.key else { return }
        if (error as? NIError)?.code == .userDidNotAllow {
            permissionDenied = true
            clear()
        } else {
            remove(id)
        }
    }
}
