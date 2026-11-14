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
    private var showsDeliveryDetails = true
    private var lastEmergencyType: SOSType = .general
    private var incomingEvents: Set<SOSResolvedPayload> = []

    let inactivityGuard: InactivityGuardService
    private(set) var deliveryState: SOSDeliveryState = .idle
    private(set) var incomingAlert: IncomingSOSAlert?
    private(set) var isSending = false
    private(set) var outgoingEventId: UInt32?
    private(set) var isResolving = false
    private(set) var resolutionError: String?
    var onIncomingAlert: (@MainActor (IncomingSOSAlert) -> Void)?
    var onIncomingSOSResolved: (@MainActor (String) -> Void)?

    var showsEdgeGlow: Bool {
        incomingAlert != nil || !incomingEvents.isEmpty || isSending || outgoingEventId != nil || deliveryState.stage != .idle
    }

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
                    guard let self, generation == current, showsDeliveryDetails,
                          isSending || outgoingEventId != nil else { return }
                    deliveryState = state
                }
            },
            onIncomingAlertTriggered: { [weak self] alert in
                guard let self, generation == current else { return }
                incomingEvents.insert(SOSResolvedPayload(senderInitials: alert.senderInitials, eventId: alert.id))
                incomingAlert = alert
                onIncomingAlert?(alert)
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
        incomingEvents.removeAll()
        outgoingEventId = nil
        isResolving = false
        resolutionError = nil
        deliveryState = .idle
        await engine.setCallbacks()
        await engine.reset()
    }

    func triggerSOS(emergencyType: SOSType = .general) {
        guard sessionProvider() != nil, !isSending, outgoingEventId == nil else { return }
        recordUserInteraction()
        let current = generation
        let location = locationService.getLatestLocationForSOS()
        let battery = locationService.currentBatteryLevel.asBatteryPercentage
        isSending = true
        lastEmergencyType = emergencyType
        showsDeliveryDetails = true
        deliveryState = .localSending
        dispatchTask = Task { [weak self] in
            guard let self, generation == current, !Task.isCancelled else { return }
            do {
                let eventId = try await engine.dispatchSOS(
                    emergencyType: emergencyType,
                    location: location?.coordinate ?? CLLocationCoordinate2D(latitude: 0, longitude: 0),
                    accuracy: location?.rawAccuracyByte ?? 255,
                    timestamp: location?.timestamp ?? Date(timeIntervalSince1970: 0),
                    batteryPct: battery
                )
                guard generation == current, !Task.isCancelled else { return }
                outgoingEventId = eventId
            } catch {
                guard generation == current, !Task.isCancelled else { return }
                deliveryState = .failed(reason: error.localizedDescription)
            }
            guard generation == current, !Task.isCancelled else { return }
            isSending = false
        }
    }

    func acknowledgeIncomingAlert() async {
        guard let incomingAlert else { return }
        let event = SOSResolvedPayload(senderInitials: incomingAlert.senderInitials, eventId: incomingAlert.id)
        self.incomingAlert = nil
        recordUserInteraction()
        await engine.acknowledgeIncomingAlert(matching: event)
    }

    func acceptResolution(_ event: SOSResolvedPayload) async {
        let current = generation
        await engine.acceptResolution(event)
        guard generation == current, incomingEvents.remove(event) != nil else { return }
        if incomingAlert?.id == event.eventId, incomingAlert?.senderInitials == event.senderInitials {
            incomingAlert = nil
        }
        if !incomingEvents.contains(where: { $0.senderInitials == event.senderInitials }) {
            onIncomingSOSResolved?(event.senderInitials)
        }
    }

    func endSOS() {
        guard let eventId = outgoingEventId, !isResolving else { return }
        recordUserInteraction()
        isResolving = true
        resolutionError = nil
        let current = generation
        dispatchTask = Task { [weak self] in
            guard let self, generation == current, !Task.isCancelled else { return }
            do {
                try await engine.resolveOutgoingSOS(eventId: eventId)
                guard generation == current, !Task.isCancelled else { return }
                outgoingEventId = nil
                deliveryState = .idle
            } catch {
                guard generation == current, !Task.isCancelled else { return }
                resolutionError = "Couldn’t queue the SOS update. Try again."
            }
            isResolving = false
        }
    }

    func retrySOS() {
        guard !isSending, !isResolving else { return }
        guard outgoingEventId != nil else {
            triggerSOS(emergencyType: lastEmergencyType)
            return
        }
        showsDeliveryDetails = true
        recordUserInteraction()
        feedbackTask?.cancel()
        feedbackTask = Task { await engine.triggerRetryNow() }
    }

    func dismissDeliveryStatus() {
        showsDeliveryDetails = false
        deliveryState = .idle
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
