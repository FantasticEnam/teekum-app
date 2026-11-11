//
//  SOSViewModel.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 11/11/26.
//

import Foundation
import CoreLocation
import Observation

@MainActor
@Observable
final class SOSViewModel {
    private let engine: SOSForwardingEngine
    private let locationService: any LocationServiceProtocol
    private let sessionProvider: @MainActor () -> GroupSession?
    private var generation = UUID()
    private var dispatchTask: Task<Void, Never>?
    private var feedbackTask: Task<Void, Never>?

    let inactivityGuard: InactivityGuardService
    private(set) var deliveryState: SOSDeliveryState = .idle
    private(set) var incomingAlert: IncomingSOSAlert?
    private(set) var isSending = false
    var onIncomingAlert: (@MainActor (IncomingSOSAlert) -> Void)?
    var onIncomingAlertDismissed: (@MainActor (String) -> Void)?

    init(
        engine: SOSForwardingEngine,
        locationService: any LocationServiceProtocol,
        sessionProvider: @escaping @MainActor () -> GroupSession?
    ) {
        self.engine = engine
        self.locationService = locationService
        self.sessionProvider = sessionProvider
        inactivityGuard = InactivityGuardService()
        inactivityGuard.onTriggerSOS = { [weak self] in self?.triggerSOS(emergencyType: .inactivity) }
    }

    func start() async {
        generation = UUID()
        let current = generation
        await engine.setMeasurementProvider { [weak self] in
            guard let self, generation == current else { return (nil, 1) }
            return (locationService.getLatestLocationForSOS(), locationService.currentBatteryLevel)
        }
        await engine.setCallbacks(
            onDeliveryStateChanged: { [weak self] state in
                Task { @MainActor [weak self] in
                    guard let self, generation == current else { return }
                    deliveryState = state
                }
            },
            onIncomingAlertTriggered: { [weak self] alert in
                Task { @MainActor [weak self] in
                    guard let self, generation == current else { return }
                    incomingAlert = alert
                    onIncomingAlert?(alert)
                }
            }
        )
    }

    func stop() async {
        generation = UUID()
        dispatchTask?.cancel()
        dispatchTask = nil
        feedbackTask?.cancel()
        feedbackTask = nil
        inactivityGuard.isEnabled = false
        isSending = false
        incomingAlert = nil
        deliveryState = .idle
        await engine.setCallbacks()
        await engine.reset()
    }

    func triggerSOS(emergencyType: SOSType = .general) {
        guard sessionProvider() != nil, !isSending else { return }
        recordUserInteraction()
        let current = generation
        let location = locationService.getLatestLocationForSOS()
        let battery = locationService.currentBatteryLevel.asBatteryPercentage
        isSending = true
        deliveryState = .localSending
        dispatchTask = Task { [weak self] in
            guard let self else { return }
            do {
                _ = try await engine.dispatchSOS(
                    emergencyType: emergencyType,
                    location: location?.coordinate ?? CLLocationCoordinate2D(latitude: 0, longitude: 0),
                    accuracy: location?.rawAccuracyByte ?? 255,
                    timestamp: location?.timestamp ?? Date(timeIntervalSince1970: 0),
                    batteryPct: battery
                )
            } catch {
                guard generation == current, !Task.isCancelled else { return }
                deliveryState = .failed(reason: error.localizedDescription)
            }
            guard generation == current, !Task.isCancelled else { return }
            isSending = false
        }
    }

    func dismissIncomingAlert() {
        if let incomingAlert { onIncomingAlertDismissed?(incomingAlert.senderInitials) }
        incomingAlert = nil
        recordUserInteraction()
        feedbackTask?.cancel()
        feedbackTask = Task { await engine.dismissIncomingAlert() }
    }

    func retrySOS() {
        recordUserInteraction()
        feedbackTask?.cancel()
        feedbackTask = Task { await engine.triggerRetryNow() }
    }

    func dismissDeliveryStatus() {
        deliveryState = .idle
        dispatchTask?.cancel()
        dispatchTask = nil
        isSending = false
        feedbackTask?.cancel()
        feedbackTask = Task { await engine.cancelOutgoingSOS() }
    }

    func recordUserInteraction() {
        inactivityGuard.recordUserInteraction()
    }
}

#if DEBUG
extension SOSViewModel {
    static var preview: SOSViewModel {
        let viewModel = SOSViewModel(
            engine: SOSForwardingEngine(transport: PeerTransportService(), cryptoService: CryptoService()),
            locationService: LocationService(isLiveSharingEnabled: false),
            sessionProvider: { nil }
        )
        viewModel.incomingAlert = .preview
        return viewModel
    }
}
#endif
