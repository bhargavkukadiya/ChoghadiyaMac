import ChoghadiyaKit
import Combine
import CoreLocation
import Foundation
import LocationManager
import WidgetKit

// MARK: - Content ViewModel

@MainActor
final class ContentViewModel: ObservableObject {
    // MARK: - Published State

    @Published private(set) var state: ScheduleViewState = .idle
    @Published private(set) var schedule: ChoghadiyaSchedule?
    @Published private(set) var activeSlot: ChoghadiyaSlot?
    @Published private(set) var cityName = String(localized: "Detecting...")
    @Published private(set) var vedicDateString = ""
    @Published private(set) var timeRemainingString = ""
    @Published private(set) var statusMessage: String?
    @Published private(set) var authorizationStatus: LocationAuthorizationStatus
    @Published private(set) var isRequestingPermission = false
    @Published var selectedTab: DayNightTab = .day
    @Published private(set) var selectedDate: Date
    @Published private(set) var isViewingToday = true

    @Published private(set) var selectedCity: ScheduleLocation?

    // MARK: - Dependencies and Private State

    private let persistCity: (ScheduleLocation?) -> Void

    private let locationManager: any LocationManaging
    private let choghadiyaManager: ChoghadiyaManager
    private let store: any ScheduleStoring
    private let now: () -> Date
    private let widgetReload: () -> Void
    private var timerCancellable: AnyCancellable?
    private var scheduleTask: Task<Void, Never>?
    private var permissionTask: Task<Void, Never>?
    private var requestID = UUID()
    private var retryAfter = Date.distantPast
    private var currentPhaseIsDay: Bool?
    private var scheduleLocation: ScheduleLocation?
    private var lastScheduleTimeZone: TimeZone?
    private static let istTimeZone = TimeZone(identifier: "Asia/Kolkata") ?? TimeZone(secondsFromGMT: 19800)!
    private let fallback = ScheduleLocation(
        latitude: 21.1702,
        longitude: 72.8311,
        timeZone: ContentViewModel.istTimeZone,
        cityName: String(localized: "Surat (Default)")
    )

    // MARK: - Initialization

    init(
        locationManager: any LocationManaging,
        choghadiyaManager: ChoghadiyaManager = ChoghadiyaManager(),
        store: any ScheduleStoring = SharedScheduleStore.shared,
        now: @escaping () -> Date = Date.init,
        startsTimer: Bool = true,
        selectedCity: ScheduleLocation? = nil,
        persistCity: @escaping (ScheduleLocation?) -> Void = { _ in },
        widgetReload: @escaping () -> Void = { WidgetCenter.shared.reloadAllTimelines() }
    ) {
        self.selectedCity = selectedCity
        self.persistCity = persistCity
        self.locationManager = locationManager
        self.choghadiyaManager = choghadiyaManager
        self.store = store
        self.now = now
        self.widgetReload = widgetReload
        selectedDate = now()
        authorizationStatus = locationManager.authorizationStatus
        if startsTimer {
            timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
                .autoconnect()
                .sink { [weak self] _ in
                    self?.tick()
                }
        }
    }

    convenience init() {
        self.init(
            locationManager: AppLocationService(),
            selectedCity: CityPreference.selected,
            persistCity: { CityPreference.selected = $0 }
        )
    }

    deinit {
        scheduleTask?.cancel()
        permissionTask?.cancel()
        timerCancellable?.cancel()
    }

    // MARK: - Navigation and User Actions

