import ChoghadiyaKit
import SwiftUI

// MARK: - Active Slot Hero Card

/// Hero banner card highlighting the currently active Choghadiya period, planetary ruler, and countdown.
struct ActiveSlotHeroCard: View {
    // MARK: - Properties

    let slot: ChoghadiyaSlot
    let timeRemainingFormatted: String
    var timeZone: TimeZone = .current

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            headerRow
            contentRow
            Divider()
                .overlay(.white.opacity(0.15))
            footerRow
        }
        .foregroundStyle(.white)
        .padding(24)
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Subviews

    private var headerRow: some View {
        HStack {
            Label("HAPPENING NOW", systemImage: "circle.fill")
                .font(.system(size: 10, weight: .semibold))
            Spacer()
            Text(slot.type.auspiciousness.rawValue.capitalized)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.white.opacity(0.12), in: Capsule())
        }
        .foregroundStyle(.white.opacity(0.85))
    }

    private var contentRow: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
                Text(slot.type.rawValue)
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                Text(slot.type.rulingPlanet)
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.75))
            }
            Spacer()
            Image(systemName: ScheduleStyle.icon(slot.type))
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(.white.opacity(0.65))
                .frame(width: 76, height: 76)
                .background(.white.opacity(0.07), in: Circle())
        }
    }

    private var footerRow: some View {
        HStack {
            Label("\(time(slot.startTime)) – \(time(slot.endTime))", systemImage: "clock")
                .font(.callout)
                .foregroundStyle(.white.opacity(0.8))
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(timeRemainingFormatted)
                    .font(.system(.title3, design: .monospaced).weight(.semibold))
                Text("remaining")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
    }

    private var cardBackground: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.10, green: 0.23, blue: 0.27),
                Color(red: 0.07, green: 0.12, blue: 0.20),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Helpers

    private func time(_ date: Date) -> String {
        ScheduleFormatting.time(date, timeZone: timeZone)
    }
}
