@testable import ChoghadiyaMacApp
import XCTest

final class ScheduleLinkTests: XCTestCase {
    func testCityAndCivilDateRoundTripAcrossTimezones() throws {
        let city = try XCTUnwrap(ScheduleLocation.suggestions.last)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = city.timeZone
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2027, month: 1, day: 9)))
        let link = ScheduleLink.url(city: city, date: date)
        let parsed = try XCTUnwrap(try ScheduleLink.parse(link, timeZone: XCTUnwrap(TimeZone(identifier: "Asia/Kolkata"))))
        XCTAssertEqual(parsed.city, city)
        XCTAssertEqual(parsed.date, date)
        let live = try XCTUnwrap(ScheduleLink.parse(ScheduleLink.url(city: city, date: nil), timeZone: .current))
        XCTAssertNil(live.date)
    }

    func testMalformedDeepLinksAreIgnored() throws {
        for value in ["https://schedule", "choghadiya://other", "choghadiya://schedule?city=invalid", "choghadiya://schedule?date=2026-02-31"] {
            XCTAssertNil(try ScheduleLink.parse(XCTUnwrap(URL(string: value)), timeZone: .current))
        }
    }
}
