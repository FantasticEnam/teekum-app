//
//  OfflineMapManager.swift
//  Teekum
//
//  Created by Adiat Rahman on 19/11/26.
//

import CoreLocation
import Foundation
import Observation

@MainActor
@Observable
public final class OfflineMapManager {
    public typealias CityGeocoder = @Sendable (CLLocationCoordinate2D) async throws -> String
    public typealias AvailableBytesProvider = @Sendable () -> Int64?
    private static let cachedCityKey = "meepo.offlineMap.cachedCity"
    private static let preparednessKey = "meepo.offlineMap.completedPreparedness"
    public static let fallbackDarkStyleURI = "mapbox://styles/mapbox/dark-v11"
    public private(set) var cachedCity: CachedCityMetadata?
    public private(set) var detectedCity: DetectedCity?
    public private(set) var downloadState: OfflineMapDownloadState = .idle
    // Penanda apakah user sudah melewati layar Preparedness Setup (selesai download atau Skip).
    public var hasCompletedPreparednessSetup: Bool {
        didSet {
            defaults.set(hasCompletedPreparednessSetup, forKey: Self.preparednessKey)
        }
    }
    public var isNudgeDismissedThisLaunch: Bool = false
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let client: any OfflineTileStoreClient
    @ObservationIgnored private let geocoder: CityGeocoder
    @ObservationIgnored private let availableBytesProvider: AvailableBytesProvider
    @ObservationIgnored private let accessTokenProvider: () -> String
    @ObservationIgnored private let styleURIProvider: () -> String
    @ObservationIgnored private let dateProvider: () -> Date
    public init(
        defaults: UserDefaults = .standard,
        client: any OfflineTileStoreClient = MapboxOfflineTileStoreClient(),
        geocoder: @escaping CityGeocoder = OfflineMapManager.defaultReverseGeocodeCity,
        availableBytesProvider: @escaping AvailableBytesProvider = OfflineMapManager.defaultAvailableBytes,
        accessTokenProvider: @escaping () -> String = OfflineMapManager.bundleAccessToken,
        styleURIProvider: @escaping () -> String = OfflineMapManager.bundleStyleURI,
        dateProvider: @escaping () -> Date = { .now }
    ) {
        self.defaults = defaults
        self.client = client
        self.geocoder = geocoder
        self.availableBytesProvider = availableBytesProvider
        self.accessTokenProvider = accessTokenProvider
        self.styleURIProvider = styleURIProvider
        self.dateProvider = dateProvider
        self.hasCompletedPreparednessSetup = defaults.bool(forKey: Self.preparednessKey)
        self.cachedCity = Self.loadCachedCity(from: defaults)
    }
    public var isConfigured: Bool {
        let token = accessTokenProvider().trimmingCharacters(in: .whitespacesAndNewlines)
        return !token.isEmpty && !token.contains("YOUR_PUBLIC_MAPBOX")
    }
    public var activeStyleURIString: String {
        let configured = styleURIProvider().trimmingCharacters(in: .whitespacesAndNewlines)
        return configured.hasPrefix("mapbox://") ? configured : Self.fallbackDarkStyleURI
    }
    public var formattedCachedSize: String {
        guard let bytes = cachedCity?.sizeBytes else { return "0 MB" }
        return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }
    // True jika sedang verified online dan (belum ada peta kota ATAU pindah > 25 km dari kota tersimpan).
    public func shouldSuggestCityDownload(
        currentCoordinate: CLLocationCoordinate2D?,
        isVerifiedOnline: Bool
    ) -> Bool {
        guard isVerifiedOnline, !downloadState.isBusy, !isNudgeDismissedThisLaunch else { return false }
        guard let cached = cachedCity else { return true }
        guard let currentCoordinate else { return false }
        return OfflineMapBounds.isOutsideRelocationThreshold(
            current: currentCoordinate,
            cachedCenter: cached.centerCoordinate
        )
    }
    public func isRelocatedFarFromCache(currentCoordinate: CLLocationCoordinate2D?) -> Bool {
        guard let cached = cachedCity, let currentCoordinate else { return false }
        return OfflineMapBounds.isOutsideRelocationThreshold(
            current: currentCoordinate,
            cachedCenter: cached.centerCoordinate
        )
    }
    @discardableResult
    public func detectCity(at coordinate: CLLocationCoordinate2D) async throws -> DetectedCity {
        guard CLLocationCoordinate2DIsValid(coordinate) else {
            throw OfflineMapError.locationUnavailable
        }
        let name = try await geocoder(coordinate)
        let resolved = DetectedCity(name: name, coordinate: coordinate)
        detectedCity = resolved
        return resolved
    }
    // Meminta 1 titik GPS (tanpa menyalakan mesh) lalu mengubahnya menjadi nama kota.
    @discardableResult
    public func locateAndDetectCity(using locationService: LocationService) async throws -> DetectedCity {
        downloadState = .locating
        guard let pin = await locationService.requestSingleLocationFix() else {
            downloadState = .failed(OfflineMapError.locationUnavailable.localizedDescription)
            throw OfflineMapError.locationUnavailable
        }
        do {
            let city = try await detectCity(at: pin.coordinate)
            downloadState = .idle
            return city
        } catch {
            downloadState = .failed(OfflineMapError.cityResolutionFailed.localizedDescription)
            throw OfflineMapError.cityResolutionFailed
        }
    }
    // Unduh kotak 20 km (z0-z14) untuk `city`. Kota lama baru dihapus SETELAH kota baru sukses.
    public func downloadCity(
        _ city: DetectedCity,
        isOnline: Bool,
        zoomRange: ClosedRange<UInt8> = OfflineMapBounds.defaultMinZoom...OfflineMapBounds.defaultMaxZoom
    ) async throws {
        guard isOnline else {
            downloadState = .failed(OfflineMapError.offline.localizedDescription)
            throw OfflineMapError.offline
        }
        guard isConfigured else {
            downloadState = .failed(OfflineMapError.missingAccessToken.localizedDescription)
            throw OfflineMapError.missingAccessToken
        }
        if let freeBytes = availableBytesProvider(), freeBytes < OfflineMapBounds.minimumRequiredFreeBytes {
            let err = OfflineMapError.insufficientStorage(
                requiredMB: Int(OfflineMapBounds.minimumRequiredFreeBytes / (1_024 * 1_024)),
                availableMB: max(0, Int(freeBytes / (1_024 * 1_024)))
            )
            downloadState = .failed(err.localizedDescription)
            throw err
        }
        let safe = OfflineMapBounds.safeRegionBox(
            center: city.coordinate,
            targetRadiusMeters: OfflineMapBounds.defaultRadiusMeters,
            zoomRange: zoomRange
        )
        guard safe.estimatedTiles <= OfflineMapBounds.mapboxHardTileCap else {
            let err = OfflineMapError.tileCapExceeded(
                estimated: safe.estimatedTiles,
                limit: OfflineMapBounds.mapboxHardTileCap
            )
            downloadState = .failed(err.localizedDescription)
            throw err
        }
        cancelDownload()
        let previousRegionId = cachedCity?.regionId
        let slug = Self.slugify(city.name)
        let newRegionId = "city-\(slug)-\(UUID().uuidString.prefix(8).lowercased())"
        let styleURI = activeStyleURIString
        downloadState = .downloading(cityName: city.name, progress: 0)
        do {
            let totalBytes = try await client.downloadRegion(
                regionId: newRegionId,
                styleURIString: styleURI,
                box: safe.box,
                zoomRange: zoomRange,
                onProgress: { [weak self] progress in
                    Task { @MainActor [weak self] in
                        guard let self, case .downloading(let name, _) = self.downloadState else { return }
                        self.downloadState = .downloading(cityName: name, progress: min(max(progress, 0), 1))
                    }
                }
            )
            let metadata = CachedCityMetadata(
                regionId: newRegionId,
                cityName: city.name,
                centerCoordinate: city.coordinate,
                radiusMeters: safe.radiusMeters,
                sizeBytes: totalBytes,
                downloadedAt: dateProvider(),
                styleURI: styleURI
            )
            // Eviksi kota lama hanya setelah kota baru 100% tersimpan aman di disk.
            if let previousRegionId, previousRegionId != newRegionId {
                await client.removeRegion(regionId: previousRegionId)
            }
            cachedCity = metadata
            saveCachedCity(metadata)
            hasCompletedPreparednessSetup = true
            isNudgeDismissedThisLaunch = false
            downloadState = .idle
        } catch {
            // Bersihkan sisa download baru yang gagal, biarkan `cachedCity` lama tetap utuh.
            await client.removeRegion(regionId: newRegionId)
            if let offlineError = error as? OfflineMapError, offlineError == .cancelled {
                downloadState = .idle
                throw offlineError
            }
            if error is CancellationError {
                downloadState = .idle
                throw OfflineMapError.cancelled
            }
            downloadState = .failed(error.localizedDescription)
            throw error
        }
    }
    public func cancelDownload() {
        client.cancelActiveDownload()
        if case .downloading = downloadState {
            downloadState = .idle
        }
    }
    public func deleteCachedCity() async {
        cancelDownload()
        if let regionId = cachedCity?.regionId {
            await client.removeRegion(regionId: regionId)
        }
        cachedCity = nil
        defaults.removeObject(forKey: Self.cachedCityKey)
        downloadState = .idle
    }
    public func dismissNudgeForThisLaunch() {
        isNudgeDismissedThisLaunch = true
    }
    public func markPreparednessCompleted() {
        hasCompletedPreparednessSetup = true
    }
    
