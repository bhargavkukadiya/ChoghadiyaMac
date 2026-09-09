import CoreLocation
import Foundation
import LocationManager

// MARK: - App Location Service

/// Bridges the official `LocationManager` SPM package to the host macOS application's presentation layer.
@MainActor
final class AppLocationService: ObservableObject {
    // MARK: - Published Properties

    @Published private(set) var currentLocation: CLLocation?

    // MARK: - Dependencies

    private let manager: LocationManager

    // MARK: - Init

    /// Initializes the service with a `LocationManager` instance (defaults to `.shared`).
    init(manager: LocationManager) {
        self.manager = manager
    }

    convenience init() {
        self.init(manager: LocationManager.shared)
    }
}

// MARK: - LocationManaging Conformance

extension AppLocationService: LocationManaging {
    // MARK: - Computed Properties

    var isAuthorized: Bool {
        manager.isAuthorized
    }

    var authorizationStatus: LocationAuthorizationStatus {
        manager.authorizationStatus
    }

    // MARK: - Protocol Methods

    func requestPermission() async -> LocationAuthorizationStatus {
        await manager.requestWhenInUseAuthorizationAsync()
    }

    func fetchCurrentLocation(timeout: TimeInterval = 4.0) async throws -> CLLocation {
        let location = try await manager.getCurrentLocation(
            accuracy: kCLLocationAccuracyKilometer,
            timeout: timeout
        )
        currentLocation = location
        return location
    }

    func reverseGeocodeCity(for location: CLLocation) async -> String {
        do {
            let placemark = try await manager.reverseGeocode(location: location)
            return placemark.locality ?? String(localized: "Current Location")
        } catch {
            return String(localized: "Current Location")
        }
    }

    func reverseGeocodeCityAndTimeZone(for location: CLLocation) async -> (city: String, timeZone: TimeZone) {
        do {
            let placemark = try await manager.reverseGeocode(location: location)
            let city = placemark.locality ?? String(localized: "Current Location")
            let tz = placemark.timeZone ?? .current
            return (city, tz)
        } catch {
            return (String(localized: "Current Location"), .current)
        }
    }
}
