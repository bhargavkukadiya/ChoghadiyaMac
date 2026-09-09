import SwiftUI
import WidgetKit

// MARK: - Widget Entry View

/// Multi-family responsive router dispatching to SmallWidgetView or MediumWidgetView.
struct ChoghadiyaWidgetEntryView: View {
    // MARK: - Environment & Properties

    @Environment(\.widgetFamily) private var family
    let entry: SimpleEntry

    // MARK: - Body

    var body: some View {
        Group {
            if entry.slot != nil {
                if family == .systemMedium {
                    MediumWidgetView(entry: entry)
                } else {
                    SmallWidgetView(entry: entry)
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Label(entry.city, systemImage: "location").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    Spacer()
                    Image("BrandMark")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 32, height: 32)
                        .accessibilityHidden(true)
                    Text("Timings unavailable").font(.headline)
                    Text("Open the app to refresh.").font(.caption).foregroundStyle(.secondary)
                }.padding(4)
            }
        }
        .widgetURL(ScheduleLink.url(city: entry.location, date: entry.selectedDate))
        .widgetBackground(Color.teal.opacity(0.06))
    }
}
