import ChoghadiyaKit
@testable import ChoghadiyaMacApp
import CoreLocation
import XCTest

@MainActor
final class ScheduleRegressionTests: XCTestCase {
    private func waitForLoad(_ model: ContentViewModel) async {
        for _ in 0 ..< 400 {
            if model.state != .loading {
                return
            }
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
        XCTFail("Schedule did not finish loading")
    }

    private func makeModel(_ location: MockLocationManager, _ fetcher: StubSunTimesFetcher,
                           _ clock: TestClock, _ store: MemoryScheduleStore = MemoryScheduleStore()) -> ContentViewModel
    {
        ContentViewModel(locationManager: location, choghadiyaManager: ChoghadiyaManager(fetcher: fetcher),
                         store: store, now: { clock.date }, startsTimer: false, widgetReload: {})
    }

    func testPermissionActionUsesServiceAndDenialSurvivesFallback() async {
        let location = MockLocationManager()
        let model = makeModel(location, StubSunTimesFetcher(), TestClock())
        XCTAssertTrue(model.needsLocationPermission)
        location.authorizationStatus = .denied
        model.requestLocationPermission()
        for _ in 0 ..< 400 {
            if location.requestPermissionCalled, model.state == .loaded {
                break
            }
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
        XCTAssertTrue(location.requestPermissionCalled)
        XCTAssertTrue(model.isLocationDenied)
        XCTAssertEqual(model.state, .loaded)
        XCTAssertNotNil(model.schedule)
    }

    func testFailedDateChangeClearsPreviousSchedule() async {
        let fetcher = StubSunTimesFetcher()
        let model = makeModel(MockLocationManager(), fetcher, TestClock())
        model.onAppear()
        await waitForLoad(model)
        XCTAssertNotNil(model.schedule)
        await fetcher.configure(fails: true)
        model.goToNextDay()
        XCTAssertNil(model.schedule)
        await waitForLoad(model)
        guard case .failed = model.state else { return XCTFail("Expected a visible failure") }
        XCTAssertNil(model.schedule)
        XCTAssertNil(model.activeSlot)
    }

    func testSunriseTicksDoNotCancelSlowRefresh() async throws {
        let clock = TestClock()
        let fetcher = StubSunTimesFetcher()
        let model = makeModel(MockLocationManager(), fetcher, clock)
        model.onAppear()
        await waitForLoad(model)
        clock.date = try XCTUnwrap(model.schedule?.nightSlots.last?.endTime.addingTimeInterval(1))
        await fetcher.configure(delay: 150_000_000)
        let before = await fetcher.requests
        model.tick()
        for _ in 0 ..< 4 {
            clock.date.addTimeInterval(1)
            model.tick()
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        await waitForLoad(model)
        let after = await fetcher.requests
        XCTAssertEqual(after - before, 1)
        XCTAssertEqual(model.state, .loaded)
        XCTAssertNotNil(model.activeSlot)
    }

    func testTodayTracksMidnightAndSelectedTomorrowBecomesLive() async {
        let clock = TestClock()
        let model = makeModel(MockLocationManager(), StubSunTimesFetcher(), clock)
        model.onAppear()
        await waitForLoad(model)
        clock.date.addTimeInterval(24 * 3600)
        model.tick()
        XCTAssertTrue(Calendar.current.isDate(model.selectedDate, inSameDayAs: clock.date))
        await waitForLoad(model)
        model.goToNextDay()
        await waitForLoad(model)
        XCTAssertFalse(model.isViewingToday)
        clock.date.addTimeInterval(24 * 3600)
        model.tick()
        await waitForLoad(model)
        XCTAssertTrue(model.isViewingToday)
        XCTAssertNotNil(model.activeSlot)
    }

    func testFallbackNavigationKeepsCityAndCoordinatesTogether() async {
        let location = MockLocationManager()
        location.authorizationStatus = .authorizedAlways
        location.currentLocation = CLLocation(latitude: 40, longitude: -74)
        let clock = TestClock()
        let store = MemoryScheduleStore()
        let model = makeModel(location, StubSunTimesFetcher(), clock, store)
        model.onAppear()
        await waitForLoad(model)
        XCTAssertEqual(model.cityName, "Mock City")
        clock.date.addTimeInterval(24 * 3600)
        location.currentLocation = nil
        model.tick()
        await waitForLoad(model)
        XCTAssertEqual(model.cityName, "Surat (Default)")
        XCTAssertEqual(store.payload?.location?.latitude, 21.1702)
        model.goToNextDay()
        await waitForLoad(model)
        XCTAssertEqual(model.cityName, "Surat (Default)")
        XCTAssertEqual(model.schedule?.timeZone.identifier, "Asia/Kolkata")
    }

    func testOfflineStartupUsesValidCacheAndRejectsExpiredCache() async {
        let clock = TestClock()
        let store = MemoryScheduleStore()
        let fetcher = StubSunTimesFetcher()
        let first = makeModel(MockLocationManager(), fetcher, clock, store)
        first.onAppear()
        await waitForLoad(first)
        await fetcher.configure(fails: true)
        let offline = makeModel(MockLocationManager(), fetcher, clock, store)
        offline.onAppear()
        XCTAssertNotNil(offline.activeSlot)
        await waitForLoad(offline)
        XCTAssertEqual(offline.state, .loaded)
        XCTAssertNotNil(offline.statusMessage)
        clock.date.addTimeInterval(48 * 3600)
        offline.tick()
        await waitForLoad(offline)
        XCTAssertNil(offline.schedule)
        guard case .failed = offline.state else { return XCTFail("Expired cache must not be presented") }
        let before = await fetcher.requests
        offline.tick()
        let after = await fetcher.requests
        XCTAssertEqual(before, after, "Failed automatic refresh must back off")
    }

    func testPreSunriseUsesPreviousSolarDay() async throws {
        let clock = TestClock()
        clock.date = try XCTUnwrap(Calendar.current.date(bySettingHour: 3, minute: 0, second: 0, of: clock.date))
        let location = MockLocationManager()
        location.authorizationStatus = .authorizedAlways
        location.currentLocation = CLLocation(latitude: 21, longitude: 72)
        let model = makeModel(location, StubSunTimesFetcher(), clock)
        model.onAppear()
        await waitForLoad(model)
        XCTAssertEqual(model.selectedTab, .night)
        XCTAssertNotNil(model.activeSlot)
        let previous = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: -1, to: clock.date))
        XCTAssertTrue(try Calendar.current.isDate(XCTUnwrap(model.schedule?.daySlots.first?.startTime), inSameDayAs: previous))
    }

    func testRapidDateChangesPublishOnlyLatestSchedule() async throws {
        let clock = TestClock()
        let fetcher = StubSunTimesFetcher()
        let location = MockLocationManager()
        location.authorizationStatus = .authorizedAlways
        location.currentLocation = CLLocation(latitude: 21, longitude: 72)
        let model = makeModel(location, fetcher, clock)
        model.onAppear()
        await waitForLoad(model)
        await fetcher.configure(delay: 150_000_000)
        model.goToNextDay()
        try? await Task.sleep(nanoseconds: 10_000_000)
        await fetcher.configure()
        model.goToNextDay()
        await waitForLoad(model)
        try? await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(model.state, .loaded)
        XCTAssertTrue(try Calendar.current.isDate(XCTUnwrap(model.schedule?.daySlots.first?.startTime), inSameDayAs: model.selectedDate))
    }

    func testGrantingPermissionWhileBrowsingUpdatesLocation() async {
        let location = MockLocationManager()
        let model = makeModel(location, StubSunTimesFetcher(), TestClock())
        model.goToNextDay()
        await waitForLoad(model)
        XCTAssertEqual(model.cityName, "Surat (Default)")
        location.authorizationStatus = .authorizedAlways
        location.currentLocation = CLLocation(latitude: 40, longitude: -74)
        model.requestLocationPermission()
        for _ in 0 ..< 400 {
            if model.cityName == "Mock City", model.state == .loaded {
                break
            }
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
        XCTAssertEqual(model.cityName, "Mock City")
        XCTAssertFalse(model.isViewingToday)
    }

    func testManualCityPersistsAndDoesNotRequestDeviceLocation() async throws {
        let location = MockLocationManager()
        let clock = TestClock()
        let fetcher = StubSunTimesFetcher()
        var saved: ScheduleLocation?
        let model = ContentViewModel(locationManager: location, choghadiyaManager: ChoghadiyaManager(fetcher: fetcher),
                                     store: MemoryScheduleStore(), now: { clock.date }, startsTimer: false,
                                     persistCity: { saved = $0 }, widgetReload: {})
        let city = try XCTUnwrap(ScheduleLocation.suggestions.last)
        model.selectCity(city)
        await waitForLoad(model)
        XCTAssertEqual(model.cityName, city.cityName)
        XCTAssertEqual(saved, city)
        XCTAssertEqual(model.schedule?.timeZone, city.timeZone)
        XCTAssertFalse(location.fetchCurrentLocationCalled)
        XCTAssertFalse(model.needsLocationPermission)
        model.goToNextDay()
        await waitForLoad(model)
        XCTAssertEqual(model.cityName, city.cityName)
        XCTAssertTrue(try model.selectionCalendar.isDate(XCTUnwrap(model.schedule?.daySlots.first?.startTime), inSameDayAs: model.selectedDate))
        model.selectCity(nil)
        await waitForLoad(model)
        XCTAssertNil(saved)
        XCTAssertTrue(model.needsLocationPermission)
    }

    func testCityChangeRejectsAnotherCityCacheAndDoesNotSilentlyFallback() async throws {
        let fetcher = StubSunTimesFetcher()
        let store = MemoryScheduleStore()
        let model = makeModel(MockLocationManager(), fetcher, TestClock(), store)
        model.onAppear()
        await waitForLoad(model)
        XCTAssertNotNil(store.payload)
        await fetcher.configure(fails: true)
        try model.selectCity(XCTUnwrap(ScheduleLocation.suggestions.last))
        XCTAssertNil(model.schedule)
        await waitForLoad(model)
        guard case .failed = model.state else { return XCTFail("A selected city must not silently become Surat") }
        XCTAssertNil(model.schedule)
        let latitude = await fetcher.lastLatitude
        XCTAssertEqual(latitude, ScheduleLocation.suggestions.last?.latitude)
    }

    func testDateSelectionBeforeLocationResolvesPreservesCivilDay() async throws {
        let location = MockLocationManager()
        location.authorizationStatus = .authorizedAlways
        location.currentLocation = CLLocation(latitude: 40, longitude: -74)
        // Choose a zone west of the selection calendar so retaining midnight's
        // absolute timestamp would fetch the previous civil day.
        location.timeZone = TimeZone(secondsFromGMT: -12 * 3600)!
        let model = makeModel(location, StubSunTimesFetcher(), TestClock())
        let components = DateComponents(year: 2027, month: 1, day: 9)
        let date = try XCTUnwrap(model.selectionCalendar.date(from: components))
        model.selectDate(date)
        await waitForLoad(model)
        let sunrise = try XCTUnwrap(model.schedule?.daySlots.first?.startTime)
        XCTAssertEqual(model.selectionCalendar.dateComponents([.year, .month, .day], from: sunrise), components)
        XCTAssertEqual(model.selectionCalendar.dateComponents([.year, .month, .day], from: model.selectedDate), components)
    }

    func testLegacyCacheUsesScheduleTimeZoneWithoutLocationMetadata() async throws {
        let clock = TestClock()
        let fetcher = StubSunTimesFetcher()
        let zone = TimeZone(secondsFromGMT: -12 * 3600)!
        let manager = ChoghadiyaManager(fetcher: fetcher)
        let schedule = try await manager.getSchedule(latitude: 0, longitude: 0, timeZone: zone, date: clock.date)
        clock.date = schedule.daySlots[3].startTime
        let store = MemoryScheduleStore()
        store.save(schedule: schedule, cityName: "Legacy city", location: nil)
        await fetcher.configure(fails: true)
        let model = makeModel(MockLocationManager(), fetcher, clock, store)
        model.onAppear()
        await waitForLoad(model)
        XCTAssertEqual(model.selectionCalendar.timeZone, zone)
        XCTAssertNotNil(model.activeSlot)
    }

    func testWidgetFallbackCacheRefreshesWhenDeviceLocationIsUnavailable() async throws {
        let clock = TestClock()
        let zone = try XCTUnwrap(TimeZone(identifier: "Asia/Kolkata"))
        let widgetLocation = ScheduleLocation(latitude: 21.1702, longitude: 72.8311,
                                              timeZone: zone, cityName: "Surat")
        let cached = try await ChoghadiyaManager(fetcher: StubSunTimesFetcher()).getSchedule(
            latitude: widgetLocation.latitude, longitude: widgetLocation.longitude, timeZone: zone, date: clock.date
        )
        clock.date = cached.daySlots[3].startTime
        let store = MemoryScheduleStore()
        store.save(schedule: cached, cityName: widgetLocation.cityName, location: widgetLocation)
        let location = MockLocationManager()
        location.authorizationStatus = .authorizedAlways
        let fetcher = StubSunTimesFetcher()
        let model = makeModel(location, fetcher, clock, store)

        model.onAppear()
        await waitForLoad(model)

        XCTAssertTrue(location.fetchCurrentLocationCalled)
        let requests = await fetcher.requests
        XCTAssertEqual(requests, 1, "The widget's fallback cache must allow a fresh solar request")
        XCTAssertEqual(model.state, .loaded)
        XCTAssertNil(model.statusMessage)
        XCTAssertNotNil(model.activeSlot)
        XCTAssertEqual(store.payload?.cityName, "Surat (Default)")
        XCTAssertEqual(store.payload?.location?.latitude, widgetLocation.latitude)
    }

    func testFallbackDisplayNameDoesNotOverrideDifferentOrUnknownLocation() async throws {
        let zone = try XCTUnwrap(TimeZone(identifier: "Asia/Kolkata"))
        let contexts: [ScheduleLocation?] = try [
            ScheduleLocation(latitude: 40, longitude: -74, timeZone: zone, cityName: "Surat (Default)"),
            ScheduleLocation(latitude: 21.1702, longitude: 72.8311,
                             timeZone: XCTUnwrap(TimeZone(identifier: "America/New_York")), cityName: "Surat (Default)"),
            nil,
        ]
        for context in contexts {
            let clock = TestClock()
            let cached = try await ChoghadiyaManager(fetcher: StubSunTimesFetcher()).getSchedule(
                latitude: context?.latitude ?? 40, longitude: context?.longitude ?? -74,
                timeZone: context?.timeZone ?? zone, date: clock.date
            )
            clock.date = cached.daySlots[3].startTime
            let store = MemoryScheduleStore()
            store.save(schedule: cached, cityName: "Surat (Default)", location: context)
            let original = store.payload
            let location = MockLocationManager()
            location.authorizationStatus = .authorizedAlways
            let fetcher = StubSunTimesFetcher()
            let model = makeModel(location, fetcher, clock, store)

            model.onAppear()
            await waitForLoad(model)

            let requests = await fetcher.requests
            XCTAssertEqual(requests, 0, "A display name must not authorize replacing another location's cache")
            XCTAssertEqual(model.state, .loaded)
            XCTAssertNotNil(model.statusMessage)
            XCTAssertEqual(store.payload, original)
        }
    }
}
