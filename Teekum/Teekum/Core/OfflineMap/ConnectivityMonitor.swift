//
//  ConnectivityMonitor.swift
//  Teekum
//
//  Created by Adiat Rahman on 18/11/26.
//

import Foundation
import Network
import Observation

public enum MapEngineMode: Equatable, Sendable {
    case appleMapKit
    case mapboxOffline
}

public enum ConnectivityState: Equatable, Sendable {
    case unknown
    case offline
    case lieFiOffline
    case verifiedOnline
    case forcedOffline
}


@MainActor
@Observable
public final class ConnectivityMonitor {
    public typealias ProbeHandler = @Sendable () async -> Bool
    private static let forcedOfflineKey = "meepo.offlineMap.forcedOfflineMode"
    public private(set) var state: ConnectivityState
    public private(set) var isPathSatisfied: Bool = false
    
    public var isForcedOfflineMode: Bool {
        didSet {
            defaults.set(isForcedOfflineMode, forKey: Self.forcedOfflineKey)
            applyForcedOfflinePreference()
        }
    }
    
    public var isVerifiedOnline: Bool {
        state == .verifiedOnline
    }
    
    public var activeMapEngine: MapEngineMode {
        state == .verifiedOnline ? .appleMapKit : .mapboxOffline
    }
    
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let probeHandler: ProbeHandler
    @ObservationIgnored private let monitorQueue = DispatchQueue(label: "com.fantasticenam.meepo.connectivity")
    @ObservationIgnored private var pathMonitorHandle: PathMonitorHandle?
    @ObservationIgnored private var probeTask: Task<Void, Never>?
    @ObservationIgnored private var isStarted = false
    public init(
        defaults: UserDefaults = .standard,
        probeHandler: @escaping ProbeHandler = { await ConnectivityMonitor.performDefaultReachabilityProbe() }
    ) {
        self.defaults = defaults
        self.probeHandler = probeHandler
        let savedForced = defaults.bool(forKey: Self.forcedOfflineKey)
        self.isForcedOfflineMode = savedForced
        self.state = savedForced ? .forcedOffline : .unknown
    }
    public func start() {
        guard !isStarted else { return }
        isStarted = true
        let monitor = NWPathMonitor()
        // Callback NWPathMonitor jalan di background queue -> harus pindah ke @MainActor
        monitor.pathUpdateHandler = { [weak self] path in
            let satisfied = (path.status == .satisfied)
            Task { @MainActor [weak self] in
                self?.handlePathStatus(isSatisfied: satisfied)
            }
        }
        pathMonitorHandle = PathMonitorHandle(monitor: monitor)
        monitor.start(queue: monitorQueue)
    }
    public func stop() {
        probeTask?.cancel()
        probeTask = nil
        pathMonitorHandle?.cancel()
        pathMonitorHandle = nil
        isStarted = false
    }
    
    public func refreshReachability() {
        handlePathStatus(isSatisfied: isPathSatisfied)
    }
    
    public func handlePathStatus(isSatisfied: Bool) {
        isPathSatisfied = isSatisfied
        if isForcedOfflineMode {
            cancelProbe()
            state = .forcedOffline
            return
        }
        if !isSatisfied {
            cancelProbe()
            state = .offline
            return
        }
        launchReachabilityProbe()
    }
    private func applyForcedOfflinePreference() {
        handlePathStatus(isSatisfied: isPathSatisfied)
    }
    private func cancelProbe() {
        probeTask?.cancel()
        probeTask = nil
    }
    private func launchReachabilityProbe() {
        cancelProbe()
        let handler = probeHandler
        probeTask = Task { [weak self] in
            let reachable = await handler()
            // Guard penting: pastikan task tidak dibatalkan & status belum berubah selama menunggu 1.5s
            guard let self, !Task.isCancelled else { return }
            guard !self.isForcedOfflineMode else { self.state = .forcedOffline; return }
            guard self.isPathSatisfied else { self.state = .offline; return }
            self.state = reachable ? .verifiedOnline : .lieFiOffline
        }
    }
}

private final class PathMonitorHandle: @unchecked Sendable {
    private let monitor: NWPathMonitor
    init(monitor: NWPathMonitor) { self.monitor = monitor }
    func cancel() { monitor.cancel() }
    deinit { monitor.cancel() }
}
