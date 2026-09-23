import SwiftUI
import WidgetKit

// MARK: - Widget Background Compatibility

extension View {
    /// Applies a container background on macOS 14+ or falls back to padded background on earlier versions.
    ///
    /// WidgetKit introduced `containerBackground(for:)` in macOS 14.
    /// This helper lets widget views use a single call site regardless of deployment target.
    @ViewBuilder
    func widgetBackground(_ backgroundView: some View) -> some View {
        if #available(macOS 14.0, *) {
            containerBackground(for: .widget) { backgroundView }
        } else {
            padding(12).background(backgroundView)
        }
    }
}
