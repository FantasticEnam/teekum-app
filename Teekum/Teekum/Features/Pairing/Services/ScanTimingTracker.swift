//
//  ScanTimingTracker.swift
//  Teekum
//
//  Debug instrument to profile post-scan execution timing and provide breakpoint hooks.
//

import Foundation

public final class ScanTimingTracker: @unchecked Sendable {
    public static let shared = ScanTimingTracker()

    private let lock = NSLock()
    private var startTime: CFAbsoluteTime?
    private var lastTime: CFAbsoluteTime?

    private init() {}

    public static func start(codePreview: String) {
        shared.begin(codePreview: codePreview)
    }

    public static func checkpoint(_ stage: String, details: String = "") {
        shared.record(stage: stage, details: details)
    }

    /// Single point of entry for Xcode breakpoints.
    /// Place an Xcode breakpoint on the line inside this function to break on any or all scan checkpoints.
    @inline(never)
    public static func breakpointHook(stage: String, details: String) {
        // MARK: - PLACE XCODE BREAKPOINT HERE TO CATCH EVERY SCAN CHECKPOINT
        _ = (stage, details)
    }

    private func begin(codePreview: String) {
        let now = CFAbsoluteTimeGetCurrent()
        let isFirstDetection: Bool = lock.withLock {
            if startTime != nil { return false }
            startTime = now
            lastTime = now
            return true
        }
        guard isFirstDetection else { return }
        let threadDesc = Thread.isMainThread ? "MainThread" : "sessionQueue"
        let truncated = codePreview.count > 50 ? "\(codePreview.prefix(47))..." : codePreview
        print("[⏱️ ScanDebug +0.0ms] [\(threadDesc)] 🚀 START: Code detected: \"\(truncated)\"")
        Self.breakpointHook(stage: "START", details: truncated)
    }

    private func record(stage: String, details: String) {
        let now = CFAbsoluteTimeGetCurrent()
        let (totalMs, stepMs): (Double, Double) = lock.withLock {
            guard let start = startTime, let last = lastTime else {
                startTime = now
                lastTime = now
                return (0.0, 0.0)
            }
            let total = (now - start) * 1000.0
            let step = (now - last) * 1000.0
            lastTime = now
            return (total, step)
        }

        let threadDesc = Thread.isMainThread ? "MainThread" : "sessionQueue"
        let detailsString = details.isEmpty ? "" : " - \(details)"
        print(String(format: "[⏱️ ScanDebug +%.1fms (+%.1fms)] [%@] 📍 %@%@", totalMs, stepMs, threadDesc, stage, detailsString))
        Self.breakpointHook(stage: stage, details: details)
    }

    public static func reset() {
        shared.lock.withLock {
            shared.startTime = nil
            shared.lastTime = nil
        }
    }
}
