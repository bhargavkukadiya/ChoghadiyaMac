import SwiftUI
import WidgetKit

extension View {
    @ViewBuilder
    func widgetBackground(_ backgroundView: some View) -> some View {
        if #available(macOS 14.0, *) {
            containerBackground(for: .widget) { backgroundView }
        } else {
            padding(12).background(backgroundView)
        }
    }
}
