//
//  ConnectivityMonitor+Probe.swift
//  Teekum
//
//  Created by Adiat Rahman on 19/11/26.
//

import Foundation
extension ConnectivityMonitor {
    nonisolated public static func performDefaultReachabilityProbe(
        url: URL = URL(string: "https://captive.apple.com/hotspot-detect.html")!,
        timeout: TimeInterval = 1.5
    ) async -> Bool {
        // 1. Buat URLSession sementara (ephemeral = tanpa cache/cookie ke disk)
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout
        config.waitsForConnectivity = false
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        // 2. Pasang delegate anti-redirect agar halaman login Wi-Fi tidak dianggap online
        let delegate = NoRedirectProbeDelegate()
        let session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        // 3. Kirim GET request ringan (~70 byte) dengan batas waktu 1.5 detik
        var request = URLRequest(
            url: url,
            cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
            timeoutInterval: timeout
        )
        request.httpMethod = "GET"
        // 4. Lolos hanya jika status 200 dan body mengandung kata "Success"
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return false
            }
            guard let body = String(data: data, encoding: .utf8) else {
                return false
            }
            return body.localizedCaseInsensitiveContains("Success")
        } catch {
            return false
        }
    }
}
// Menolak semua redirect HTTP (301/302) dari Wi-Fi captive portal.
private final class NoRedirectProbeDelegate: NSObject, URLSessionTaskDelegate, Sendable {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest
    ) async -> URLRequest? {
        nil
    }
}
