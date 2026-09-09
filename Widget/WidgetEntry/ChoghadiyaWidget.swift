import SwiftUI
import WidgetKit

// MARK: - Widget Bundle

/// Root WidgetKit bundle dispatching either configurable (macOS 14+) or static legacy widgets.
@main
struct ChoghadiyaWidgets: WidgetBundle {
    var body: some Widget {
        availableWidget()
    }

    private func availableWidget() -> some Widget {
        if #available(macOS 14.0, *) {
            return ConfigurableChoghadiyaWidget()
        } else {
            return LegacyChoghadiyaWidget()
        }
    }
}

// MARK: - Configurable Widget (macOS 14+)

@available(macOS 14.0, *)
struct ConfigurableChoghadiyaWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "ChoghadiyaWidget", intent: ScheduleWidgetIntent.self, provider: ConfigurableScheduleProvider()) { entry in
            ChoghadiyaWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Choghadiya")
        .description("Your city. Your day. Choose a city and date in Edit Widget.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct LegacyChoghadiyaWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ChoghadiyaWidget", provider: ChoghadiyaTimelineProvider()) { entry in
            ChoghadiyaWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Choghadiya")
        .description("Live timings for the city selected in the app.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
