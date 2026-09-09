import AppKit
import ChoghadiyaKit
@testable import ChoghadiyaMacApp
import SwiftUI
import XCTest

@MainActor
final class WidgetRenderingTests: XCTestCase {
    func testWidgetLayoutsRenderInBothAppearances() async throws {
        guard #available(macOS 13.0, *) else { throw XCTSkip("ImageRenderer needs macOS 13") }
        let date = Date()
        let manager = ChoghadiyaManager(fetcher: StubSunTimesFetcher())
        let schedule = try await manager.getSchedule(latitude: 21, longitude: 72, timeZone: .current, date: date)
        let slot = ChoghadiyaSlot(type: .shubh, startTime: date.addingTimeInterval(-1800), endTime: date.addingTimeInterval(3600))
        for appearance in [ColorScheme.light, .dark] {
            for isPlan in [false, true] {
                let entry = SimpleEntry(date: date, slot: slot, city: "Ahmedabad, India", schedule: schedule, selectedDate: isPlan ? date : nil)
                let label = "\(appearance == .light ? "light" : "dark")-\(isPlan ? "date" : "live")"
                try render(SmallWidgetView(entry: entry), size: CGSize(width: 170, height: 170), appearance: appearance, name: "small-\(label)")
                try render(MediumWidgetView(entry: entry), size: CGSize(width: 360, height: 170), appearance: appearance, name: "medium-\(label)")
            }
        }
    }

    @available(macOS 13.0, *)
    private func render(_ view: some View, size: CGSize, appearance: ColorScheme, name: String) throws {
        let content = view.padding(16).frame(width: size.width, height: size.height)
            .background(appearance == .light ? Color.white : Color(red: 0.10, green: 0.12, blue: 0.13))
            .environment(\.colorScheme, appearance)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        let image = try XCTUnwrap(renderer.nsImage)
        let data = try XCTUnwrap(image.tiffRepresentation)
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: data))
        let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        try png.write(to: URL(fileURLWithPath: "/private/tmp/choghadiya-widget-\(name).png"))
    }
}
