import ChoghadiyaKit
@testable import ChoghadiyaMacApp
import Foundation

typealias ScheduleLocation = ChoghadiyaMacApp.ScheduleLocation

actor StubSunTimesFetcher: SunTimesFetching {
    var fails = false
    var delay: UInt64 = 0
    private(set) var requests = 0
    private(set) var lastLatitude: Double?

    func configure(fails: Bool = false, delay: UInt64 = 0) {
        self.fails = fails
        self.delay = delay
    }

    func fetchSunTimes(for _: String, date: Date) async throws -> SunTimes {
        try await fetchSunTimes(latitude: 0, longitude: 0, timeZone: .current, date: date)
    }

    func fetchSunTimes(latitude: Double, longitude _: Double, timeZone: TimeZone, date: Date) async throws -> SunTimes {
        requests += 1
        lastLatitude = latitude
        if delay > 0 {
            try await Task.sleep(nanoseconds: delay)
        }
        if fails {
            throw URLError(.notConnectedToInternet)
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let start = calendar.startOfDay(for: date)
        let sunrise = calendar.date(byAdding: .hour, value: 6, to: start)!
        let sunset = calendar.date(byAdding: .hour, value: 18, to: start)!
        return SunTimes(sunrise: sunrise, sunset: sunset,
                        nextSunrise: calendar.date(byAdding: .day, value: 1, to: sunrise)!, timeZone: timeZone)
    }
}

final class MemoryScheduleStore: ScheduleStoring {
    var payload: SharedSchedulePayload?
    func load() -> SharedSchedulePayload? {
        payload
    }

    func save(schedule: ChoghadiyaSchedule, cityName: String, location: ScheduleLocation?) {
        payload = SharedSchedulePayload(schedule: schedule, cityName: cityName, location: location)
    }
}

@MainActor
final class TestClock {
    var date = Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 5, hour: 12))!
}
