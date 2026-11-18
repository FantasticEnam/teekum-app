//
//  OfflineMapTests.swift
//  TeekumTests
//
//  Created by Adiat Rahman on 19/11/26.
//

import XCTest
import CoreLocation
@testable import Teekum

// MARK: - Mock Tile Store Actor untuk Menghindari Network Nyata (Swift 6 Safe)
private actor MockTileStoreClient: OfflineTileStoreClient {
    var downloadedRegions: [String] = []
    var removedRegions: [String] = []
    var shouldFailDownload = false
    var simulatedBytes: UInt64 = 15_500_000 // ~15.5 MB
    
    func downloadRegion(
        regionId: String,
        styleURIString: String,
        box: OfflineMapBounds.CoordinateBox,
        zoomRange: ClosedRange<UInt8>,
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws -> UInt64 {
        if shouldFailDownload {
            throw OfflineMapError.downloadFailed("Simulated network drop")
        }
        onProgress(0.5)
        onProgress(1.0)
        downloadedRegions.append(regionId)
        return simulatedBytes
    }
    
    func removeRegion(regionId: String) async {
        removedRegions.append(regionId)
    }
    
    nonisolated func cancelActiveDownload() {}
    
    func setShouldFailDownload(_ shouldFail: Bool) {
        self.shouldFailDownload = shouldFail
    }
}

// Box bantuan Sendable untuk probe test
private final class ProbeBox: @unchecked Sendable {
    var result: Bool = true
}

// MARK: - Test Suite
final class OfflineMapTests: XCTestCase {
    
    private var testDefaults: UserDefaults!
    
    override func setUp() {
        super.setUp()
        testDefaults = UserDefaults(suiteName: "TeekumOfflineMapTests")!
        testDefaults.removePersistentDomain(forName: "TeekumOfflineMapTests")
    }
    
    override func tearDown() {
        testDefaults.removePersistentDomain(forName: "TeekumOfflineMapTests")
        testDefaults = nil
        super.tearDown()
    }
    
    // MARK: - 1. Bounds Math & Tile-Cap Safety
    func testSafeRegionBoxEstimatedTilesWithinHardCap() {
        let bandung = CLLocationCoordinate2D(latitude: -6.9175, longitude: 107.6191)
        let safe = OfflineMapBounds.safeRegionBox(
            center: bandung,
            targetRadiusMeters: OfflineMapBounds.defaultRadiusMeters,
            zoomRange: OfflineMapBounds.defaultMinZoom...OfflineMapBounds.defaultMaxZoom
        )
        
        // Kotak 20 km (z0-z14) harus berada di bawah batas keras 750 tiles
        XCTAssertLessThanOrEqual(safe.estimatedTiles, OfflineMapBounds.mapboxHardTileCap)
        XCTAssertGreaterThan(safe.estimatedTiles, 0)
        XCTAssertEqual(safe.radiusMeters, 20_000)
    }
    
    func testRelocationThresholdDistance() {
        let bandung = CLLocationCoordinate2D(latitude: -6.9175, longitude: 107.6191)
        // Lokasi dekat: 5 km dari pusat kota Bandung
        let cimahi = CLLocationCoordinate2D(latitude: -6.8722, longitude: 107.5420)
        XCTAssertFalse(
            OfflineMapBounds.isOutsideRelocationThreshold(current: cimahi, cachedCenter: bandung),
            "Jarak dekat tidak boleh memicu notifikasi pindah kota"
        )
        
        // Lokasi jauh: Jakarta (~120 km dari Bandung)
        let jakarta = CLLocationCoordinate2D(latitude: -6.2088, longitude: 106.8456)
        XCTAssertTrue(
            OfflineMapBounds.isOutsideRelocationThreshold(current: jakarta, cachedCenter: bandung),
            "Jarak >25 km harus memicu notifikasi download kota baru"
        )
    }
    
    // MARK: - 2. Anti-Lie-Fi & Connectivity State Transitions
    @MainActor
    func testConnectivityMonitorTransitions() async {
        let probeBox = ProbeBox()
        probeBox.result = true
        let monitor = ConnectivityMonitor(
            defaults: testDefaults,
            probeHandler: { probeBox.result }
        )
        
        // Saat offline kabel/seluler mati
        monitor.handlePathStatus(isSatisfied: false)
        XCTAssertEqual(monitor.state, .offline)
        XCTAssertEqual(monitor.activeMapEngine, .mapboxOffline)
        
        // Saat Wi-Fi nyambung dan internet tembus (Verified Online)
        probeBox.result = true
        monitor.handlePathStatus(isSatisfied: true)
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(monitor.state, .verifiedOnline)
        XCTAssertEqual(monitor.activeMapEngine, .appleMapKit)
        
        // Saat Wi-Fi nyambung tapi internet jebakan / captive portal (Lie-Fi)
        probeBox.result = false
        monitor.handlePathStatus(isSatisfied: true)
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(monitor.state, .lieFiOffline)
        XCTAssertEqual(monitor.activeMapEngine, .mapboxOffline)
        
        // Saat mode forced offline diaktifkan
        monitor.isForcedOfflineMode = true
        XCTAssertEqual(monitor.state, .forcedOffline)
        XCTAssertEqual(monitor.activeMapEngine, .mapboxOffline)
    }
    
    // MARK: - 3. Single-City Disk Lock & Safe Eviction
    @MainActor
    func testSingleCityEvictionOnlyAfterNewCitySucceeds() async throws {
        let mock = MockTileStoreClient()
        let manager = OfflineMapManager(
            defaults: testDefaults,
            client: mock,
            availableBytesProvider: { 500_000_000 }, // 500 MB cukup
            accessTokenProvider: { "pk.dummy-token" },
            styleURIProvider: { "mapbox://styles/dummy" }
        )
        
        let bandung = DetectedCity(name: "Bandung", coordinate: CLLocationCoordinate2D(latitude: -6.9175, longitude: 107.6191))
        let jakarta = DetectedCity(name: "Jakarta", coordinate: CLLocationCoordinate2D(latitude: -6.2088, longitude: 106.8456))
        
        // 1. Download kota pertama (Bandung)
        try await manager.downloadCity(bandung, isOnline: true)
        XCTAssertEqual(manager.cachedCity?.cityName, "Bandung")
        let downloadedCount = await mock.downloadedRegions.count
        let removedCount = await mock.removedRegions.count
        XCTAssertEqual(downloadedCount, 1)
        XCTAssertEqual(removedCount, 0)
        let bandungRegionId = manager.cachedCity?.regionId
        
        // 2. Download kota kedua (Jakarta) tapi GAGAL di tengah jalan
        await mock.setShouldFailDownload(true)
        do {
            try await manager.downloadCity(jakarta, isOnline: true)
            XCTFail("Harusnya melempar error download")
        } catch {
            // Bandung HARUS tetap utuh sebagai cachedCity
            XCTAssertEqual(manager.cachedCity?.cityName, "Bandung")
            let removed = await mock.removedRegions
            XCTAssertFalse(removed.contains(bandungRegionId ?? ""))
        }
        
        // 3. Download kota kedua (Jakarta) kali ini SUKSES
        await mock.setShouldFailDownload(false)
        try await manager.downloadCity(jakarta, isOnline: true)
        XCTAssertEqual(manager.cachedCity?.cityName, "Jakarta")
        // Bandung sekarang harus sudah dieviksi (dihapus)
        let finalRemoved = await mock.removedRegions
        XCTAssertTrue(finalRemoved.contains(bandungRegionId ?? ""))
    }
    
    // MARK: - 4. Insufficient Storage Guard
    @MainActor
    func testInsufficientStorageRejectsDownload() async {
        let mock = MockTileStoreClient()
        let manager = OfflineMapManager(
            defaults: testDefaults,
            client: mock,
            availableBytesProvider: { 50_000_000 }, // Hanya ada 50 MB (< 200 MB)
            accessTokenProvider: { "pk.dummy-token" },
            styleURIProvider: { "mapbox://styles/dummy" }
        )
        let city = DetectedCity(name: "Bandung", coordinate: CLLocationCoordinate2D(latitude: -6.9175, longitude: 107.6191))
        
        do {
            try await manager.downloadCity(city, isOnline: true)
            XCTFail("Harusnya menolak download jika storage kurang")
        } catch let OfflineMapError.insufficientStorage(requiredMB, availableMB) {
            XCTAssertEqual(requiredMB, 60)
            XCTAssertEqual(availableMB, 47) // 50_000_000 / 1024 / 1024 ≈ 47
        } catch {
            XCTFail("Error yang dilempar bukan insufficientStorage: \(error)")
        }
    }
}
