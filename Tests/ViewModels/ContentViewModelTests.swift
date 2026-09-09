import ChoghadiyaKit
@testable import ChoghadiyaMacApp
import CoreLocation
import LocationManager
import XCTest

// MARK: - Content View Model Tests

@MainActor
final class ContentViewModelTests: XCTestCase {
    // MARK: - Tests

    func testViewModelInitialState() {
        let mockLocation = MockLocationManager()
        let viewModel = ContentViewModel(locationManager: mockLocation, choghadiyaManager: ChoghadiyaManager(fetcher: StubSunTimesFetcher()), store: MemoryScheduleStore(), startsTimer: false, widgetReload: {})

        XCTAssertEqual(viewModel.state, .idle)
        XCTAssertEqual(viewModel.selectedTab, .day)
        XCTAssertEqual(viewModel.cityName, "Detecting...")
        XCTAssertNil(viewModel.schedule)
        XCTAssertNil(viewModel.activeSlot)
    }

    func testViewModelTabSwitching() {
        let mockLocation = MockLocationManager()
        let viewModel = ContentViewModel(locationManager: mockLocation, choghadiyaManager: ChoghadiyaManager(fetcher: StubSunTimesFetcher()), store: MemoryScheduleStore(), startsTimer: false, widgetReload: {})

        XCTAssertEqual(viewModel.selectedTab, .day)
        viewModel.selectedTab = .night
        XCTAssertEqual(viewModel.selectedTab, .night)
        XCTAssertEqual(viewModel.selectedTab.icon, "moon.stars.fill")
    }

    func testViewModelRequestPermissionDelegatesToManager() async {
        let mockLocation = MockLocationManager()
        let viewModel = ContentViewModel(locationManager: mockLocation, choghadiyaManager: ChoghadiyaManager(fetcher: StubSunTimesFetcher()), store: MemoryScheduleStore(), startsTimer: false, widgetReload: {})

        viewModel.requestLocationPermission()

        // Allow cooperative Task execution
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertTrue(mockLocation.requestPermissionCalled)
    }

    func testDayNightTabCases() {
        XCTAssertEqual(DayNightTab.allCases.count, 2)
        XCTAssertEqual(DayNightTab.day.rawValue, "Day Choghadiya")
        XCTAssertEqual(DayNightTab.night.rawValue, "Night Choghadiya")
        XCTAssertEqual(DayNightTab.day.icon, "sun.max.fill")
        XCTAssertEqual(DayNightTab.night.icon, "moon.stars.fill")
    }

    func testDateNavigationNextAndPreviousDay() {
        let mockLocation = MockLocationManager()
        let viewModel = ContentViewModel(locationManager: mockLocation, choghadiyaManager: ChoghadiyaManager(fetcher: StubSunTimesFetcher()), store: MemoryScheduleStore(), startsTimer: false, widgetReload: {})

        XCTAssertTrue(viewModel.isViewingToday)

        let initialDate = viewModel.selectedDate

        // Navigate to Next Day
        viewModel.goToNextDay()
        XCTAssertFalse(viewModel.isViewingToday)
        let dayDiff = Calendar.current.dateComponents([.day], from: initialDate, to: viewModel.selectedDate).day
        XCTAssertEqual(dayDiff, 1)

        // Navigate to Previous Day
        viewModel.goToPreviousDay()
        XCTAssertTrue(viewModel.isViewingToday)
        XCTAssertTrue(Calendar.current.isDate(viewModel.selectedDate, inSameDayAs: initialDate))
    }

    func testDateNavigationTodayReset() {
        let mockLocation = MockLocationManager()
        let viewModel = ContentViewModel(locationManager: mockLocation, choghadiyaManager: ChoghadiyaManager(fetcher: StubSunTimesFetcher()), store: MemoryScheduleStore(), startsTimer: false, widgetReload: {})

        // Advance 5 days into future
        viewModel.goToNextDay()
        viewModel.goToNextDay()
        viewModel.goToNextDay()
        XCTAssertFalse(viewModel.isViewingToday)

        // Reset to Today
        viewModel.goToToday()
        XCTAssertTrue(viewModel.isViewingToday)
        XCTAssertTrue(Calendar.current.isDateInToday(viewModel.selectedDate))
    }
}
