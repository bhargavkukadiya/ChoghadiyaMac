import ChoghadiyaKit
import SwiftUI

// MARK: - Slot Row View

/// Individual table row presenting a single Choghadiya slot, its auspiciousness tier, and time boundaries.
struct SlotRowView: View {
    // MARK: - Properties

    let slot: ChoghadiyaSlot
    let isCurrent: Bool
    var timeZone: TimeZone = .current

    // MARK: - Body

    var body: some View {
        HStack(spacing: 12) {
            slotIconView
            slotDetailsView
            Spacer(minLength: 12)
            slotTimingView
        }
        .padding(16)
        .background(isCurrent ? Color.teal.opacity(0.07) : Color.clear)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Subviews

    private var slotIconView: some View {
        Image(systemName: ScheduleStyle.icon(slot.type))
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(ScheduleStyle.color(slot.type))
            .frame(width: 34, height: 34)
            .background(ScheduleStyle.color(slot.type).opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
    }

    private var slotDetailsView: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(slot.type.rawValue)
                    .font(.headline)
                if isCurrent {
                    Text("NOW")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.teal)
                }
            }
            Text(slot.type.rulingPlanet)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var slotTimingView: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text("\(time(slot.startTime)) – \(time(slot.endTime))")
                .font(.system(.callout, design: .monospaced))
            Text(slot.type.auspiciousness.rawValue.capitalized)
                .font(.caption)
                .foregroundStyle(ScheduleStyle.color(slot.type))
        }
    }

    // MARK: - Helpers

    private func time(_ date: Date) -> String {
        ScheduleFormatting.time(date, timeZone: timeZone)
    }
}
