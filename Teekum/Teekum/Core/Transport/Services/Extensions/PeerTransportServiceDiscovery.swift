//
//  PeerTransportServiceDiscovery.swift
//  Teekum
//
//  Created by Nicho on 06/11/26.
//

import Foundation
import Network

// MARK: - Bonjour Discovery, Advertising & Tie-Breaking

extension PeerTransportService {
    
    // MARK: - Network Parameters
    
    func createParameters() -> NWParameters {
        let params: NWParameters
        if isUDP {
            params = NWParameters.udp
        } else {
            let tcpOptions = NWProtocolTCP.Options()
            tcpOptions.enableKeepalive = true
            tcpOptions.keepaliveIdle = 5
            tcpOptions.keepaliveInterval = 2
            tcpOptions.keepaliveCount = 3
            params = NWParameters(tls: nil, tcp: tcpOptions)
        }
        params.includePeerToPeer = true
        return params
    }
    
    // MARK: - Bonjour Listener & Browser Setup
    
    func startListener() throws {
        guard let session = activeSession else { return }
        
        let params = createParameters()
        let newListener = try NWListener(using: params)
        
        // Encode metadata in Bonjour TXT record
        var txtDict: [String: Data] = [:]
        txtDict["sid"] = String(format: "%08X", session.sessionId).data(using: .utf8)
        txtDict["name"] = session.localMemberName.data(using: .utf8)
        txtDict["relay"] = (isRelayEnabled ? "1" : "0").data(using: .utf8)
        let txtData = NetService.data(fromTXTRecord: txtDict)
        
        newListener.service = NWListener.Service(
            name: localPeerId,
            type: serviceType,
            domain: nil,
            txtRecord: txtData
        )
        
        let generation = radioGeneration
        newListener.stateUpdateHandler = { [weak self] state in
            Task {
                guard await self?.isCurrentGeneration(generation) == true else { return }
                await self?.handleListenerState(state)
            }
        }
        
        newListener.newConnectionHandler = { [weak self] connection in
            Task {
                guard await self?.isCurrentGeneration(generation) == true else { connection.cancel(); return }
                await self?.handleIncomingConnection(connection)
            }
        }
        
        newListener.start(queue: dispatchQueue)
        self.listener = newListener
    }
    
    func startBrowser() throws {
        let params = createParameters()
        let descriptor = NWBrowser.Descriptor.bonjourWithTXTRecord(type: serviceType, domain: nil)
        let newBrowser = NWBrowser(for: descriptor, using: params)
        
        let generation = radioGeneration
        newBrowser.stateUpdateHandler = { [weak self] state in
            Task {
                guard await self?.isCurrentGeneration(generation) == true else { return }
                await self?.handleBrowserState(state)
            }
        }
        
        newBrowser.browseResultsChangedHandler = { [weak self] results, changes in
            Task {
                guard await self?.isCurrentGeneration(generation) == true else { return }
                await self?.handleBrowseResults(results, changes: changes)
            }
        }
        
        newBrowser.start(queue: dispatchQueue)
        self.browser = newBrowser
    }
    
    // MARK: - State Handlers
    
    func restartListener(generation: UUID) {
        guard isCurrentGeneration(generation), currentState != .stopped else { return }
        listener?.cancel()
        listener = nil
        do {
            try startListener()
            logEvent("NWListener successfully restarted.", level: .info)
        } catch {
            logEvent("NWListener restart failed: \(error.localizedDescription)", level: .error)
        }
    }
    
    func restartBrowser(generation: UUID) {
        guard isCurrentGeneration(generation), currentState != .stopped else { return }
        browser?.cancel()
        browser = nil
        do {
            try startBrowser()
            logEvent("NWBrowser successfully restarted.", level: .info)
        } catch {
            logEvent("NWBrowser restart failed: \(error.localizedDescription)", level: .error)
        }
    }
    
    func handleListenerState(_ state: NWListener.State) {
        switch state {
        case .ready:
            logEvent("NWListener ready on AWDL interface.", level: .info)
        case let .failed(error):
            let err = TransportError.listenerFailed(error.localizedDescription)
            logEvent("NWListener failed: \(error)", level: .error)
            if activeSession != nil, currentState != .stopped {
                logEvent("NWListener failed during active session, scheduling recovery restart...", level: .warning)
                let generation = radioGeneration
                listenerRecoveryTask?.cancel()
                listenerRecoveryTask = Task { [weak self] in
                    do { try await Task.sleep(for: .seconds(1)) } catch { return }
                    await self?.restartListener(generation: generation)
                }
            } else {
                updateState(.failed(err))
                transportErrorsContinuation?.yield(err)
            }
        case .cancelled:
            logEvent("NWListener cancelled.", level: .info)
        default:
            break
        }
    }
    
    func handleBrowserState(_ state: NWBrowser.State) {
        switch state {
        case .ready:
            logEvent("NWBrowser scanning for Bonjour service '\(serviceType)'.", level: .info)
        case let .failed(error):
            let err = TransportError.browserFailed(error.localizedDescription)
            logEvent("NWBrowser failed: \(error)", level: .error)
            if activeSession != nil, currentState != .stopped {
                logEvent("NWBrowser failed during active session, scheduling recovery restart...", level: .warning)
                let generation = radioGeneration
                browserRecoveryTask?.cancel()
                browserRecoveryTask = Task { [weak self] in
                    do { try await Task.sleep(for: .seconds(1)) } catch { return }
                    await self?.restartBrowser(generation: generation)
                }
            } else {
                updateState(.failed(err))
                transportErrorsContinuation?.yield(err)
            }
        case .cancelled:
            logEvent("NWBrowser cancelled.", level: .info)
        default:
            break
        }
    }
    
