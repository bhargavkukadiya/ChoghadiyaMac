import ChoghadiyaKit
import Foundation
import WidgetKit

// MARK: - Timeline Entry

/// Represents a single timeline snapshot for the Choghadiya widget.
struct SimpleEntry: TimelineEntry {
    let date: Date
    let slot: ChoghadiyaSlot?
    let city: String
    let schedule: ChoghadiyaSchedule?
    let selectedDate: Date?
    let location: ScheduleLocation?

    init(
        date: Date = Date(),
        slot: ChoghadiyaSlot?,
        city: String,
        schedule: ChoghadiyaSchedule? = nil,
        selectedDate: Date? = nil,
        location: ScheduleLocation? = nil
    ) {
        self.date = date
        self.slot = slot
        self.city = city
        self.schedule = schedule
        self.selectedDate = selectedDate
        self.location = location
    }
}
