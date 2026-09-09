import SwiftUI

// MARK: - App Entry Point

/// The main entry point for the Choghadiya for Mac application.
@main
struct ChoghadiyaApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 540, minHeight: 640)
        }
    }
}
