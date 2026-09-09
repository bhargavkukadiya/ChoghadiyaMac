import SwiftUI

// MARK: - Selected Date Summary Card

/// Summary card displaying astrological overview when browsing non-live calendar dates.
struct SelectedDateSummaryCard: View {
    // MARK: - Properties

    let dateTitle: String
    let dayRuler: String
    let sunriseTime: String
    let sunsetTime: String
    let onReturnToToday: () -> Void

    // MARK: - Body

    var body: some View {
        HStack(spacing: 18) {
            Image(systemName: "calendar")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(.teal)
                .frame(width: 64, height: 64)
                .background(Color.teal.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))

            VStack(alignment: .leading, spacing: 6) {
                Text("Plan your day")
                    .font(.title2.bold())
                Text("Ruled by \(dayRuler)")
                    .foregroundStyle(.secondary)
                Text("8 daytime · 8 nighttime periods")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Back to today", action: onReturnToToday)
        }
        .padding(24)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
    }
}
