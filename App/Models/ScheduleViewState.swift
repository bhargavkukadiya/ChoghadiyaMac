import Foundation

// MARK: - View State & Models

/// Segmented tab selection representing diurnal (daytime) and nocturnal (nighttime) Choghadiya divisions.
enum DayNightTab: String, CaseIterable, Identifiable {
    case day = "Day Choghadiya"
    case night = "Night Choghadiya"

    var id: String {
        rawValue
    }

    var icon: String {
        switch self {
        case .day: "sun.max.fill"
        case .night: "moon.stars.fill"
        }
    }
}

/// Represents the loading and presentation lifecycle states of the schedule view model.
enum ScheduleViewState: Equatable {
    case idle
    case loading
    case loaded
    case failed(message: String)
}
