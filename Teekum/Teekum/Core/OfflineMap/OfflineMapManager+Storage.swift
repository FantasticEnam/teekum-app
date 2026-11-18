//
//  OfflineMapManager+Storage.swift
//  Teekum
//
//  Created by Adiat Rahman on 19/11/26.
//

import CoreLocation
import Foundation
import MapboxMaps
// Kontrak tipis agar `OfflineMapManager` bisa dites di XCTest tanpa memanggil server Mapbox asli.
public protocol OfflineTileStoreClient: Sendable {
    func downloadRegion(
        regionId: String,
        styleURIString: String,
        box: OfflineMapBounds.CoordinateBox,
        zoomRange: ClosedRange<UInt8>,
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws -> UInt64
    func removeRegion(regionId: String) async
    func cancelActiveDownload()
}
// Kotak aman lintas-thread (Swift 6) untuk menyimpan handle `Cancelable` milik Mapbox.
private final class CancelableBox: @unchecked Sendable {
    private let lock = NSLock()
    private var stylePack: Cancelable?
    private var tileRegion: Cancelable?
    func setStylePack(_ cancelable: Cancelable?) {
        lock.lock()
        stylePack = cancelable
        lock.unlock()
    }
    func setTileRegion(_ cancelable: Cancelable?) {
        lock.lock()
        tileRegion = cancelable
        lock.unlock()
    }
    func cancelAll() {
        lock.lock()
        let sp = stylePack
        let tr = tileRegion
        stylePack = nil
        tileRegion = nil
        lock.unlock()
        sp?.cancel()
        tr?.cancel()
    }
}
// Implementasi asli Mapbox v11 menggunakan `OfflineManager` + `TileStore.default`.
public final class MapboxOfflineTileStoreClient: OfflineTileStoreClient, @unchecked Sendable {
    private let cancelables = CancelableBox()
    public init() {}
    public func downloadRegion(
        regionId: String,
        styleURIString: String,
        box: OfflineMapBounds.CoordinateBox,
        zoomRange: ClosedRange<UInt8>,
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws -> UInt64 {
        let styleURI = StyleURI(rawValue: styleURIString) ?? .dark
        let offlineManager = OfflineManager()
        let tileStore = TileStore.default
        try Task.checkCancellation()
        // Tahap 1 (0% -> 15%): Download style JSON, sprites, & font glyphs
        let styleSize = try await downloadStylePack(
            offlineManager: offlineManager,
            styleURI: styleURI,
            regionId: regionId,
            onProgress: { fraction in
                onProgress(min(0.15, fraction * 0.15))
            }
        )
        try Task.checkCancellation()
        // Tahap 2 (15% -> 100%): Download vector tiles untuk kotak 40x40 km (z0-z14)
        let tileSize = try await downloadTileRegion(
            offlineManager: offlineManager,
            tileStore: tileStore,
            styleURI: styleURI,
            regionId: regionId,
            box: box,
            zoomRange: zoomRange,
            onProgress: { fraction in
                onProgress(0.15 + min(0.85, fraction * 0.85))
            }
        )
        onProgress(1.0)
        return styleSize + tileSize
    }
    public func removeRegion(regionId: String) async {
        TileStore.default.removeTileRegion(forId: regionId)
    }
    public func cancelActiveDownload() {
        cancelables.cancelAll()
    }
    private func downloadStylePack(
        offlineManager: OfflineManager,
        styleURI: StyleURI,
        regionId: String,
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws -> UInt64 {
        guard let options = StylePackLoadOptions(
            glyphsRasterizationMode: .ideographsRasterizedLocally, // Hemat ukuran font CJK/Unicode
            metadata: ["regionId": regionId],
            acceptExpired: false
        ) else {
            throw OfflineMapError.downloadFailed("Invalid style pack load options.")
        }
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let cancelable = offlineManager.loadStylePack(
                    for: styleURI,
                    loadOptions: options,
                    progress: { progress in
                        guard progress.requiredResourceCount > 0 else { return }
                        let fraction = Double(progress.completedResourceCount) / Double(progress.requiredResourceCount)
                        onProgress(fraction)
                    },
                    completion: { [cancelables] result in
                        cancelables.setStylePack(nil)
                        switch result {
                        case .success(let pack):
                            continuation.resume(returning: pack.completedResourceSize)
                        case .failure(let error):
                            if case StylePackError.canceled = error {
                                continuation.resume(throwing: OfflineMapError.cancelled)
                            } else {
                                continuation.resume(throwing: OfflineMapError.downloadFailed(error.localizedDescription))
                            }
                        }
                    }
                )
                cancelables.setStylePack(cancelable)
            }
        } onCancel: { [cancelables] in
            cancelables.cancelAll()
        }
    }
    private func downloadTileRegion(
        offlineManager: OfflineManager,
        tileStore: TileStore,
        styleURI: StyleURI,
        regionId: String,
        box: OfflineMapBounds.CoordinateBox,
        zoomRange: ClosedRange<UInt8>,
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws -> UInt64 {
        let descriptorOptions = TilesetDescriptorOptions(styleURI: styleURI, zoomRange: zoomRange, tilesets: nil)
        let descriptor = offlineManager.createTilesetDescriptor(for: descriptorOptions)
        let polygon = Polygon([box.polygonRing])
        guard let loadOptions = TileRegionLoadOptions(
            geometry: .polygon(polygon),
            descriptors: [descriptor],
            metadata: ["regionId": regionId],
            acceptExpired: false,
            networkRestriction: .none // Izinkan download lewat Wi-Fi maupun Cellular
        ) else {
            throw OfflineMapError.downloadFailed("Invalid tile region load options.")
        }
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let cancelable = tileStore.loadTileRegion(
                    forId: regionId,
                    loadOptions: loadOptions,
                    progress: { progress in
                        guard progress.requiredResourceCount > 0 else { return }
                        let fraction = Double(progress.completedResourceCount) / Double(progress.requiredResourceCount)
                        onProgress(fraction)
                    },
                    completion: { [cancelables] result in
                        cancelables.setTileRegion(nil)
                        switch result {
                        case .success(let region):
                            continuation.resume(returning: region.completedResourceSize)
                        case .failure(let error):
                            if case TileRegionError.canceled = error {
                                continuation.resume(throwing: OfflineMapError.cancelled)
                            } else {
                                continuation.resume(throwing: OfflineMapError.downloadFailed(error.localizedDescription))
                            }
                        }
                    }
                )
                cancelables.setTileRegion(cancelable)
            }
        } onCancel: { [cancelables] in
            cancelables.cancelAll()
        }
    }
}
