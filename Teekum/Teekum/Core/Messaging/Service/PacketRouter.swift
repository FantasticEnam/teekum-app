import Foundation
import CryptoKit

/// Authenticates group traffic and owns forwarding; feature handlers receive accepted inputs.
@MainActor
public final class PacketRouter {
    private let cryptoService: any CryptoServiceProtocol
    private let peerTransport: any PeerTransport & MeshTransport
    private let relayPolicyManager: RelayPolicyManager
    private let routeDiscoveryService: RouteDiscoveryService
    private let seenPacketCache: SeenPacketCache
    private let onLocationPing: (LocationPingPayload, InboundPacket) -> Void
    private let onSOS: (SOSPayload, InboundPacket) async -> Void
    private let onACK: (InboundPacket) async -> Void
    private let onMeetingUpdate: (MeetingUpdatePayload) -> Void
    private let onChat: (InboundPacket) async -> Void
    private var isActive = true

    public init(
        cryptoService: any CryptoServiceProtocol,
        peerTransport: any PeerTransport & MeshTransport,
        relayPolicyManager: RelayPolicyManager,
        routeDiscoveryService: RouteDiscoveryService,
        seenPacketCache: SeenPacketCache,
        onLocationPing: @escaping (LocationPingPayload, InboundPacket) -> Void,
        onSOS: @escaping (SOSPayload, InboundPacket) async -> Void,
        onACK: @escaping (InboundPacket) async -> Void,
        onMeetingUpdate: @escaping (MeetingUpdatePayload) -> Void,
        onChat: @escaping (InboundPacket) async -> Void
    ) {
        self.cryptoService = cryptoService
        self.peerTransport = peerTransport
        self.relayPolicyManager = relayPolicyManager
        self.routeDiscoveryService = routeDiscoveryService
        self.seenPacketCache = seenPacketCache
        self.onLocationPing = onLocationPing
        self.onSOS = onSOS
        self.onACK = onACK
        self.onMeetingUpdate = onMeetingUpdate
        self.onChat = onChat
    }

    public func stop() {
        isActive = false
    }

    public func routeInboundPacket(_ inbound: InboundPacket, for session: GroupSession) async {
        guard isActive else { return }
        let raw = inbound.rawPacket
        let envelope = raw.envelope
        guard envelope.version == PacketConstants.protocolVersion, envelope.hopCount <= envelope.hopLimit else { return }
        guard envelope.sessionId == session.sessionId else {
            await handleStrangerRelayPacket(inbound)
            return
        }

        guard let decrypted = try? await cryptoService.open(
            ciphertext: raw.ciphertext,
            envelope: envelope,
            authTag: raw.authTag,
            using: SymmetricKey(data: session.symmetricKeyData)
        ) else {
            // Prototype fallback: a same-SID SOS with a different key can still travel opaquely.
            if envelope.type == .sos { await relayMeshPacketIfNeeded(inbound, for: session) }
            return
        }
        guard isActive else { return }

        switch envelope.type {
        case .ack:
            guard let ack = try? ACKPayload.deserialize(from: decrypted),
                  abs(Date().timeIntervalSince(ack.ackTimestamp)) <= CarryMessageStore.retention,
                  ack.responderInitials != session.localInitials else { return }
            await onACK(inbound)
            guard isActive else { return }
            await peerTransport.retainReceivedForCarry(raw, excludingPeerId: inbound.sourcePeerId)
            await relayMeshPacketIfNeeded(inbound, for: session)

        case .sos:
            guard let payload = try? SOSPayload.deserialize(from: decrypted),
                  payload.senderInitials != session.localInitials else { return }
            await onSOS(payload, inbound)
            await relayMeshPacketIfNeeded(inbound, for: session)

        case .locationPing:
            guard let ping = try? LocationPingPayload.deserialize(from: decrypted),
                  ping.senderInitials != session.localInitials else { return }
            onLocationPing(ping, inbound)
            await relayMeshPacketIfNeeded(inbound, for: session)

        case .meetingUpdate:
            guard let update = try? MeetingUpdatePayload.deserialize(from: decrypted) else { return }
            onMeetingUpdate(update)
            await relayMeshPacketIfNeeded(inbound, for: session)

        case .routeReq:
            guard let wireData = try? raw.toWireData() else { return }
            _ = try? await routeDiscoveryService.handleInboundRouteReq(
                wireData: wireData, fromPeerId: inbound.sourcePeerId, session: session
            )

        case .routeResp:
            guard let wireData = try? raw.toWireData() else { return }
            _ = try? await routeDiscoveryService.handleInboundRouteResp(
                wireData: wireData, fromPeerId: inbound.sourcePeerId, session: session
            )

        case .chatMessage:
            guard let chat = try? ChatMessagePayload.deserialize(from: decrypted),
                  abs(Date().timeIntervalSince(chat.timestamp)) <= CarryMessageStore.retention,
                  chat.senderInitials != session.localInitials else { return }
            await peerTransport.retainReceivedForCarry(raw, excludingPeerId: inbound.sourcePeerId)
            guard isActive else { return }
            await onChat(inbound)
            await relayMeshPacketIfNeeded(inbound, for: session)

        case .uwbTokenExchange:
            break
        }
    }

    public func relayMeshPacketIfNeeded(_ inbound: InboundPacket, for session: GroupSession) async {
        let envelope = inbound.rawPacket.envelope
        guard isActive, envelope.hopCount < envelope.hopLimit,
              envelope.memberSlot != session.memberSlot else { return }
        let duplicate = await seenPacketCache.isDuplicateAndRecord(PacketKey(wirePacket: inbound.rawPacket))
        guard !duplicate, isActive else { return }
        var packet = inbound.rawPacket
        packet.envelope.hopCount += 1
        guard let data = try? packet.toWireData() else { return }
        try? await peerTransport.broadcastPacket(data)
    }

    public func handleStrangerRelayPacket(_ inbound: InboundPacket) async {
        guard isActive else { return }
        let policy = await relayPolicyManager.currentState()
        guard policy.isRelayPermitted, isActive else {
            await relayPolicyManager.recordDropEvent(reason: .policyDisabled)
            return
        }
        let packet = inbound.rawPacket
        guard packet.envelope.hopCount < packet.envelope.hopLimit else {
            await relayPolicyManager.recordDropEvent(reason: .hopLimitExceeded)
            return
        }
        await peerTransport.retainReceivedForCarry(packet, excludingPeerId: inbound.sourcePeerId)
        guard isActive else { return }
        let duplicate = await seenPacketCache.isDuplicateAndRecord(PacketKey(wirePacket: packet))
        guard !duplicate, isActive else {
            if duplicate { await relayPolicyManager.recordDropEvent(reason: .duplicate) }
            return
        }
        guard let data = try? packet.toWireData() else { return }
        let neighbors = await peerTransport.activeNeighbors()
        var forwarded = false
        for peer in neighbors where peer.id != inbound.sourcePeerId {
            guard isActive else { return }
            if (try? await peerTransport.forwardFrame(data, to: peer.id)) != nil { forwarded = true }
        }
        if forwarded { await relayPolicyManager.recordForwardEvent(type: packet.envelope.type) }
    }
}
