import ChoghadiyaKit
import SwiftUI
import WidgetKit

struct MediumWidgetView: View {
    let entry: SimpleEntry
    var body: some View {
        HStack(spacing: 16) {
            SmallWidgetView(entry: entry).frame(maxWidth: .infinity, alignment: .leading)
            Divider()
            VStack(alignment: .leading, spacing: 9) {
                Text(entry.selectedDate == nil ? String(localized: "UP NEXT") : String(localized: "DAY SCHEDULE"))
                    .font(.system(size: 9, weight: .semibold)).tracking(1).foregroundStyle(.secondary)
                if let schedule = entry.schedule {
                    let slots = entry.selectedDate == nil ? schedule.allSlots.filter { $0.startTime > entry.date } : schedule.daySlots
                    if slots.isEmpty {
                        Text("New cycle at sunrise").font(.caption).foregroundStyle(.secondary)
                    }
                    ForEach(slots.prefix(3)) { slot in
                        HStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 2).fill(ScheduleStyle.color(slot.type)).frame(width: 3, height: 25)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(slot.type.rawValue).font(.caption.weight(.semibold))
                                Text(time(slot.startTime)).font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                }
                Spacer(minLength: 0)
            }.padding(.vertical, 4).frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Formatting

    private func time(_ date: Date) -> String {
        ScheduleFormatting.time(date, timeZone: entry.schedule?.timeZone ?? entry.location?.timeZone ?? .current)
    }
}
