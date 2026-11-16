//
//  PeerTransportService+Discovery.swift
//  Teekum
//
//  Created by Nicho on 06/11/26.
//

import Foundation
import Network
import WiFiAware

extension PeerTransportService {
    func observePairedDevices(publish: WAPublishableService, subscribe: WASubscribableService, generation: UUID) async {
        while !Task.isCancelled && isCurrentGeneration(generation) {
            do {
                for try await devices in WAPairedDevice.allDevices {
                    guard !Task.isCancelled, isCurrentGeneration(generation) else { return }
                    await updatePairedDevices(devices, publish: publish, subscribe: subscribe, generation: generation)
                }
            } catch {
                guard !Task.isCancelled, isCurrentGeneration(generation) else { return }
                reportRadioFailure(.connectionFailed("Could not read paired iPhones: \(error.localizedDescription)"))
            }
            do { try await Task.sleep(for: .seconds(2)) } catch { return }
        }
    }

    func updatePairedDevices(
        _ devices: WAPairedDevice.Devices,
        publish: WAPublishableService,
        subscribe: WASubscribableService,
        generation: UUID
    ) async {
        guard isCurrentGeneration(generation) else { return }
        let ids = Set(devices.keys)
        guard ids != pairedDeviceIDs else { return }
        pairedDeviceIDs = ids
        let discovery = UUID()
        discoveryGeneration = discovery
        let oldDiscovery = discoveryTask
        oldDiscovery?.cancel()
        discoveryTask = nil
        discoveredEndpoints.removeAll()
        nextDial = nextDial.filter { ids.contains($0.key) }
        for (id, token) in dialAttempts where !ids.contains(id) { linkTasks[token]?.cancel() }
        for peer in connections.values where !ids.contains(peer.deviceID) { linkTasks[peer.token]?.cancel() }
        await oldDiscovery?.value
        guard isCurrentGeneration(generation), !Task.isCancelled, !ids.isEmpty else { return }
        logEvent("Wi-Fi Aware discovery scheduled for \(ids.count) paired devices.", level: .info)

        discoveryTask = Task { [weak self] in
            await withTaskGroup(of: Void.self) { tasks in
                tasks.addTask { [weak self] in
                    await self?.listen(publish, devices: devices, generation: generation, discovery: discovery)
                }
                tasks.addTask { [weak self] in
                    await self?.browse(subscribe, devices: devices, generation: generation, discovery: discovery)
                }
            }
        }
    }

    private func listen(
        _ service: WAPublishableService,
        devices: WAPairedDevice.Devices,
        generation: UUID,
        discovery: UUID
    ) async {
        while !Task.isCancelled && isCurrentGeneration(generation) && discovery == discoveryGeneration {
            do {
                let listener = try NetworkListener(
                    for: .wifiAware(.connecting(to: service, from: .selected(devices))),
                    using: tcpParameters()
                )
                listener.onStateUpdate { [weak self] _, state in
                    guard case .waiting(let error) = state else { return }
                    Task { await self?.reportDiscoveryIssue(.listenerFailed(error.localizedDescription), generation: generation, discovery: discovery) }
                }
                try await listener.run { [weak self] connection in
                    guard let task = await self?.attachIncoming(connection, generation: generation, discovery: discovery) else { return }
                    await withTaskCancellationHandler {
                        await task.value
                    } onCancel: {
                        task.cancel()
                    }
                }
            } catch {
                guard !Task.isCancelled, isCurrentGeneration(generation), discovery == discoveryGeneration else { return }
                reportRadioFailure(.listenerFailed(error.localizedDescription))
            }
            do { try await Task.sleep(for: .seconds(2)) } catch { return }
        }
    }

    private func browse(
        _ service: WASubscribableService,
        devices: WAPairedDevice.Devices,
        generation: UUID,
        discovery: UUID
    ) async {
        while !Task.isCancelled && isCurrentGeneration(generation) && discovery == discoveryGeneration {
            do {
                let browser = NetworkBrowser(for: .wifiAware(.connecting(to: .selected(devices), from: service)))
                browser.onStateUpdate { [weak self] _, state in
                    guard case .waiting(let error) = state else { return }
                    Task { await self?.reportDiscoveryIssue(.browserFailed(error.localizedDescription), generation: generation, discovery: discovery) }
                }
                try await browser.run { [weak self] endpoints in
                    await self?.updateBrowseResults(endpoints, generation: generation, discovery: discovery)
                }
            } catch {
                guard !Task.isCancelled, isCurrentGeneration(generation), discovery == discoveryGeneration else { return }
                reportRadioFailure(.browserFailed(error.localizedDescription))
            }
            guard isCurrentGeneration(generation), discovery == discoveryGeneration else { return }
            discoveredEndpoints.removeAll()
            do { try await Task.sleep(for: .seconds(2)) } catch { return }
        }
    }

    private func updateBrowseResults(_ endpoints: [WAEndpoint], generation: UUID, discovery: UUID) {
        guard isCurrentGeneration(generation), discovery == discoveryGeneration, !Task.isCancelled else { return }
        discoveredEndpoints = Dictionary(
            endpoints.lazy.filter { self.pairedDeviceIDs.contains($0.device.id) }.map { ($0.device.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        connectDiscoveredPeers(generation: generation)
    }

    func connectDiscoveredPeers(generation: UUID) {
        guard isCurrentGeneration(generation), !Task.isCancelled else { return }
        let attached = Set(connections.values.map(\.deviceID))
        let now = ContinuousClock.now
        for (id, endpoint) in discoveredEndpoints where !attached.contains(id) && dialAttempts[id] == nil {
            guard nextDial[id].map({ $0 <= now }) ?? true else { continue }
            let token = UUID()
            dialAttempts[id] = token
            let connection = NetworkConnection(to: endpoint, using: tcpParameters())
            attach(connection, token: token, dialedDeviceID: id, generation: generation)
        }
    }

    private func attachIncoming(
        _ connection: NetworkConnection<TCP>,
        generation: UUID,
        discovery: UUID
    ) -> Task<Void, Never>? {
        guard isCurrentGeneration(generation), discovery == discoveryGeneration, !Task.isCancelled else { return nil }
        return attach(connection, token: UUID(), dialedDeviceID: nil, generation: generation)
    }

    private func tcpParameters() -> NWParametersBuilder<TCP> {
        .parameters {
            TCP().noDelay(true).keepalive(idleTimeInSeconds: 5, count: 3, intervalInSeconds: 2)
                .connectionTimeout(6).retransmitConnectionDropTime(6)
        }.wifiAware { $0.performanceMode = .bulk }
    }

    private func reportDiscoveryIssue(_ error: TransportError, generation: UUID, discovery: UUID) {
        guard isCurrentGeneration(generation), discovery == discoveryGeneration,
              lastErrorMessage != error.localizedDescription else { return }
        reportRadioFailure(error)
    }
}
