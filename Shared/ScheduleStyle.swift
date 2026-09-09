import ChoghadiyaKit
import SwiftUI

// MARK: - Schedule Style

/// Keeps slot colors and symbols consistent between the app and widget.
enum ScheduleStyle {
    // MARK: - Color Mapping

    static func color(_ type: ChoghadiyaType) -> Color {
        switch type {
        case .amrit, .shubh:
            .teal
        case .labh:
            .blue
        case .chal:
            .indigo
        case .udveg:
            .orange
        case .rog:
            .red
        case .kaal:
            .purple
        }
    }

    // MARK: - Icon Mapping

    static func icon(_ type: ChoghadiyaType) -> String {
        switch type {
        case .amrit:
            "sparkles"
        case .shubh:
            "star.fill"
        case .labh:
            "arrow.up.right"
        case .chal:
            "wind"
        case .udveg:
            "exclamationmark"
        case .rog:
            "cross.fill"
        case .kaal:
            "clock"
        }
    }
}
