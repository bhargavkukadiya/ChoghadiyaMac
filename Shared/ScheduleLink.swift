import Foundation

// MARK: - Schedule Link

/// A local deep link keeps a widget's city and date when opening the app.
enum ScheduleLink {
    // MARK: - URL Generation

    /// Encodes a city and its civil date for opening a widget selection in the app.
    static func url(city: ScheduleLocation?, date: Date?) -> URL {
        var components = URLComponents()
        components.scheme = "choghadiya"
        components.host = "schedule"
        var items: [URLQueryItem] = []

        if let city, let data = try? JSONEncoder().encode(city) {
            items.append(URLQueryItem(name: "city", value: data.base64EncodedString()))
        }

        if let date {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.timeZone = city?.timeZone ?? .current
            formatter.dateFormat = "yyyy-MM-dd"
            items.append(URLQueryItem(name: "date", value: formatter.string(from: date)))
        }

        components.queryItems = items.isEmpty ? nil : items
        return components.url ?? URL(string: "choghadiya://schedule")!
    }

    // MARK: - URL Parsing

    /// Rejects malformed coordinates or dates before applying an external URL.
    static func parse(_ url: URL, timeZone: TimeZone) -> (city: ScheduleLocation?, date: Date?)? {
        guard url.scheme == "choghadiya",
              url.host == "schedule",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else {
            return nil
        }

        let items = components.queryItems ?? []
        var city: ScheduleLocation?

        if let encoded = items.first(where: { $0.name == "city" })?.value {
            guard let data = Data(base64Encoded: encoded),
                  let decoded = try? JSONDecoder().decode(ScheduleLocation.self, from: data),
                  decoded.latitude.isFinite,
                  decoded.longitude.isFinite,
                  (-90 ... 90).contains(decoded.latitude),
                  (-180 ... 180).contains(decoded.longitude)
            else {
                return nil
            }
            city = decoded
        }

        var date: Date?
        if let string = items.first(where: { $0.name == "date" })?.value {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.timeZone = city?.timeZone ?? timeZone
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.isLenient = false
            guard let parsed = formatter.date(from: string),
                  formatter.string(from: parsed) == string
            else {
                return nil
            }
            date = parsed
        }

        return (city, date)
    }
}
