import AppIntents
import Foundation
import WidgetKit

// MARK: - Widget City App Entity

@available(macOS 14.0, *)
struct WidgetCity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "City"
    static var defaultQuery = WidgetCityQuery()

    let location: ScheduleLocation

    var id: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return (try? encoder.encode(location).base64EncodedString()) ?? location.id
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(location.cityName)", subtitle: "\(location.timeZone.identifier)")
    }
}

// MARK: - Widget City Query

@available(macOS 14.0, *)
struct WidgetCityQuery: EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [WidgetCity] {
        identifiers.compactMap { id in
            guard let data = Data(base64Encoded: id),
                  let city = try? JSONDecoder().decode(ScheduleLocation.self, from: data)
            else {
                return nil
            }
            return WidgetCity(location: city)
        }
    }

    func entities(matching string: String) async throws -> [WidgetCity] {
        try await CitySearch.search(string).map { WidgetCity(location: $0) }
    }

    func suggestedEntities() async throws -> [WidgetCity] {
        var cities = ScheduleLocation.suggestions
        if let selected = CityPreference.selected {
            cities.removeAll { $0.id == selected.id }
            cities.insert(selected, at: 0)
        }
        return cities.map { WidgetCity(location: $0) }
    }
}

// MARK: - Schedule Widget Intent

@available(macOS 14.0, *)
struct ScheduleWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Choghadiya"
    static var description = IntentDescription("Choose a city and date. Leave them empty to follow the app’s city and show live timings.")

    @Parameter(title: "City", description: "Leave empty to follow the city selected in the app.")
    var city: WidgetCity?

    @Parameter(title: "Date", description: "Leave empty for live timings. Select a date for a day overview.", kind: .date)
    var selectedDate: Date?
}

// MARK: - Configurable Schedule Provider

@available(macOS 14.0, *)
struct ConfigurableScheduleProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        ChoghadiyaTimelineProvider().placeholder(in: context)
    }

    func snapshot(for configuration: ScheduleWidgetIntent, in _: Context) async -> SimpleEntry {
        let timeline = await ChoghadiyaTimelineProvider().timeline(
            city: configuration.city?.location,
            selectedDate: configuration.selectedDate
        )
        return timeline.entries.first ?? SimpleEntry(slot: nil, city: String(localized: "Timings unavailable"))
    }

    func timeline(for configuration: ScheduleWidgetIntent, in _: Context) async -> Timeline<SimpleEntry> {
        await ChoghadiyaTimelineProvider().timeline(
            city: configuration.city?.location,
            selectedDate: configuration.selectedDate
        )
    }
}
