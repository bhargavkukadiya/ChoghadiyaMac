import ChoghadiyaKit
import CoreLocation
import Foundation
import WidgetKit
#if TESTING_WIDGET_PROVIDER
    @testable import ChoghadiyaMacApp
#endif

// MARK: - Choghadiya Timeline Provider

/// Coordinates location discovery and astronomical schedule computation for the WidgetKit timeline.
struct ChoghadiyaTimelineProvider: TimelineProvider {
    // MARK: - Fallback Coordinates

    private enum DefaultLocation {
        static let latitude: Double = 21.1702
        static let longitude: Double = 72.8311
        static let timeZone = TimeZone(identifier: "Asia/Kolkata") ?? .current
        static let cityName = "Surat"
    }

    // MARK: - Dependencies

    private let locationFetcher: WidgetLocationFetching
    private let manager: ChoghadiyaManager
    private let store: any ScheduleStoring
    private let preferredCity: () -> ScheduleLocation?
    private let now: () -> Date

    // MARK: - Init

    init(
        locationFetcher: WidgetLocationFetching = WidgetLocationFetcher(),
        manager: ChoghadiyaManager = ChoghadiyaManager(),
        store: any ScheduleStoring = SharedScheduleStore.shared,
        preferredCity: @escaping () -> ScheduleLocation? = { CityPreference.selected },
        now: @escaping () -> Date = Date.init
    ) {
        self.locationFetcher = locationFetcher
        self.manager = manager
        self.store = store
        self.preferredCity = preferredCity
        self.now = now
    }

    // MARK: - Placeholder

    func placeholder(in _: Context) -> SimpleEntry {
        if let payload = store.load(),
           let current = payload.schedule.currentSlot(at: Date())
        {
            return SimpleEntry(date: Date(), slot: current, city: payload.cityName, schedule: payload.schedule)
        }
        let slot = ChoghadiyaSlot(type: .shubh, startTime: Date(), endTime: Date().addingTimeInterval(3600))
        return SimpleEntry(date: Date(), slot: slot, city: DefaultLocation.cityName)
    }

