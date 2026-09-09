@testable import ChoghadiyaMacApp
import XCTest

final class ScheduleFormattingTests: XCTestCase {
    private func normalized(_ value: String) -> String {
        value.components(separatedBy: .whitespaces).filter { !$0.isEmpty }.joined(separator: " ")
    }

    func testConcurrentCityFormattingKeepsEachTimezone() async throws {
        let date = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-09-07T12:00:00Z"))
        let india = try XCTUnwrap(TimeZone(identifier: "Asia/Kolkata"))
        let newYork = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        let values = await withTaskGroup(of: (String, String).self, returning: [(String, String)].self) { group in
            for i in 0 ..< 100 {
                let zone = i.isMultiple(of: 2) ? india : newYork
                let expected = i.isMultiple(of: 2) ? "5:30 PM" : "8:00 AM"
                group.addTask {
                    (ScheduleFormatting.time(date, timeZone: zone, locale: Locale(identifier: "en_US")), expected)
                }
            }
            var results: [(String, String)] = []
            for await result in group {
                results.append(result)
            }
            return results
        }
        for (actual, expected) in values {
            XCTAssertEqual(normalized(actual), expected)
        }
    }

    func testTimeFormattingRespectsLocaleAndDaylightSavingTransition() throws {
        let zone = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        let before = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-03-08T06:30:00Z"))
        let after = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-03-08T07:30:00Z"))
        let locale = Locale(identifier: "en_GB")
        XCTAssertEqual(ScheduleFormatting.time(before, timeZone: zone, locale: locale), "01:30")
        XCTAssertEqual(ScheduleFormatting.time(after, timeZone: zone, locale: locale), "03:30")
    }

    func testDateFormattingUsesCityCivilDay() throws {
        let date = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-09-07T02:00:00Z"))
        let zone = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        let locale = Locale(identifier: "en_US")
        XCTAssertEqual(ScheduleFormatting.selectedDate(date, timeZone: zone, locale: locale), "Sunday, September 6, 2026")
        XCTAssertEqual(ScheduleFormatting.vedicDate(date, timeZone: zone, locale: locale), "Sunday, Sep 6")
    }
}
