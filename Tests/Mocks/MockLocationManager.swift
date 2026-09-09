@testable import ChoghadiyaMacApp
import CoreLocation
import Foundation
import LocationManager

// MARK: - Mock Location Manager

/// Test double simulating CoreLocation authorization and coordinate updates for unit testing.
@MainActor
final class MockLocationManager: ObservableObject, LocationManaging {
    // MARK: - Published Properties

    @Published var authorizationStatus: LocationAuthorizationStatus = .notDetermined
    @Published var currentLocation: CLLocation?
    var timeZone: TimeZone = .current

    // MARK: - Spy Properties

    private(set) var requestPermissionCalled = false
    private(set) var fetchCurrentLocationCalled = false

    // MARK: - Computed Properties

    var isAuthorized: Bool {
        authorizationStatus.isAuthorized
    }

    // MARK: - Protocol Implementation

    func requestPermission() async -> LocationAuthorizationStatus {
        requestPermissionCalled = true
        return authorizationStatus
    }

    func fetchCurrentLocation(timeout _: TimeInterval = 4.0) async throws -> CLLocation {
        fetchCurrentLocationCalled = true
        if let current = currentLocation {
            return current
        }
        throw LocationError.locationUnavailable
    }

    func reverseGeocodeCity(for _: CLLocation) async -> String {
        "Mock City"
    }

    func reverseGeocodeCityAndTimeZone(for _: CLLocation) async -> (city: String, timeZone: TimeZone) {
        ("Mock City", timeZone)
    }

    // MARK: - Test Helpers

    func simulateAuthorizationChange(_ status: LocationAuthorizationStatus) {
        authorizationStatus = status
    }

    func simulateLocationUpdate(_ location: CLLocation) {
        currentLocation = location
    }
}