    // MARK: - Persistence & Helpers
    private func saveCachedCity(_ metadata: CachedCityMetadata) {
        guard let data = try? JSONEncoder().encode(metadata) else { return }
        defaults.set(data, forKey: Self.cachedCityKey)
    }
    private static func loadCachedCity(from defaults: UserDefaults) -> CachedCityMetadata? {
        guard let data = defaults.data(forKey: cachedCityKey) else { return nil }
        return try? JSONDecoder().decode(CachedCityMetadata.self, from: data)
    }
    private static func slugify(_ raw: String) -> String {
        let filtered = raw.lowercased().map { $0.isLetter || $0.isNumber ? $0 : "-" }
        let collapsed = String(filtered).trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return collapsed.isEmpty ? "region" : String(collapsed.prefix(24))
    }
    nonisolated public static func bundleAccessToken() -> String {
        (Bundle.main.object(forInfoDictionaryKey: "MBXAccessToken") as? String) ?? ""
    }
    nonisolated public static func bundleStyleURI() -> String {
        (Bundle.main.object(forInfoDictionaryKey: "MeepoMapboxStyleURI") as? String) ?? ""
    }
    nonisolated public static func defaultAvailableBytes() -> Int64? {
        let home = URL(fileURLWithPath: NSHomeDirectory())
        let values = try? home.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        return values?.volumeAvailableCapacityForImportantUsage
    }
    nonisolated public static func defaultReverseGeocodeCity(for coordinate: CLLocationCoordinate2D) async throws -> String {
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let placemarks = try await geocoder.reverseGeocodeLocation(location)
        guard let placemark = placemarks.first else {
            throw OfflineMapError.cityResolutionFailed
        }
        // Urutan fallback Indonesia: Kota/Kecamatan (locality) -> Kabupaten (subAdministrativeArea) -> Provinsi
        let candidates = [placemark.locality, placemark.subAdministrativeArea, placemark.administrativeArea]
        if let name = candidates.compactMap({ $0?.trimmingCharacters(in: .whitespacesAndNewlines) }).first(where: { !$0.isEmpty }) {
            return name
        }
        throw OfflineMapError.cityResolutionFailed
    }
}
