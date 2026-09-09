import ChoghadiyaKit
import SwiftUI
import WidgetKit

struct SmallWidgetView: View {
    let entry: SimpleEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(entry.city, systemImage: "location.fill").font(.caption2.weight(.medium))
                .foregroundStyle(.secondary).lineLimit(1)
            if let date = entry.selectedDate {
                Text(date, format: .dateTime.month(.abbreviated).day()).font(.title2.bold())
                    .environment(\.timeZone, entry.schedule?.timeZone ?? .current)
                Text("DAY OVERVIEW").font(.system(size: 8, weight: .semibold)).foregroundStyle(.secondary)
                Spacer(minLength: 0)
                if let schedule = entry.schedule, let first = schedule.daySlots.first, let last = schedule.daySlots.last {
                    Label(time(first.startTime), systemImage: "sunrise")
                    Label(time(last.endTime), systemImage: "sunset")
                }
            } else if let slot = entry.slot {
                Spacer(minLength: 0)
                HStack {
                    Text(slot.type.rawValue).font(.system(size: 26, weight: .bold, design: .rounded)).minimumScaleFactor(0.8)
                    Spacer(minLength: 0)
                    Image(systemName: ScheduleStyle.icon(slot.type)).foregroundStyle(ScheduleStyle.color(slot.type))
                }
                Text(slot.type.auspiciousness.rawValue.capitalized).font(.caption2).foregroundStyle(.secondary)
                Spacer(minLength: 0)
                HStack(spacing: 4) {
                    Image(systemName: "timer")
                    Text(slot.endTime, style: .timer).monospacedDigit()
                    Text("left").foregroundStyle(.secondary)
                }.font(.caption.weight(.medium)).foregroundStyle(ScheduleStyle.color(slot.type))
            }
        }.font(.caption).padding(4)
    }

    // MARK: - Formatting

    private func time(_ date: Date) -> String {
        ScheduleFormatting.time(date, timeZone: entry.schedule?.timeZone ?? entry.location?.timeZone ?? .current)
    }
}