    // MARK: - Discovery & Tie-Breaking
    
    func handleBrowseResults(_ results: Set<NWBrowser.Result>, changes: Set<NWBrowser.Result.Change>) {
        guard let session = activeSession else { return }
        latestBrowseResults = results
        
        var currentDiscovered: [String: (endpoint: NWEndpoint, displayName: String?, isGroup: Bool)] = [:]
        
        for result in results {
            guard case let .service(name, _, _, _) = result.endpoint else { continue }
            let remotePeerId = name
            
            // 1. Prevent connecting to self or loopback ghosts from previous session
            guard remotePeerId != localPeerId, !remotePeerId.starts(with: localPeerId) else { continue }
            
            // 2. Check session ID from TXT record if present
            var remoteName: String?
            var isGroup = false
            var isRemoteRelayEnabled = true // default true for backwards compatibility
            if case let .bonjour(txtRecord) = result.metadata {
                if let sidStr = txtRecord.dictionary["sid"] {
                    let expectedSid = String(format: "%08X", session.sessionId)
                    isGroup = (sidStr.uppercased() == expectedSid.uppercased())
                }
                if let name = txtRecord.dictionary["name"] {
                    remoteName = name
                }
                if let relayStr = txtRecord.dictionary["relay"] {
                    isRemoteRelayEnabled = (relayStr == "1")
                }
            }
            
            // If communal relaying is disabled locally, or remote stranger has relay disabled, do not peer
            if !isGroup {
                guard isRelayEnabled && isRemoteRelayEnabled else {
                    continue
                }
            }
            
            currentDiscovered[remotePeerId] = (result.endpoint, remoteName, isGroup)
        }
        
        self.discoveredEndpoints = currentDiscovered
        
        // Evaluate connection initiation for discovered peers
        for (remotePeerId, info) in currentDiscovered {
            // Check if connection already exists
            if let existing = connections[remotePeerId] {
                if existing.isReady {
                    continue // Connection is already established and healthy
                }
            }
            
            // Reconcile pre-discovery inbound link if it arrived before NWBrowser completed
            if localPeerId > remotePeerId {
                if let inboundEntry = connections.first(where: { $0.key.starts(with: "inbound-") }) {
                    let inboundConn = inboundEntry.value
                    connections.removeValue(forKey: inboundEntry.key)
                    inboundConn.peerId = remotePeerId
                    inboundConn.displayName = info.displayName ?? "Peer-\(remotePeerId.prefix(3))"
                    inboundConn.isGroupMember = info.isGroup
                    connections[remotePeerId] = inboundConn
                    logEvent("Matched pre-discovery inbound link to peer \(remotePeerId) (group: \(info.isGroup)).", level: .info)
                    
                    Task {
                        await neighborTable.registerOrUpdateNeighbor(
                            id: remotePeerId,
                            displayName: inboundConn.displayName,
                            state: inboundConn.isReady ? .connected : .connecting,
                            rssi: nil,
                            isGroupMember: info.isGroup,
                            capabilities: inboundConn.capabilities
                        )
                    }
                    emitPeerUpdates()
                    continue
                }
            }
            
            // Deterministic Tie-Breaking:
            // The peer with the smaller peerId initiates the outbound connection.
            // The peer with the larger peerId waits for the incoming connection.
            if localPeerId < remotePeerId {
                logEvent("Discovered peer \(remotePeerId) (Initiator role: local < remote, group: \(info.isGroup)). Connecting...", level: .info)
                initiateOutboundConnection(to: info.endpoint, peerId: remotePeerId, displayName: info.displayName, isGroupMember: info.isGroup)
            } else {
                logEvent("Discovered peer \(remotePeerId) (Listener role: local > remote, group: \(info.isGroup)). Awaiting incoming link.", level: .info)
                // Schedule fallback connection in case remote is delayed
                scheduleFallbackConnection(to: info.endpoint, peerId: remotePeerId, displayName: info.displayName, isGroupMember: info.isGroup)
            }
        }
    }
    
    func scheduleFallbackConnection(to endpoint: NWEndpoint, peerId: String, displayName: String?, isGroupMember: Bool) {
        let generation = radioGeneration
        fallbackTasks[peerId]?.cancel()
        fallbackTasks[peerId] = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(3.5)) } catch { return }
            await self?.checkAndFallbackConnect(to: endpoint, peerId: peerId, displayName: displayName,
                isGroupMember: isGroupMember, generation: generation)
        }
    }
    
    func checkAndFallbackConnect(to endpoint: NWEndpoint, peerId: String, displayName: String?, isGroupMember: Bool, generation: UUID) {
        guard isCurrentGeneration(generation), currentState != .stopped else { return }
        fallbackTasks.removeValue(forKey: peerId)
        guard discoveredEndpoints[peerId] != nil else { return }
        
        if let conn = connections[peerId], conn.isReady {
            return // Successfully connected in the meantime
        }
        
        logEvent("Fallback connection trigger for peer \(peerId). Initiating outbound link.", level: .info)
        initiateOutboundConnection(to: endpoint, peerId: peerId, displayName: displayName, isGroupMember: isGroupMember)
    }
}
