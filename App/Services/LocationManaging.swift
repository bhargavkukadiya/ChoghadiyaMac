import CoreLocation
import Foundation
import LocationManager

// MARK: - Location Managing Protocol

/// Protocol abstracting CoreLocation operations and authorization state for dependency injection.
@MainActor
protocol LocationManaging: ObservableObject {
    /// Whether location services are authorized for use
    var isAuthorized: Bool { get }

    /// Detailed authorization status enum
    var authorizationStatus: LocationAuthorizationStatus { get }

    /// Most recently captured geographic location
    var currentLocation: CLLocation? { get }

    /// Asynchronously requests when-in-use location permissions from the user
    func requestPermission() async -> LocationAuthorizationStatus

    /// Requests a one-shot current location fix with an operational timeout
    func fetchCurrentLocation(timeout: TimeInterval) async throws -> CLLocation

    /// Reverse-geocodes a geographic coordinate into a human-readable city/locality name
    func reverseGeocodeCity(for location: CLLocation) async -> String

    /// Reverse-geocodes a location into a city name and timezone
    func reverseGeocodeCityAndTimeZone(for location: CLLocation) async -> (city: String, timeZone: TimeZone)
}
