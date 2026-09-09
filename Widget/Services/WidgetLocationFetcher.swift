import CoreLocation
import Foundation
import LocationManager

// MARK: - Location Fetching Protocol

protocol WidgetLocationFetching: Sendable {
    func fetchLocation(timeout: TimeInterval) async throws -> CLLocation
    func reverseGeocodeCity(for location: CLLocation) async -> String
    func reverseGeocodeCityAndTimeZone(for location: CLLocation) async -> (city: String, timeZone: TimeZone)
}

// MARK: - Widget Location Fetcher

/// Bridges the official `LocationManager` SPM package to Widget extensions with timeout protection.
final class WidgetLocationFetcher: WidgetLocationFetching, @unchecked Sendable {
    func fetchLocation(timeout: TimeInterval = 4.0) async throws -> CLLocation {
        try await LocationManager.shared.getCurrentLocation(
            accuracy: kCLLocationAccuracyKilometer,
            timeout: timeout
        )
    }

    func reverseGeocodeCity(for location: CLLocation) async -> String {
        do {
            let placemark = try await LocationManager.shared.reverseGeocode(location: location)
            return placemark.locality ?? String(localized: "Current Area")
        } catch {
            return String(localized: "Current Area")
        }
    }

    func reverseGeocodeCityAndTimeZone(for location: CLLocation) async -> (city: String, timeZone: TimeZone) {
        do {
            let placemark = try await LocationManager.shared.reverseGeocode(location: location)
            let city = placemark.locality ?? String(localized: "Current Area")
            let tz = placemark.timeZone ?? .current
            return (city, tz)
        } catch {
            return (String(localized: "Current Area"), .current)
        }
    }
}
