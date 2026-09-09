import ChoghadiyaKit
@testable import ChoghadiyaMacApp
import CoreLocation
import LocationManager
import XCTest

// MARK: - ChoghadiyaKit Integration Tests

final class ChoghadiyaKitIntegrationTests: XCTestCase {
    // MARK: - Tests

    func testChoghadiyaTypeProperties() {
        let auspiciousTypes: [ChoghadiyaType] = [.amrit, .shubh, .labh]
        for type in auspiciousTypes {
            XCTAssertTrue(type.isAuspicious, "\(type.rawValue) should be auspicious")
            XCTAssertTrue(type.auspiciousness.isFavorable, "\(type.rawValue) auspiciousness should be favorable")
        }

        let inauspiciousTypes: [ChoghadiyaType] = [.udveg, .kaal, .rog]
        for type in inauspiciousTypes {
            XCTAssertFalse(type.isAuspicious, "\(type.rawValue) should not be auspicious")
            XCTAssertFalse(type.auspiciousness.isFavorable, "\(type.rawValue) should not be favorable")
        }

        XCTAssertFalse(ChoghadiyaType.chal.isAuspicious)
        XCTAssertEqual(ChoghadiyaType.chal.auspiciousness, .neutral)
    }

    func testChoghadiyaRulingPlanets() {
        XCTAssertEqual(ChoghadiyaType.amrit.rulingPlanet, "Moon (Chandra)")
        XCTAssertEqual(ChoghadiyaType.shubh.rulingPlanet, "Jupiter (Guru)")
        XCTAssertEqual(ChoghadiyaType.labh.rulingPlanet, "Mercury (Budha)")
        XCTAssertEqual(ChoghadiyaType.chal.rulingPlanet, "Venus (Shukra)")
        XCTAssertEqual(ChoghadiyaType.udveg.rulingPlanet, "Sun (Surya)")
        XCTAssertEqual(ChoghadiyaType.kaal.rulingPlanet, "Saturn (Shani)")
        XCTAssertEqual(ChoghadiyaType.rog.rulingPlanet, "Mars (Mangal)")
    }

    func testSlotContainsDate() {
        let now = Date()
        let start = now.addingTimeInterval(-1800)
        let end = now.addingTimeInterval(1800)
        let slot = ChoghadiyaSlot(type: .shubh, startTime: start, endTime: end)

        XCTAssertTrue(slot.contains(date: now))
        XCTAssertTrue(slot.isActive(at: now))
        XCTAssertFalse(slot.contains(date: now.addingTimeInterval(3600)))
        XCTAssertEqual(slot.duration, 3600)
    }

    func testLocationAuthorizationStatus() {
        XCTAssertTrue(LocationAuthorizationStatus.authorizedAlways.isAuthorized)
        XCTAssertTrue(LocationAuthorizationStatus.authorizedWhenInUse.isAuthorized)
        XCTAssertFalse(LocationAuthorizationStatus.denied.isAuthorized)
        XCTAssertFalse(LocationAuthorizationStatus.restricted.isAuthorized)
        XCTAssertFalse(LocationAuthorizationStatus.notDetermined.isAuthorized)
    }

    func testChoghadiyaScheduleActiveSlotPreSunrise() {
        // Create 24-hour cycle: Day 1 sunrise at 06:00, sunset at 18:00, next sunrise at 06:00
        let cal = Calendar(identifier: .gregorian)
        var components = DateComponents()
        components.year = 2026
        components.month = 9
        components.day = 4
        components.hour = 6
        components.minute = 0
        guard let day1Sunrise = cal.date(from: components),
              let day1Sunset = cal.date(byAdding: .hour, value: 12, to: day1Sunrise),
              let day2Sunrise = cal.date(byAdding: .hour, value: 12, to: day1Sunset)
        else {
            XCTFail("Failed to construct test dates")
            return
        }

        // Build 8 day slots and 8 night slots
        let dayDuration = day1Sunset.timeIntervalSince(day1Sunrise) / 8.0
        let nightDuration = day2Sunrise.timeIntervalSince(day1Sunset) / 8.0

        let daySlots = (0 ..< 8).map { i in
            ChoghadiyaSlot(
                type: .shubh,
                startTime: day1Sunrise.addingTimeInterval(Double(i) * dayDuration),
                endTime: day1Sunrise.addingTimeInterval(Double(i + 1) * dayDuration)
            )
        }

        let nightSlots = (0 ..< 8).map { i in
            ChoghadiyaSlot(
                type: .amrit,
                startTime: day1Sunset.addingTimeInterval(Double(i) * nightDuration),
                endTime: day1Sunset.addingTimeInterval(Double(i + 1) * nightDuration)
            )
        }

        let schedule = ChoghadiyaSchedule(daySlots: daySlots, nightSlots: nightSlots, timeZone: .current)

        XCTAssertEqual(schedule.daySlots.count, 8)
        XCTAssertEqual(schedule.nightSlots.count, 8)
        XCTAssertEqual(schedule.allSlots.count, 16)

        // Test pre-sunrise date on Day 2 at 01:55 AM (which is 19 hours 55 minutes after Day 1 sunrise)
        let preSunriseDate = day1Sunrise.addingTimeInterval(19 * 3600 + 55 * 60)
        XCTAssertFalse(schedule.isDaytime(at: preSunriseDate), "01:55 AM must be recognized as nighttime")

        let activeSlot = schedule.currentSlot(at: preSunriseDate)
        XCTAssertNotNil(activeSlot, "01:55 AM must resolve to an active night slot")
        XCTAssertEqual(activeSlot?.type, .amrit)
        XCTAssertTrue(activeSlot?.contains(date: preSunriseDate) == true)
    }

    func testSharedScheduleStoreSaveAndLoad() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("schedule.json")
        let store = SharedScheduleStore(defaults: nil, fileURL: file)
        let manager = ChoghadiyaManager(fetcher: StubSunTimesFetcher())
        let schedule = try await manager.getSchedule(latitude: 21.17, longitude: 72.83,
                                                     timeZone: .current, date: Date())
        let location = ScheduleLocation(latitude: 21.17, longitude: 72.83, timeZone: .current, cityName: "Test City")
        store.save(schedule: schedule, cityName: location.cityName, location: location)
        let reopened = SharedScheduleStore(defaults: nil, fileURL: file)
        XCTAssertEqual(reopened.load()?.schedule, schedule)
        XCTAssertEqual(reopened.load()?.location, location)
        XCTAssertEqual(reopened.load()?.cityName, "Test City")
        reopened.clear()
        XCTAssertNil(store.load())
        try Data("invalid JSON".utf8).write(to: file)
        XCTAssertNil(store.load())
    }
}
