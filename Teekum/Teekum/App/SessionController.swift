//
//  SessionController.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 11/11/26.
//

import CoreLocation
import Foundation
import Observation

/// App composition and session lifetimes. Feature state and packet rules remain with their owners.
@MainActor
@Observable
final class SessionController {
    let store: SessionStore
    let location: LocationService
    let transport: PeerTransportService
    let relayPolicy: RelayPolicyManager
    let chat: ChatViewModel
    let sos: SOSViewModel
    let meeting: MeetingPointService
    let notifications = NotificationService()
    private(set) var relayState = RelayPolicyState(mode: .disabled)
    private(set) var diagnostics: TransportDiagnostics?
    var errorMessage: String?
    var isTransitioning = false
    var isShowingGroupSwitch = false

    private let holder: SessionHolder
    private let crypto = CryptoService()
    private let sequences = PacketSequenceAllocator()
    private let routes: RouteDiscoveryService
    private let chatEngine: ChatMessageEngine
    private let sosEngine: SOSForwardingEngine
    private let seen = SeenPacketCache()
    private let persistence = SessionPersistence()
    private let liveActivity = LiveActivityManager()
    private var publisher: LocationPublisher?
    private var router: PacketRouter?
    private var sessionTask: Task<Void, Never>?
    private var transitionTask: Task<Void, Never>?
    private var generation = UUID()
    private var didRestore = false
    private var directPeers: Set<String> = []
    private var routeProbes: [String: Task<Void, Never>] = [:]

    init(store: SessionStore = SessionStore()) {
        self.store = store
        let holder = SessionHolder()
        self.holder = holder
        let location = LocationService()
        self.location = location
        let transport = PeerTransportService()
        self.transport = transport
        relayPolicy = RelayPolicyManager(transport: transport)
        let routing = RoutingTable()
        routes = RouteDiscoveryService(routingTable: routing, neighborTable: transport.neighborTable,
            transport: transport, cryptoService: crypto, sequenceAllocator: sequences)
        let chatEngine = ChatMessageEngine(transport: transport, cryptoService: crypto,
            routingTable: routing, neighborTable: transport.neighborTable, rateLimiter: transport.rateLimiter,
            sequenceAllocator: sequences)
        self.chatEngine = chatEngine
        chat = ChatViewModel(service: chatEngine, sessionProvider: { holder.session })
        let sosEngine = SOSForwardingEngine(transport: transport, cryptoService: crypto,
            routingTable: routing, neighborTable: transport.neighborTable, rateLimiter: transport.rateLimiter,
            sequenceAllocator: sequences, sessionProvider: { holder.session }, audioAlerter: DefaultSOSAudioAlerter())
        self.sosEngine = sosEngine
        sos = SOSViewModel(engine: sosEngine, locationService: location, sessionProvider: { holder.session })
        meeting = MeetingPointService(sessionStore: store, cryptoService: crypto, transport: transport,
            sequenceAllocator: sequences)
        sos.onIncomingAlert = { [weak self] alert in
            guard let self, holder.session != nil else { return }
            store.setEmergency(true, for: alert.senderInitials)
            notifications.notify(title: "SOS from \(alert.senderInitials)", body: alert.emergencyType.title, showBanner: false)
        }
        sos.onIncomingSOSResolved = { [weak store] initials in
            store?.setEmergency(false, for: initials)
        }
    }

    func restore() async {
        guard !didRestore, ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
        didRestore = true
        do {
            if let session = try await persistence.load(), store.activeSession == nil {
                transition(to: session, acceptedConsent: false)
            } else {
                await liveActivity.stop()
            }
        } catch { errorMessage = "Unable to restore your group. Please join again." }
    }

    func activate(_ session: GroupSession) { transition(to: session, acceptedConsent: true) }
    func leave() { transition(to: nil, acceptedConsent: false) }

    func joinPendingInvite() {
        guard let invite = store.pendingInvite else { return }
        leave()
        store.pendingInvite = invite
        isShowingGroupSwitch = false
    }

    func cancelPendingInvite() {
        store.pendingInvite = nil
        isShowingGroupSwitch = false
    }

    private func transition(to session: GroupSession?, acceptedConsent: Bool) {
        generation = UUID()
        let current = generation
        router?.stop()
        holder.session = nil
        let previous = transitionTask
        previous?.cancel()
        let oldSessionTask = sessionTask
        oldSessionTask?.cancel()
        for probe in routeProbes.values { probe.cancel() }
        routeProbes.removeAll()
        sessionTask = nil
        store.resetSessionState()
        store.activeSession = session
        errorMessage = nil
        isTransitioning = true
        transitionTask = Task { [weak self] in
            await previous?.value
            await oldSessionTask?.value
            guard let self else { return }
            await stopServices()
            guard generation == current, !Task.isCancelled else { return }
            guard let session else {
                do { try await persistence.clear() }
                catch { errorMessage = "Your group was left, but its saved key could not be removed." }
                guard generation == current else { return }
                isTransitioning = false
                return
            }
            do {
                try await persistence.save(session)
                guard generation == current, !Task.isCancelled else { return }
                holder.session = session
                if acceptedConsent { await relayPolicy.setParticipationMode(.communalRelayActive) }
                await prepareServices(session, generation: current)
                guard generation == current, !Task.isCancelled else { return }
                isTransitioning = false
                sessionTask = Task { [weak self] in
                    guard let self else { return }
                    await consumeSession(session, generation: current)
                }
            } catch {
                guard generation == current else { return }
                holder.session = nil
                store.resetSessionState()
                errorMessage = error.localizedDescription
                isTransitioning = false
                await stopServices()
            }
        }
    }