    var selectionCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = selectedCity?.timeZone ?? scheduleLocation?.timeZone ?? lastScheduleTimeZone ?? .current
        return calendar
    }

    func openSchedule(_ url: URL) {
        guard let request = ScheduleLink.parse(url, timeZone: selectionCalendar.timeZone) else {
            return
        }
        if let city = request.city {
            selectCity(city)
        }
        selectDate(request.date ?? now())
    }

    func selectCity(_ city: ScheduleLocation?) {
        let components = selectionCalendar.dateComponents([.year, .month, .day], from: selectedDate)
        selectedCity = city
        scheduleLocation = city
        selectedDate = isViewingToday ? now() : (selectionCalendar.date(from: components) ?? selectedDate)
        isViewingToday = selectionCalendar.isDate(selectedDate, inSameDayAs: now())
        cityName = city?.cityName ?? String(localized: "Current location")
        persistCity(city)
        clearSchedule()
        startLoading()
        reloadWidgets()
    }

    var isLocationDenied: Bool {
        selectedCity == nil && (authorizationStatus == .denied || authorizationStatus == .restricted)
    }

    var needsLocationPermission: Bool {
        selectedCity == nil && authorizationStatus == .notDetermined
    }

    func onAppear() {
        guard state == .idle else {
            return
        }
        refresh()
    }

    func onBecomeActive() {
        let changed = authorizationStatus != locationManager.authorizationStatus
        authorizationStatus = locationManager.authorizationStatus
        tick()
        if changed {
            if locationManager.isAuthorized {
                scheduleLocation = nil
            }
            startLoading()
        }
    }

    func requestLocationPermission() {
        guard !isRequestingPermission else {
            return
        }
        isRequestingPermission = true
        permissionTask?.cancel()
        permissionTask = Task { [weak self] in
            guard let self else { return }
            let status = await locationManager.requestPermission()
            guard !Task.isCancelled else { return }
            authorizationStatus = status
            isRequestingPermission = false
            if authorizationStatus.isAuthorized {
                scheduleLocation = nil
            }
            startLoading()
        }
    }

    func refresh() {
        guard scheduleTask == nil else {
            return
        }
        startLoading()
    }

    func reloadWidgets() {
        widgetReload()
    }

    func goToPreviousDay() {
        if let date = selectionCalendar.date(byAdding: .day, value: -1, to: selectedDate) {
            selectDate(date)
        }
    }

    func goToNextDay() {
        if let date = selectionCalendar.date(byAdding: .day, value: 1, to: selectedDate) {
            selectDate(date)
        }
    }

    func goToToday() {
        selectDate(now())
    }

    func selectDate(_ date: Date) {
        selectedDate = date
        isViewingToday = selectionCalendar.isDate(date, inSameDayAs: now())
        clearSchedule()
        startLoading()
    }

    // MARK: - Computed Presentation Properties

    var formattedSelectedDate: String {
        ScheduleFormatting.selectedDate(selectedDate, timeZone: selectionCalendar.timeZone)
    }

    var selectedDayRuler: String {
        guard let firstSlot = schedule?.daySlots.first else {
            return "—"
        }
        return firstSlot.type.rulingPlanet
    }

    var sunriseTimeFormatted: String {
        guard let firstSlot = schedule?.daySlots.first else {
            return "--:--"
        }
        return ScheduleFormatting.time(firstSlot.startTime, timeZone: selectionCalendar.timeZone)
    }

    var sunsetTimeFormatted: String {
        guard let lastDaySlot = schedule?.daySlots.last else {
            return "--:--"
        }
        return ScheduleFormatting.time(lastDaySlot.endTime, timeZone: selectionCalendar.timeZone)
    }

    // MARK: - Schedule Selection

    var currentSlotsForTab: [ChoghadiyaSlot] {
        guard let schedule else {
            return []
        }
        switch selectedTab {
        case .day:
            return schedule.daySlots
        case .night:
            return schedule.nightSlots
        }
    }

    var isCurrentSlotInCurrentTab: Bool {
        guard let active = activeSlot else {
            return false
        }
        return currentSlotsForTab.contains { $0.id == active.id }
    }

    // MARK: - Schedule Loading

    private func clearSchedule() {
        schedule = nil
        activeSlot = nil
        vedicDateString = ""
        timeRemainingString = "--:--"
    }

    private func startLoading() {
        scheduleTask?.cancel()
        let id = UUID()
        requestID = id
        let live = isViewingToday
        let date = selectedDate
        let civilDate = selectionCalendar.dateComponents([.year, .month, .day], from: date)
        let previousLocation = selectedCity ?? scheduleLocation
        authorizationStatus = locationManager.authorizationStatus
        state = .loading
        statusMessage = nil

        if live,
           let cached = store.load(),
           cached.schedule.currentSlot(at: now()) != nil,
           selectedCity == nil || cached.location == selectedCity
        {
            apply(cached.schedule, location: cached.location, city: cached.cityName)
            statusMessage = String(localized: "Showing saved timings while refreshing.")
        } else {
            clearSchedule()
        }

        scheduleTask = Task {
            defer {
                if requestID == id {
                    scheduleTask = nil
                }
            }
            do {
                let result: (ChoghadiyaSchedule, ScheduleLocation)
                if live {
                    result = try await loadLiveSchedule()
                } else {
                    let location: ScheduleLocation
                    if let previousLocation {
                        location = previousLocation
                    } else if locationManager.isAuthorized {
                        do {
                            location = try await resolveLocation()
                        } catch {
                            try Task.checkCancellation()
                            location = fallback
                        }
                    } else {
                        location = fallback
                    }

                    // Preserve the date selected in the user's calendar in the schedule's timezone.
                    var calendar = Calendar(identifier: .gregorian)
                    calendar.timeZone = location.timeZone
                    let target = calendar.date(from: civilDate) ?? date
                    result = try await (fetchSchedule(location: location, date: target, live: false), location)
                }

                try Task.checkCancellation()
                guard requestID == id else {
                    return
                }

                if !live {
                    var calendar = Calendar(identifier: .gregorian)
                    calendar.timeZone = result.1.timeZone
                    selectedDate = calendar.date(from: civilDate) ?? date
                }

                apply(result.0, location: result.1, city: result.1.cityName)
                state = .loaded
                statusMessage = nil
                retryAfter = now().addingTimeInterval(30)

                if live {
                    store.save(schedule: result.0, cityName: result.1.cityName, location: result.1)
                    reloadWidgets()
                }
            } catch {
                guard !Task.isCancelled, requestID == id else {
                    return
                }
                retryAfter = now().addingTimeInterval(30)
                if live, let schedule, schedule.currentSlot(at: now()) != nil {
                    state = .loaded
                    statusMessage = String(localized: "Could not refresh. Showing saved timings until this schedule expires.")
                } else {
                    clearSchedule()
                    state = .failed(message: String(localized: "Unable to load timings. Check your internet connection and try again."))
                }
            }
        }
    }

    private func loadLiveSchedule() async throws -> (ChoghadiyaSchedule, ScheduleLocation) {
        if let selectedCity {
            return try await (fetchSchedule(location: selectedCity, date: now(), live: true), selectedCity)
        }
        if locationManager.isAuthorized {
            do {
                let context = try await resolveLocation()
                return try await (fetchSchedule(location: context, date: now(), live: true), context)
            } catch {
                try Task.checkCancellation()
                // App and widget use different display names for the same fallback.
                // Missing location metadata is not enough to replace a valid cache.
                let isAlreadyFallback = scheduleLocation.map {
                    $0.latitude == fallback.latitude
                        && $0.longitude == fallback.longitude
                        && $0.timeZone == fallback.timeZone
                } ?? false
                if !isAlreadyFallback, schedule?.currentSlot(at: now()) != nil {
                    throw error
                }
            }
        }
        return try await (fetchSchedule(location: fallback, date: now(), live: true), fallback)
    }

    private func resolveLocation() async throws -> ScheduleLocation {
        let location = try await locationManager.fetchCurrentLocation(timeout: 4)
        let (city, timeZone) = await locationManager.reverseGeocodeCityAndTimeZone(for: location)
        try Task.checkCancellation()
        return ScheduleLocation(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            timeZone: timeZone,
            cityName: city
        )
    }

    private func fetchSchedule(location: ScheduleLocation, date: Date, live: Bool) async throws -> ChoghadiyaSchedule {
        let schedule = try await choghadiyaManager.getSchedule(
            latitude: location.latitude,
            longitude: location.longitude,
            timeZone: location.timeZone,
            date: date
        )
        try Task.checkCancellation()

        if live, let sunrise = schedule.daySlots.first?.startTime, date < sunrise {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = location.timeZone
            guard let previous = calendar.date(byAdding: .day, value: -1, to: date) else {
                return schedule
            }
            return try await choghadiyaManager.getSchedule(
                latitude: location.latitude,
                longitude: location.longitude,
                timeZone: location.timeZone,
                date: previous
            )
        }
        return schedule
    }

    private func apply(_ value: ChoghadiyaSchedule, location: ScheduleLocation?, city: String) {
        schedule = value
        scheduleLocation = location
        lastScheduleTimeZone = value.timeZone
        cityName = city
        currentPhaseIsDay = nil
        updatePresentation()
    }

    // MARK: - Clock and Lifecycle

    func tick() {
        let date = now()
        if isViewingToday {
            if !selectionCalendar.isDate(selectedDate, inSameDayAs: date) {
                selectedDate = date
            }
        } else if selectionCalendar.isDate(selectedDate, inSameDayAs: date) {
            selectDate(date)
        }
        updatePresentation()
        if isViewingToday,
           scheduleTask == nil,
           date >= retryAfter,
           schedule?.currentSlot(at: date) == nil
        {
            refresh()
        }
    }

    private func updatePresentation() {
        let date = now()
        activeSlot = isViewingToday ? schedule?.currentSlot(at: date) : nil
        if let schedule, let first = schedule.daySlots.first {
            vedicDateString = ScheduleFormatting.vedicDate(first.startTime, timeZone: schedule.timeZone)
            if isViewingToday {
                let isDay = schedule.isDaytime(at: date)
                vedicDateString = isDay
                    ? String(localized: "\(vedicDateString) • Day")
                    : String(localized: "\(vedicDateString) • Night")
                if currentPhaseIsDay != isDay {
                    currentPhaseIsDay = isDay
                    selectedTab = isDay ? .day : .night
                }
            }
        }
        guard let slot = activeSlot else {
            timeRemainingString = "--:--"
            return
        }
        let seconds = max(0, Int(slot.endTime.timeIntervalSince(date)))
        timeRemainingString = seconds >= 3600
            ? String(format: "%02d:%02d:%02d", seconds / 3600, seconds % 3600 / 60, seconds % 60)
            : String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}
