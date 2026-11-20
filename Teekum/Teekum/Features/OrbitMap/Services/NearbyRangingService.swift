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
    struct Status {
        let description: LocalizedStringResource
        let tokensReceived: Int
        let lastSetupIssue: LocalizedStringResource?
        let measurements: [Member.ID: NearbyOrbitPosition]
    }

    private final class Peer {
        let radio = NISession()
        var linkId: String
        var authenticatedLinks: Set<String>
        let transfer = UInt32.random(in: .min ... .max)
        var assembly = NearbyTokenFragment.Assembly()
        var token: NIDiscoveryToken?
        var lastRangingActivity = ContinuousClock.now
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
    private var peers: [String: Peer] = [:]
    @ObservationIgnored private var retryAfter: [String: ContinuousClock.Instant] = [:]
    @ObservationIgnored private var advertisementTask: Task<Void, Never>?
    @ObservationIgnored private var lastAdvertisement: ContinuousClock.Instant?
    @ObservationIgnored private var sessionLimit = 3
    private var isForeground = false
    private var permissionDenied = false
    private var configuredMembers: Set<Member.ID> = []
    private var lastSetupIssue: LocalizedStringResource?
    private(set) var positions: [Member.ID: NearbyOrbitPosition] = [:]

    init(transport: PeerTransportService, crypto: CryptoService, sequences: PacketSequenceAllocator) {
        self.transport = transport
        self.crypto = crypto
        self.sequences = sequences
    }

    var canRange: Bool {
        isForeground && !permissionDenied && isSupported
    }

    private var isSupported: Bool { NISession.deviceCapabilities.supportsPreciseDistanceMeasurement }

    var status: Status {
        let now = ContinuousClock.now
        let measurements = positions.filter { $0.value.isFresh(at: now) }
        let description: LocalizedStringResource = if !isSupported {
            "Unsupported on this device"
        } else if permissionDenied {
            "Permission denied"
        } else if !isForeground {
            "Paused"
        } else if !measurements.isEmpty {
            "Active"
        } else if !configuredMembers.isEmpty {
            "Waiting for UWB measurements"
        } else if !peers.isEmpty {
            "Exchanging discovery tokens"
        } else {
            "Searching for nearby members"
        }
        return Status(description: description, tokensReceived: configuredMembers.count,
            lastSetupIssue: canRange && measurements.isEmpty ? lastSetupIssue : nil, measurements: measurements)
    }

    func distance(to id: Member.ID) -> Double? {
        guard let sample = positions[id], sample.isFresh(at: .now) else { return nil }
        return sample.distance
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

    private func startPeer(_ id: String, linkId: String) -> Peer? {
        // shortcut: Start with three sessions until device tests establish a safe group capacity.
        guard group != nil, peers.count < sessionLimit, retryAfter[id].map({ $0 <= .now }) ?? true else { return nil }
        let peer = Peer(linkId: linkId)
        peer.radio.delegateQueue = .main
        peer.radio.delegate = self
        peers[id] = peer
        sendToken(to: id, peer: peer)
        return peer
    }

    func receive(_ fragment: NearbyTokenFragment, from linkId: String) {
        // An authenticated direct request can arrive before the remote phone's first GPS ping.
        guard canRange, let peer = peers[fragment.sender] ?? startPeer(fragment.sender, linkId: linkId) else { return }
        peer.authenticatedLinks.insert(linkId)
        guard let data = peer.assembly.receive(fragment) else { return }
        guard let token = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NIDiscoveryToken.self, from: data) else {
            lastSetupIssue = "Could not decode the other iPhone's token."
            return
        }
        if token != peer.token {
            positions.removeValue(forKey: fragment.sender)
            peer.token = token
            peer.lastRangingActivity = .now
            configuredMembers.insert(fragment.sender)
            lastSetupIssue = nil
            peer.radio.run(NINearbyPeerConfiguration(peerToken: token))
        }
        if peer.lastRangingActivity.duration(to: .now) > .seconds(3) {
            sendToken(to: fragment.sender, peer: peer)
        }
    }

    func refresh(connectedLinks: Set<String>) {
        guard canRange, group != nil else { return }
        let now = ContinuousClock.now
        if !connectedLinks.isEmpty { advertise(now: now) }
        for id in Array(positions.keys) where positions[id]?.isFresh(at: now) == false {
            positions.removeValue(forKey: id)
        }
        retryAfter = retryAfter.filter { $0.value > now }
        for (id, peer) in peers {
            peer.authenticatedLinks.formIntersection(connectedLinks)
            if !connectedLinks.contains(peer.linkId),
               let fallback = peer.authenticatedLinks.sorted().first {
                peer.linkId = fallback
                peer.lastSend = nil
            }
            let idle = peer.lastRangingActivity.duration(to: now)
            if !connectedLinks.contains(peer.linkId) {
                remove(id)
            } else if idle > .seconds(15) {
                if lastSetupIssue == nil {
                    lastSetupIssue = peer.token == nil ? "Peer token did not arrive in full." : "No UWB distance received."
                }
                remove(id)
            } else if idle > .seconds(3) {
                sendToken(to: id, peer: peer)
            }
        }
    }

    private func advertise(now: ContinuousClock.Instant) {
        guard let group, advertisementTask == nil,
              lastAdvertisement.map({ $0.duration(to: now) >= .seconds(6) }) ?? true,
              let payload = NearbyTokenFragment.advertisement(from: group.localInitials, color: group.localColorCode)
        else { return }
        lastAdvertisement = now
        advertisementTask = Task { [weak self] in
            guard let self, !Task.isCancelled else { return }
            defer { if !Task.isCancelled { advertisementTask = nil } }
            guard let frame = try? await seal(payload, for: group),
                  !Task.isCancelled, canRange, self.group == group else { return }
            await transport.sendNearbyFrames([frame], to: nil, session: group)
        }
    }

    private func sendToken(to id: String, peer: Peer) {
        let now = ContinuousClock.now
        guard let group, peer.sendTask == nil,
              peer.lastSend.map({ $0.duration(to: now) >= .seconds(4) }) ?? true
        else { return }
        if peer.lastSend != nil {
            let links = peer.authenticatedLinks.sorted()
            peer.linkId = links.first(where: { $0 > peer.linkId }) ?? links.first ?? peer.linkId
        }
        let linkId = peer.linkId
        peer.lastSend = now
        guard let token = peer.radio.discoveryToken,
              let data = try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true) else {
            lastSetupIssue = "Could not prepare this iPhone's discovery token."
            return
        }
        let payloads = NearbyTokenFragment.payloads(for: data, from: group.localInitials, to: id, transfer: peer.transfer)
        guard !payloads.isEmpty else {
            lastSetupIssue = "Could not split the discovery token into packets (\(data.count) bytes)."
            return
        }
        peer.sendTask = Task { [weak self, weak peer] in
            guard let self, let peer else { return }
            defer { peer.sendTask = nil }
            var frames: [Data] = []
            do {
                for payload in payloads {
                    try Task.checkCancellation()
                    frames.append(try await seal(payload, for: group))
                }
                guard !Task.isCancelled, peers[id] === peer else { return }
                let queued = await transport.sendNearbyFrames(frames, to: linkId, session: group)
                if !queued, peers[id] === peer {
                    lastSetupIssue = "Could not queue token packets on the direct connection."
                }
            } catch {
                if !Task.isCancelled, peers[id] === peer {
                    lastSetupIssue = "Could not encrypt the token packets."
                }
            }
        }
    }

    private func seal(_ payload: Data, for group: GroupSession) async throws -> Data {
        let sequence = try await sequences.next(for: group)
        let header = CleartextEnvelope(type: .nearbyToken, hopLimit: 1,
            sessionId: group.sessionId, sequenceNumber: sequence)
        return try await crypto.sealToWireBytes(payload: payload, envelope: header,
            using: SymmetricKey(data: group.symmetricKeyData))
    }

    private func remove(_ id: String) {
        guard let peer = peers.removeValue(forKey: id) else { return }
        positions.removeValue(forKey: id)
        configuredMembers.remove(id)
        retryAfter[id] = .now.advanced(by: .seconds(8))
        peer.sendTask?.cancel()
        peer.radio.invalidate()
    }

    private func clear() {
        advertisementTask?.cancel()
        advertisementTask = nil
        lastAdvertisement = nil
        for id in Array(peers.keys) { remove(id) }
        retryAfter.removeAll()
        lastSetupIssue = nil
    }

    func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        guard let (id, peer) = peers.first(where: { $0.value.radio === session }),
              let object = nearbyObjects.first(where: { $0.discoveryToken == peer.token }) else { return }
        guard let distance = object.distance, distance.isFinite, distance >= 0 else {
            positions.removeValue(forKey: id)
            return
        }
        let now = ContinuousClock.now
        peer.lastRangingActivity = now
        lastSetupIssue = nil
        let bearing = object.direction.flatMap { direction -> Double? in
            guard direction.x.isFinite, direction.x >= -1, direction.x <= 1 else { return nil }
            return asin(Double(direction.x)) * 180 / .pi
        }
        positions[id] = NearbyOrbitPosition(distance: Double(distance), bearing: bearing, measuredAt: now)
    }

    func session(_ session: NISession, didRemove nearbyObjects: [NINearbyObject], reason: NINearbyObject.RemovalReason) {
        if let (id, peer) = peers.first(where: { $0.value.radio === session }),
           nearbyObjects.contains(where: { $0.discoveryToken == peer.token }) {
            lastSetupIssue = reason == .timeout ? "The UWB session timed out." : "The other iPhone ended the UWB session."
            remove(id)
        }
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
        let code = (error as? NIError)?.code
        if code == .userDidNotAllow {
            permissionDenied = true
            clear()
        } else {
            lastSetupIssue = LocalizedStringResource(stringLiteral: error.localizedDescription)
            if code == .activeSessionsLimitExceeded {
                sessionLimit = max(1, peers.count - 1)
            }
            remove(id)
        }
    }
}