    private func prepareServices(_ session: GroupSession, generation current: UUID) async {
        guard generation == current, !Task.isCancelled else { return }
        do { try location.startTracking() }
        catch { errorMessage = error.localizedDescription }
        await notifications.requestAuthorization()
        guard generation == current, !Task.isCancelled else { return }
        await relayPolicy.synchronizePersistedParticipation()
        await updatePower()
        await chatEngine.configure(sessionProvider: { [holder] in holder.session }, recipientsProvider: { [weak store] in
            store?.members.map(\.id) ?? []
        })
        await chat.start()
        await sos.start()
        guard generation == current, !Task.isCancelled else { return }
        do { try await transport.start(serviceType: "_teekum._tcp", session: session) }
        catch { errorMessage = error.localizedDescription }
        guard generation == current, !Task.isCancelled else { return }
        location.hasDistantPeersProvider = { [weak self] in self?.hasDistantMembers ?? false }
        location.hasStalePeersProvider = { [weak store] in store?.members.contains { $0.isWithinStaleRecoveryWindow() } ?? false }
        await routes.setOnTargetReached { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, generation == current else { return }
                location.triggerBurstPings()
            }
        }
        let publisher = LocationPublisher(locationService: location, sessionProvider: { [holder] in holder.session },
            cryptoService: crypto, transport: transport, sequenceAllocator: sequences)
        self.publisher = publisher
        publisher.start()
        router = makeRouter(generation: current)
        await liveActivity.start(session: session)
    }

    private func stopServices() async {
        router?.stop()
        router = nil
        publisher?.stop()
        publisher = nil
        holder.session = nil
        meeting.reset()
        notifications.clear()
        await liveActivity.stop()
        location.clearSessionMeasurements()
        await chat.stop()
        await chatEngine.configure(sessionProvider: nil)
        await chatEngine.clearHistory()
        await sos.stop()
        await transport.stop()
        await routes.setOnTargetReached(nil)
        await routes.teardown()
        await seen.removeAll()
        diagnostics = nil
        directPeers.removeAll()
    }

    private func consumeSession(_ session: GroupSession, generation current: UUID) async {
        guard let router else { return }
        let inbound = await transport.inboundPackets
        let peers = await transport.peerUpdates
        await withTaskGroup(of: Void.self) { tasks in
            tasks.addTask { [weak self] in
                await self?.consumeInbound(inbound, router: router, session: session, generation: current)
            }
            tasks.addTask { [weak self] in
                await self?.consumePeers(peers, generation: current)
            }
            tasks.addTask { [weak self] in
                await self?.maintainSession(session, generation: current)
            }
        }
    }

    private func consumeInbound(_ inbound: AsyncStream<InboundPacket>, router: PacketRouter,
                                session: GroupSession, generation current: UUID) async {
        for await packet in inbound {
            guard generation == current, !Task.isCancelled else { break }
            await router.routeInboundPacket(packet, for: session)
        }
    }

    private func consumePeers(_ peers: AsyncStream<[PeerInfo]>, generation current: UUID) async {
        for await update in peers {
            guard generation == current, !Task.isCancelled else { break }
            await acceptPeerUpdate(update)
        }
    }

    private func maintainSession(_ session: GroupSession, generation current: UUID) async {
        var lastGlobalProbe = Date.distantPast
        var lastProbe: [String: Date] = [:]
        while !Task.isCancelled {
            do { try await Task.sleep(for: .seconds(1)) } catch { break }
            guard generation == current else { break }
            await updatePower()
            let snapshot = await transport.getDiagnostics()
            guard generation == current else { break }
            diagnostics = snapshot
            let losses = store.refreshMemberVisibility(now: .now, peers: snapshot.activeDirectPeers)
            if !losses.isEmpty {
                let initials = losses.map(\.initials).formatted(.list(type: .and))
                notifications.notify(title: "Group activity", body: "Lost contact with \(initials).")
            }
            meeting.checkExpiration()
            if let coordinate = location.currentLocation?.coordinate { meeting.checkArrival(userLocation: coordinate) }
            let stale = store.members.contains { $0.isWithinStaleRecoveryWindow() }
            if location.hasStalePeers != stale {
                location.hasStalePeers = stale
                if stale { location.triggerCadenceEvaluation() }
            }
            await liveActivity.update(peerCount: store.visibleMembers.count + 1, unreadCount: chat.unreadCount,
                meeting: store.activeMeetingPoint, location: location.currentLocation,
                sosSender: sos.outgoingEventId != nil ? session.localInitials : store.members.first(where: \.isEmergency)?.id,
                relay: relayState)
            guard generation == current else { break }
            let now = Date.now
            if now.timeIntervalSince(lastGlobalProbe) >= MeshTimingConfiguration.default.staleRouteReqStaggerInterval,
               let target = store.members.filter({
                   routeProbes[$0.id] == nil && $0.isEligibleForStaleRouteDiscovery() && now.timeIntervalSince(lastProbe[$0.id] ?? .distantPast) >= 10
               }).min(by: { $0.lastSeen < $1.lastSeen }) {
                lastGlobalProbe = now
                lastProbe[target.id] = now
                let id = target.id
                routeProbes[id] = Task { [weak self, routes] in
                    guard !Task.isCancelled else { return }
                    _ = try? await routes.initiateDiscovery(to: id, session: session, timeout: 3)
                    guard let self, generation == current else { return }
                    routeProbes.removeValue(forKey: id)
                }
            }
        }
    }

    private func makeRouter(generation current: UUID) -> PacketRouter {
        PacketRouter(cryptoService: crypto, peerTransport: transport, relayPolicyManager: relayPolicy,
            routeDiscoveryService: routes, seenPacketCache: seen,
            onLocationPing: { [weak self] ping, inbound in
                guard let self, generation == current else { return }
                store.applyLocationPing(ping, inbound: inbound)
            }, onSOS: { [weak self] payload, inbound in
                guard let self, generation == current else { return }
                store.applySOSLocation(payload, inbound: inbound)
                try? await sosEngine.handleInboundSOSPacket(rawPacket: inbound.rawPacket, fromPeerId: inbound.sourcePeerId)
            }, onACK: { [weak self] inbound in
                guard let self, generation == current else { return }
                await sosEngine.handleInboundACK(rawPacket: inbound.rawPacket, fromPeerId: inbound.sourcePeerId)
                guard generation == current else { return }
                _ = await chatEngine.processDeliveryACK(rawPacket: inbound.rawPacket, fromPeerId: inbound.sourcePeerId)
            }, onMeetingUpdate: { [weak self] update in
                guard let self, generation == current, meeting.applyInboundUpdate(update) else { return }
                if update.senderInitials != store.activeSession?.localInitials {
                    switch update.action {
                    case .propose:
                        notifications.notify(title: "Meeting point", body: "\(update.senderInitials) updated the group rendezvous.")
                    case .cancel:
                        notifications.notify(title: "Meeting point", body: "\(update.senderInitials) cancelled the group rendezvous.")
                    case .accept, .decline:
                        break
                    }
                }
            }, onChat: { [weak self] inbound in
                guard let self, generation == current,
                      let outcome = try? await chatEngine.handleInboundPacket(inbound, relay: false) else { return }
                guard generation == current else { return }
                if let message = outcome.deliveredMessage, !chat.isChatSheetPresented {
                    notifications.notify(title: message.senderInitials, body: message.text)
                }
            }, onSOSResolved: { [weak self] event in
                guard let self, generation == current else { return }
                await sos.acceptResolution(event)
            })
    }

    private func acceptPeerUpdate(_ peers: [PeerInfo]) async {
        let current = generation
        let connected = Set(peers.filter(\.isDirectLink).map(\.id))
        let disconnected = directPeers.subtracting(connected)
        let newlyConnected = connected.subtracting(directPeers)
        directPeers = connected
        for peer in disconnected {
            await routes.handleNeighborDisconnected(peerId: peer)
            guard generation == current else { return }
        }
        store.applyPeerSnapshot(peers, connected: connected)
        if !connected.isEmpty {
            location.publishCurrentState()
        }
        if !newlyConnected.isEmpty {
            await meeting.syncActiveMeetingPointToPeers()
        }
    }

    private var hasDistantMembers: Bool {
        store.members.contains { member in
            if let rssi = member.rssi, rssi <= MeshTimingConfiguration.default.distantRSSIThreshold { return true }
            guard let local = location.currentLocation, let coordinate = member.coordinate else { return false }
            return local.distance(to: coordinate) >= MeshTimingConfiguration.default.distantDistanceThresholdMeters
        }
    }

    func updatePower() async {
        location.updateBatteryState()
        await relayPolicy.updatePowerMetrics(batteryLevel: location.currentBatteryLevel, isLowPowerMode: location.isLowPowerMode)
        await transport.updateCarryPowerMetrics(location.currentBatteryLevel, isLowPowerMode: location.isLowPowerMode)
        await chatEngine.setBatteryLevel(location.currentBatteryLevel, isLowPowerMode: location.isLowPowerMode)
        chat.updateBattery(level: location.currentBatteryLevel, isLowPower: location.isLowPowerMode)
        relayState = await relayPolicy.currentState()
    }

    func handleURL(_ url: URL) {
        if url.scheme == "teekum", url.host == "session" { leave(); return }
        if url.scheme == "teekum", ["meeting", "sos"].contains(url.host ?? ""), store.hasActiveSession {
            store.pendingDeepLink = url
            return
        }
        if let invite = GroupSession.parseInvite(from: url) {
            store.pendingInvite = invite
            isShowingGroupSwitch = store.hasActiveSession
        }
    }
}
