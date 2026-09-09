import Foundation

// MARK: - Schedule Formatting

/// Value-based display formats shared by the dashboard and widgets.
/// Timezones are explicit so rendering one city cannot change another city's output.
enum ScheduleFormatting {
    // MARK: - Public Formatting Methods

    static func time(_ date: Date, timeZone: TimeZone, locale: Locale = .autoupdatingCurrent) -> String {
        date.formatted(
            Date.FormatStyle(locale: locale, timeZone: timeZone)
                .hour()
                .minute()
        )
    }

    static func selectedDate(_ date: Date, timeZone: TimeZone, locale: Locale = .autoupdatingCurrent) -> String {
        date.formatted(
            Date.FormatStyle(locale: locale, calendar: Calendar(identifier: .gregorian), timeZone: timeZone)
                .weekday(.wide)
                .month(.wide)
                .day()
                .year()
        )
    }

    static func vedicDate(_ date: Date, timeZone: TimeZone, locale: Locale = .autoupdatingCurrent) -> String {
        date.formatted(
            Date.FormatStyle(locale: locale, calendar: Calendar(identifier: .gregorian), timeZone: timeZone)
                .weekday(.wide)
                .month(.abbreviated)
                .day()
        )
    }
}
