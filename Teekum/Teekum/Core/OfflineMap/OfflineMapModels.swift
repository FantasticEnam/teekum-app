//
//  OfflineMapModels.swift
//  Teekum
//
//  Created by Adiat Rahman on 19/11/26.
//

import CoreLocation
import Foundation
// Identitas 1 kota yang sedang tersimpan di disk (disimpan sebagai JSON di UserDefaults).
public struct CachedCityMetadata: Codable, Equatable, Sendable {
    public let regionId: String
    public let cityName: String
    public let centerLatitude: Double
    public let centerLongitude: Double
    public let radiusMeters: Double
    public let sizeBytes: UInt64
    public let downloadedAt: Date
    public let styleURI: String
    public var centerCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: centerLatitude, longitude: centerLongitude)
    }
    public init(
        regionId: String,
        cityName: String,
        centerCoordinate: CLLocationCoordinate2D,
        radiusMeters: Double,
        sizeBytes: UInt64,
        downloadedAt: Date = .now,
        styleURI: String
    ) {
        self.regionId = regionId
        self.cityName = cityName
        self.centerLatitude = centerCoordinate.latitude
        self.centerLongitude = centerCoordinate.longitude
        self.radiusMeters = radiusMeters
        self.sizeBytes = sizeBytes
        self.downloadedAt = downloadedAt
        self.styleURI = styleURI
    }
}
// Hasil sementara deteksi GPS + geocoding sebelum user menekan tombol Download.
public struct DetectedCity: Equatable, Sendable {
    public let name: String
    public let coordinate: CLLocationCoordinate2D
    public init(name: String, coordinate: CLLocationCoordinate2D) {
        self.name = name
        self.coordinate = coordinate
    }
    public static func == (lhs: DetectedCity, rhs: DetectedCity) -> Bool {
        lhs.name == rhs.name &&
        lhs.coordinate.latitude == rhs.coordinate.latitude &&
        lhs.coordinate.longitude == rhs.coordinate.longitude
    }
}
// Status UI untuk proses deteksi & unduh peta offline.
public enum OfflineMapDownloadState: Equatable, Sendable {
    case idle
    case locating
    case downloading(cityName: String, progress: Double)
    case failed(String)
    public var isBusy: Bool {
        switch self {
        case .locating, .downloading: true
        case .idle, .failed: false
        }
    }
}
public enum OfflineMapError: Error, LocalizedError, Equatable, Sendable {
    case missingAccessToken
    case offline
    case insufficientStorage(requiredMB: Int, availableMB: Int)
    case tileCapExceeded(estimated: Int, limit: Int)
    case locationUnavailable
    case cityResolutionFailed
    case cancelled
    case downloadFailed(String)
    public var errorDescription: String? {
        switch self {
        case .missingAccessToken:
            "Offline map token is not configured for this build."
        case .offline:
            "Connect to Wi-Fi or cellular data to download an offline city map."
        case .insufficientStorage(let requiredMB, let availableMB):
            "Not enough free storage (\(availableMB) MB available, need at least \(requiredMB) MB)."
        case .tileCapExceeded(let estimated, let limit):
            "Requested area (\(estimated) tiles) exceeds Mapbox's \(limit)-tile offline cap."
        case .locationUnavailable:
            "Unable to determine your current location. Check Location permissions and try again."
        case .cityResolutionFailed:
            "Unable to identify your current city. Check your connection and try again."
        case .cancelled:
            "Offline map download was cancelled."
        case .downloadFailed(let message):
            "Offline map download failed: \(message)"
        }
    }
}
// Matematika murni untuk kotak 20 km, pengaman batas 750 tile Mapbox, dan cek pindah >25 km.
public enum OfflineMapBounds {
    public static let defaultRadiusMeters: Double = 20_000
    public static let relocationThresholdMeters: Double = 25_000
    public static let defaultMinZoom: UInt8 = 0
    public static let defaultMaxZoom: UInt8 = 14
    public static let mapboxHardTileCap: Int = 750
    public static let safeTileCap: Int = 700
    public static let minimumRequiredFreeBytes: Int64 = 60 * 1_024 * 1_024
    public static let estimatedDownloadLabel: String = "~15–25 MB"
    private static let earthRadiusMeters: Double = 6_371_000
    private static let metersPerDegreeLatitude: Double = 111_320
    private static let maxMercatorLatitude: Double = 85.0511
    public struct CoordinateBox: Equatable, Sendable {
        public let minLatitude: Double
        public let maxLatitude: Double
        public let minLongitude: Double
        public let maxLongitude: Double
        public init(minLatitude: Double, maxLatitude: Double, minLongitude: Double, maxLongitude: Double) {
            self.minLatitude = minLatitude
            self.maxLatitude = maxLatitude
            self.minLongitude = minLongitude
            self.maxLongitude = maxLongitude
        }
        // 5 titik berurutan membentuk kotak tertutup (SW -> NW -> NE -> SE -> SW) untuk GeoJSON Polygon Mapbox.
        public var polygonRing: [CLLocationCoordinate2D] {
            let sw = CLLocationCoordinate2D(latitude: minLatitude, longitude: minLongitude)
            let nw = CLLocationCoordinate2D(latitude: maxLatitude, longitude: minLongitude)
            let ne = CLLocationCoordinate2D(latitude: maxLatitude, longitude: maxLongitude)
            let se = CLLocationCoordinate2D(latitude: minLatitude, longitude: maxLongitude)
            return [sw, nw, ne, se, sw]
        }
        public func contains(_ coordinate: CLLocationCoordinate2D) -> Bool {
            coordinate.latitude >= minLatitude &&
            coordinate.latitude <= maxLatitude &&
            coordinate.longitude >= minLongitude &&
            coordinate.longitude <= maxLongitude
        }
    }
    // Membuat kotak persegi dengan jarak `radiusMeters` ke segala arah dari `center`.
    public static func boundingBox(
        center: CLLocationCoordinate2D,
        radiusMeters: Double = defaultRadiusMeters
    ) -> CoordinateBox {
        let clampedRadius = max(1_000, radiusMeters)
        // 1 derajat lintang ≈ 111.320 meter
        let latDelta = clampedRadius / metersPerDegreeLatitude
        let clampedCenterLat = min(max(center.latitude, -maxMercatorLatitude), maxMercatorLatitude)
        // 1 derajat bujur menyempit mengikuti cos(latitude) saat menjauhi khatulistiwa
        let cosLat = max(0.05, cos(clampedCenterLat * .pi / 180.0))
        let lonDelta = clampedRadius / (metersPerDegreeLatitude * cosLat)
        return CoordinateBox(
            minLatitude: max(-maxMercatorLatitude, clampedCenterLat - latDelta),
            maxLatitude: min(maxMercatorLatitude, clampedCenterLat + latDelta),
            minLongitude: max(-180.0, center.longitude - lonDelta),
            maxLongitude: min(180.0, center.longitude + lonDelta)
        )
    }
    // Menghitung jumlah tile Web Mercator (Slippy Map) dari zoom bawah sampai zoom atas.
    public static func estimatedTileCount(
        for box: CoordinateBox,
        zoomRange: ClosedRange<UInt8> = defaultMinZoom...defaultMaxZoom
    ) -> Int {
        var total = 0
        for z in zoomRange {
            let n = Double(1 << Int(z)) // 2^z jumlah kotak per sisi bumi pada zoom z
            let maxIndex = max(0, Int(n) - 1)
            let xMin = tileX(longitude: box.minLongitude, n: n, maxIndex: maxIndex)
            let xMax = tileX(longitude: box.maxLongitude, n: n, maxIndex: maxIndex)
            let yNorth = tileY(latitude: box.maxLatitude, n: n, maxIndex: maxIndex)
            let ySouth = tileY(latitude: box.minLatitude, n: n, maxIndex: maxIndex)
            let cols = max(1, abs(xMax - xMin) + 1)
            let rows = max(1, abs(ySouth - yNorth) + 1)
            total += cols * rows
        }
        return total
    }
    // Memastikan jumlah tile selalu <= 700 (di bawah batas 750 Mapbox).
    public static func safeRegionBox(
        center: CLLocationCoordinate2D,
        targetRadiusMeters: Double = defaultRadiusMeters,
        zoomRange: ClosedRange<UInt8> = defaultMinZoom...defaultMaxZoom,
        tileLimit: Int = safeTileCap
    ) -> (box: CoordinateBox, radiusMeters: Double, estimatedTiles: Int) {
        var radius = max(1_000, targetRadiusMeters)
        var box = boundingBox(center: center, radiusMeters: radius)
        var count = estimatedTileCount(for: box, zoomRange: zoomRange)
        while count > tileLimit && radius > 2_000 {
            radius -= 1_000
            box = boundingBox(center: center, radiusMeters: radius)
            count = estimatedTileCount(for: box, zoomRange: zoomRange)
        }
        return (box, radius, count)
    }
    // Rumus Haversine: jarak garis lurus di permukaan bumi (meter).
    public static func distanceMeters(from a: CLLocationCoordinate2D, to b: CLLocationCoordinate2D) -> Double {
        let lat1 = a.latitude * .pi / 180.0
        let lat2 = b.latitude * .pi / 180.0
        let dLat = (b.latitude - a.latitude) * .pi / 180.0
        let dLon = (b.longitude - a.longitude) * .pi / 180.0
        let sinHalfLat = sin(dLat / 2.0)
        let sinHalfLon = sin(dLon / 2.0)
        let h = sinHalfLat * sinHalfLat + cos(lat1) * cos(lat2) * sinHalfLon * sinHalfLon
        return 2.0 * earthRadiusMeters * asin(min(1.0, sqrt(h)))
    }
    public static func isOutsideRelocationThreshold(
        current: CLLocationCoordinate2D,
        cachedCenter: CLLocationCoordinate2D,
        thresholdMeters: Double = relocationThresholdMeters
    ) -> Bool {
        distanceMeters(from: current, to: cachedCenter) > thresholdMeters
    }
    public static func isInsideCachedArea(
        point: CLLocationCoordinate2D,
        cached: CachedCityMetadata
    ) -> Bool {
        boundingBox(center: cached.centerCoordinate, radiusMeters: cached.radiusMeters).contains(point)
    }
    private static func tileX(longitude: Double, n: Double, maxIndex: Int) -> Int {
        let raw = Int(floor((longitude + 180.0) / 360.0 * n))
        return min(max(raw, 0), maxIndex)
    }
    private static func tileY(latitude: Double, n: Double, maxIndex: Int) -> Int {
        let clampedLat = min(max(latitude, -maxMercatorLatitude), maxMercatorLatitude)
        let latRad = clampedLat * .pi / 180.0
        let mercator = log(tan(latRad) + 1.0 / cos(latRad))
        let raw = Int(floor((1.0 - mercator / .pi) / 2.0 * n))
        return min(max(raw, 0), maxIndex)
    }
}
