import CoreLocation
import Foundation
import LocationManager

// MARK: - ScheduleLocation Suggestions

extension ScheduleLocation: Identifiable {
    public var id: String {
        "\(latitude),\(longitude),\(timeZone.identifier)"
    }

    private static let ist = TimeZone(identifier: "Asia/Kolkata") ?? TimeZone(secondsFromGMT: 19800)!
    private static let london = TimeZone(identifier: "Europe/London") ?? TimeZone(secondsFromGMT: 0)!
    private static let newYork = TimeZone(identifier: "America/New_York") ?? TimeZone(secondsFromGMT: -18000)!

    static let suggestions: [ScheduleLocation] = [
        .init(latitude: 21.1702, longitude: 72.8311, timeZone: ist, cityName: "Surat, India"),
        .init(latitude: 23.0225, longitude: 72.5714, timeZone: ist, cityName: "Ahmedabad, India"),
        .init(latitude: 19.0760, longitude: 72.8777, timeZone: ist, cityName: "Mumbai, India"),
        .init(latitude: 28.6139, longitude: 77.2090, timeZone: ist, cityName: "New Delhi, India"),
        .init(latitude: 51.5074, longitude: -0.1278, timeZone: london, cityName: "London, United Kingdom"),
        .init(latitude: 40.7128, longitude: -74.0060, timeZone: newYork, cityName: "New York, United States"),
    ]
}

// MARK: - Forward Geocoding Protocol

@MainActor
public protocol ForwardGeocoding {
    func forwardGeocode(address: String) async throws -> [PlacemarkInfo]
}

extension LocationManager: ForwardGeocoding {}

// MARK: - City Search

@MainActor
enum CitySearch {
    /// Resolves a place name to unique cities with usable coordinates and timezones.
    static func search(_ query: String, geocoder: (any ForwardGeocoding)? = nil) async throws -> [ScheduleLocation] {
        let activeGeocoder = geocoder ?? LocationManager.shared
        let places = try await activeGeocoder.forwardGeocode(address: query)
        var seen = Set<String>()
        return places.compactMap { place in
            guard CLLocationCoordinate2DIsValid(place.coordinate),
                  let zone = place.timeZone
            else {
                return nil
            }

            let candidateParts = [place.locality ?? place.name, place.administrativeArea, place.country]
                .compactMap { $0 }
            var uniqueParts: [String] = []
            for part in candidateParts where !uniqueParts.contains(part) {
                uniqueParts.append(part)
            }
            let title = uniqueParts.joined(separator: ", ")

            let location = ScheduleLocation(
                latitude: place.coordinate.latitude,
                longitude: place.coordinate.longitude,
                timeZone: zone,
                cityName: title.isEmpty ? query : title
            )
            return seen.insert(location.id).inserted ? location : nil
        }
    }
}

// MARK: - City Preference

/// City preference is separate from the latest schedule so refreshes cannot change the user's choice.
enum CityPreference {
    private static let key = "selected_city_v1"

    static var selected: ScheduleLocation? {
        get {
            guard let data = UserDefaults(suiteName: SharedScheduleStore.appGroupId)?.data(forKey: key) else {
                return nil
            }
            return try? JSONDecoder().decode(ScheduleLocation.self, from: data)
        }
        set {
            let defaults = UserDefaults(suiteName: SharedScheduleStore.appGroupId)
            if let value = newValue, let data = try? JSONEncoder().encode(value) {
                defaults?.set(data, forKey: key)
            } else {
                defaults?.removeObject(forKey: key)
            }
        }
    }
}