    // MARK: - Snapshot

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
        completion(snapshotEntry(isPreview: context.isPreview))
    }

    func snapshotEntry(isPreview: Bool) -> SimpleEntry {
        let date = now()
        let chosen = preferredCity()
        if let payload = store.load(),
           chosen == nil || payload.location == chosen,
           let current = payload.schedule.currentSlot(at: date)
        {
            return SimpleEntry(date: date, slot: current, city: payload.cityName,
                               schedule: payload.schedule, location: payload.location)
        }
        let sample = isPreview ? ChoghadiyaSlot(type: .amrit, startTime: date, endTime: date.addingTimeInterval(3600)) : nil
        return SimpleEntry(date: date, slot: sample, city: chosen?.cityName ?? DefaultLocation.cityName, location: chosen)
    }

    // MARK: - Timeline

    func getTimeline(in _: Context, completion: @escaping (Timeline<SimpleEntry>) -> Void) {
        Task { await completion(timeline(city: nil, selectedDate: nil)) }
    }

    func timeline(city: ScheduleLocation?, selectedDate: Date?) async -> Timeline<SimpleEntry> {
        let chosen = city ?? preferredCity()
        let now = now()
        if selectedDate == nil, let payload = store.load(),
           payload.schedule.currentSlot(at: now) != nil,
           chosen == nil || payload.location == chosen
        {
            return buildTimeline(from: payload.schedule, city: payload.cityName, location: payload.location)
        }
        if chosen != nil || selectedDate != nil {
            return await timelineForExplicitCityOrDate(chosen: chosen, selectedDate: selectedDate, city: city)
        }
        let (schedule, cityName, location) = await loadScheduleWithFallback()
        if let schedule {
            store.save(schedule: schedule, cityName: cityName, location: location)
        }
        return buildTimeline(from: schedule, city: cityName, location: location)
    }

    private func timelineForExplicitCityOrDate(
        chosen: ScheduleLocation?,
        selectedDate: Date?,
        city: ScheduleLocation?
    ) async -> Timeline<SimpleEntry> {
        let now = now()
        let location = chosen ?? store.load()?.location ?? ScheduleLocation.suggestions[0]
        var calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents([.year, .month, .day], from: selectedDate ?? now)
        calendar.timeZone = location.timeZone
        let targetDate = selectedDate == nil ? nil : calendar.date(from: components)
        do {
            let date = targetDate ?? now
            var schedule = try await manager.getSchedule(latitude: location.latitude, longitude: location.longitude,
                                                         timeZone: location.timeZone, date: date)
            if selectedDate == nil {
                schedule = try await adjustForPreSunrise(schedule, latitude: location.latitude,
                                                        longitude: location.longitude, timeZone: location.timeZone)
            }
            if selectedDate != nil {
                let entry = SimpleEntry(date: now, slot: schedule.daySlots.first, city: location.cityName,
                                        schedule: schedule, selectedDate: date, location: location)
                return Timeline(entries: [entry], policy: .after(now.addingTimeInterval(6 * 3600)))
            }
            if city == nil {
                store.save(schedule: schedule, cityName: location.cityName, location: location)
            }
            return buildTimeline(from: schedule, city: location.cityName, location: location)
        } catch {
            return Timeline(entries: [SimpleEntry(date: now, slot: nil, city: location.cityName, selectedDate: targetDate, location: location)],
                            policy: .after(now.addingTimeInterval(300)))
        }
    }

    // MARK: - Private Schedule Loading

    private func loadScheduleWithFallback() async -> (ChoghadiyaSchedule?, String, ScheduleLocation?) {
        let now = now()
        do {
            let location = try await locationFetcher.fetchLocation(timeout: 3.5)
            let (city, locationTimeZone) = await locationFetcher.reverseGeocodeCityAndTimeZone(for: location)
            let initialSchedule = try await manager.getSchedule(
                coordinate: location.coordinate,
                timeZone: locationTimeZone,
                date: now
            )
            let schedule = try await adjustForPreSunrise(
                initialSchedule,
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                timeZone: locationTimeZone
            )
            return (schedule, city, ScheduleLocation(latitude: location.coordinate.latitude,
                                                     longitude: location.coordinate.longitude, timeZone: locationTimeZone, cityName: city))
        } catch {
            // Graceful fallback to default astrological coordinate
            do {
                let initialFallback = try await manager.getSchedule(
                    latitude: DefaultLocation.latitude,
                    longitude: DefaultLocation.longitude,
                    timeZone: DefaultLocation.timeZone,
                    date: now
                )
                let schedule = try await adjustForPreSunrise(
                    initialFallback,
                    latitude: DefaultLocation.latitude,
                    longitude: DefaultLocation.longitude,
                    timeZone: DefaultLocation.timeZone
                )
                return (
                    schedule,
                    DefaultLocation.cityName,
                    ScheduleLocation(
                        latitude: DefaultLocation.latitude,
                        longitude: DefaultLocation.longitude,
                        timeZone: DefaultLocation.timeZone,
                        cityName: DefaultLocation.cityName
                    )
                )
            } catch {
                return (nil, String(localized: "Unavailable"), nil)
            }
        }
    }

    /// In Vedic astrology, pre-sunrise hours belong to the previous calendar day's cycle.
    /// Returns the previous day's schedule if the current time is before sunrise.
    private func adjustForPreSunrise(
        _ schedule: ChoghadiyaSchedule,
        latitude: Double,
        longitude: Double,
        timeZone: TimeZone
    ) async throws -> ChoghadiyaSchedule {
        let now = now()
        guard let sunrise = schedule.daySlots.first?.startTime, now < sunrise else {
            return schedule
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        guard let previousDate = calendar.date(byAdding: .day, value: -1, to: now) else {
            return schedule
        }
        return try await manager.getSchedule(
            latitude: latitude,
            longitude: longitude,
            timeZone: timeZone,
            date: previousDate
        )
    }

    /// Builds a chronological WidgetKit `Timeline` from a calculated `ChoghadiyaSchedule`.
    private func buildTimeline(from schedule: ChoghadiyaSchedule?, city: String, location: ScheduleLocation? = nil) -> Timeline<SimpleEntry> {
        let now = now()

        guard let schedule else {
            let errorEntry = SimpleEntry(date: now, slot: nil, city: city, location: location)
            return Timeline(entries: [errorEntry], policy: .after(now.addingTimeInterval(300)))
        }

        let allSlots = schedule.allSlots
        var entries: [SimpleEntry] = allSlots
            .filter { $0.endTime > now }
            .map { slot in
                SimpleEntry(
                    date: max(now, slot.startTime),
                    slot: slot,
                    city: city,
                    schedule: schedule,
                    location: location
                )
            }

        guard !entries.isEmpty else {
            return Timeline(entries: [SimpleEntry(date: now, slot: nil, city: city, location: location)],
                            policy: .after(now.addingTimeInterval(60)))
        }
        let refreshDate = allSlots.last?.endTime ?? now.addingTimeInterval(3600)
        // WidgetKit may delay the requested refresh. Expire the last slot locally.
        entries.append(SimpleEntry(date: refreshDate, slot: nil, city: city, location: location))
        return Timeline(entries: entries, policy: .after(refreshDate))
    }
}
