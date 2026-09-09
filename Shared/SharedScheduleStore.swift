import ChoghadiyaKit
import Foundation

public struct ScheduleLocation: Codable, Sendable, Equatable {
    public let latitude: Double
    public let longitude: Double
    public let timeZone: TimeZone
    public let cityName: String
}

protocol ScheduleStoring {
    func load() -> SharedSchedulePayload?
    func save(schedule: ChoghadiyaSchedule, cityName: String, location: ScheduleLocation?)
}

// MARK: - Shared Schedule Payload

/// Codable payload representing the calculated Choghadiya schedule and metadata shared between App and Widget.
public struct SharedSchedulePayload: Codable, Sendable, Equatable {
    public let schedule: ChoghadiyaSchedule
    public let cityName: String
    public let location: ScheduleLocation?
    public let updatedAt: Date

    public init(schedule: ChoghadiyaSchedule, cityName: String, updatedAt: Date = Date(), location: ScheduleLocation? = nil) {
        self.schedule = schedule
        self.cityName = cityName
        self.updatedAt = updatedAt
        self.location = location
    }
}

// MARK: - Shared Schedule Store

/// Provides persistent, thread-safe synchronization of Choghadiya schedules between the host application
/// and WidgetKit extensions using Apple App Groups (`group.com.choghadiya.mac`).
public final class SharedScheduleStore: ScheduleStoring, @unchecked Sendable {
    // MARK: - Singleton

    public static let shared = SharedScheduleStore()

    // MARK: - Constants

    public static let appGroupId = "group.com.choghadiya.mac"
    private static let payloadKey = "shared_choghadiya_schedule_payload"
    private static let fileName = "shared_schedule.json"

    // MARK: - Storage Accessors

    private let injectedStorage: (defaults: UserDefaults?, fileURL: URL?)?

    private var userDefaults: UserDefaults? {
        if let injectedStorage {
            return injectedStorage.defaults
        }
        return UserDefaults(suiteName: Self.appGroupId)
    }

    private var containerFileURL: URL? {
        if let injectedStorage {
            return injectedStorage.fileURL
        }
        return FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupId)?
            .appendingPathComponent(Self.fileName)
    }

    // MARK: - Init

    private init() {
        injectedStorage = nil
    }

    /// Isolated storage for tests; never touches the production App Group.
    init(defaults: UserDefaults?, fileURL: URL?) {
        injectedStorage = (defaults, fileURL)
    }

    // MARK: - Public API

    /// Persists the calculated schedule and city name to both App Group UserDefaults and shared container storage.
    public func save(schedule: ChoghadiyaSchedule, cityName: String, location: ScheduleLocation? = nil) {
        let payload = SharedSchedulePayload(schedule: schedule, cityName: cityName, updatedAt: Date(), location: location)

        guard let encoded = try? JSONEncoder().encode(payload) else { return }

        // Primary: App Group UserDefaults
        if let defaults = userDefaults {
            defaults.set(encoded, forKey: Self.payloadKey)
        }

        // Secondary: Shared container file
        if let fileURL = containerFileURL {
            try? encoded.write(to: fileURL, options: .atomic)
        }
    }

    /// Loads the active shared schedule payload from App Group UserDefaults or shared container storage.
    public func load() -> SharedSchedulePayload? {
        // Try App Group UserDefaults first
        if let defaults = userDefaults,
           let data = defaults.data(forKey: Self.payloadKey),
           let payload = try? JSONDecoder().decode(SharedSchedulePayload.self, from: data)
        {
            return payload
        }

        // Fall back to shared container file
        if let fileURL = containerFileURL,
           let data = try? Data(contentsOf: fileURL),
           let payload = try? JSONDecoder().decode(SharedSchedulePayload.self, from: data)
        {
            return payload
        }

        return nil
    }

    /// Clears any cached schedule in shared storage.
    public func clear() {
        userDefaults?.removeObject(forKey: Self.payloadKey)
        if let fileURL = containerFileURL {
            try? FileManager.default.removeItem(at: fileURL)
        }
    }
}
