import ChoghadiyaKit
@testable import ChoghadiyaMacApp
import CoreLocation
import WidgetKit
import XCTest

private struct UnavailableWidgetLocation: WidgetLocationFetching {
    func fetchLocation(timeout _: TimeInterval) async throws -> CLLocation {
        throw URLError(.notConnectedToInternet)
    }

    func reverseGeocodeCity(for _: CLLocation) async -> String {
        "Unused"
    }

    func reverseGeocodeCityAndTimeZone(for _: CLLocation) async -> (city: String, timeZone: TimeZone) {
        ("Unused", .current)
    }
}

final class WidgetTimelineTests: XCTestCase {
    func testCachedTimelineKeepsDisplayedCityAndExpiresAtSunrise() async throws {
        let city = try XCTUnwrap(ScheduleLocation.suggestions.last)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = city.timeZone
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 9, day: 7, hour: 12)))
        let manager = ChoghadiyaManager(fetcher: StubSunTimesFetcher())
        let schedule = try await manager.getSchedule(latitude: city.latitude, longitude: city.longitude, timeZone: city.timeZone, date: date)
        let store = MemoryScheduleStore()
        store.save(schedule: schedule, cityName: city.cityName, location: city)
        let provider = ChoghadiyaTimelineProvider(locationFetcher: UnavailableWidgetLocation(), manager: manager,
                                                  store: store, preferredCity: { nil }, now: { date })
        let timeline = await provider.timeline(city: nil, selectedDate: nil)
        XCTAssertEqual(timeline.entries.first?.location, city, "Opening the widget must preserve the displayed city")
        XCTAssertEqual(timeline.entries.first?.date, date)
        XCTAssertEqual(timeline.entries.last?.date, schedule.allSlots.last?.endTime)
        XCTAssertNil(timeline.entries.last?.slot, "The final slot must disappear even when WidgetKit delays refresh")
        XCTAssertEqual(timeline.entries.last?.location, city)
    }

    func testFreshFallbackTimelineKeepsLocation() async {
        let provider = ChoghadiyaTimelineProvider(locationFetcher: UnavailableWidgetLocation(),
                                                  manager: ChoghadiyaManager(fetcher: StubSunTimesFetcher()), store: MemoryScheduleStore(), preferredCity: { nil })
        let timeline = await provider.timeline(city: nil, selectedDate: nil)
        XCTAssertEqual(timeline.entries.first?.location?.latitude, 21.1702)
        XCTAssertNotNil(timeline.entries.first?.slot)
    }

    func testExplicitWidgetCityDoesNotUseOrOverwriteOtherCityCache() async throws {
        let store = MemoryScheduleStore()
        let manager = ChoghadiyaManager(fetcher: StubSunTimesFetcher())
        let city = ScheduleLocation.suggestions[0]
        let chosen = try XCTUnwrap(ScheduleLocation.suggestions.last)
        let schedule = try await manager.getSchedule(latitude: city.latitude, longitude: city.longitude, timeZone: city.timeZone, date: Date())
        store.save(schedule: schedule, cityName: city.cityName, location: city)
        let original = store.payload
        let provider = ChoghadiyaTimelineProvider(locationFetcher: UnavailableWidgetLocation(), manager: manager,
                                                  store: store, preferredCity: { city })
        let timeline = await provider.timeline(city: chosen, selectedDate: nil)
        XCTAssertEqual(timeline.entries.first?.location, chosen)
        XCTAssertEqual(store.payload, original)
    }

    func testSnapshotRejectsWrongCityAndExpiredCacheWithoutInventingTimings() async throws {
        let city = ScheduleLocation.suggestions[0]
        let chosen = try XCTUnwrap(ScheduleLocation.suggestions.last)
        let date = Date()
        let manager = ChoghadiyaManager(fetcher: StubSunTimesFetcher())
        let schedule = try await manager.getSchedule(latitude: city.latitude, longitude: city.longitude,
                                                     timeZone: city.timeZone, date: date)
        let store = MemoryScheduleStore()
        store.save(schedule: schedule, cityName: city.cityName, location: city)
        let provider = ChoghadiyaTimelineProvider(manager: manager, store: store, preferredCity: { chosen },
                                                  now: { schedule.daySlots[0].startTime })
        XCTAssertNil(provider.snapshotEntry(isPreview: false).slot)
        XCTAssertEqual(provider.snapshotEntry(isPreview: false).location, chosen)
        XCTAssertNotNil(provider.snapshotEntry(isPreview: true).slot)
        let expired = ChoghadiyaTimelineProvider(manager: manager, store: store, preferredCity: { nil },
                                                 now: { schedule.allSlots.last!.endTime })
        XCTAssertNil(expired.snapshotEntry(isPreview: false).slot)
    }

    func testFixedDateFailurePreservesCivilDateForDeepLink() async throws {
        let fetcher = StubSunTimesFetcher()
        await fetcher.configure(fails: true)
        let city = try XCTUnwrap(ScheduleLocation.suggestions.last)
        let components = DateComponents(year: 2027, month: 1, day: 9)
        let date = try XCTUnwrap(Calendar(identifier: .gregorian).date(from: components))
        let provider = ChoghadiyaTimelineProvider(manager: ChoghadiyaManager(fetcher: fetcher),
                                                  store: MemoryScheduleStore(), preferredCity: { nil })
        let timeline = await provider.timeline(city: city, selectedDate: date)
        let entry = try XCTUnwrap(timeline.entries.first)
        XCTAssertNil(entry.slot)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = city.timeZone
        XCTAssertEqual(try calendar.dateComponents([.year, .month, .day], from: XCTUnwrap(entry.selectedDate)), components)
    }
}
