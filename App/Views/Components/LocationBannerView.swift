import SwiftUI

// MARK: - Location Banner View

/// Displays guidance when location permissions are denied, with a deep link to macOS Settings.
struct LocationBannerView: View {
    // MARK: - Environment

    @Environment(\.openURL) private var openURL

    // MARK: - Body

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text("Location Access Disabled")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text("Enable location in System Settings for local timings. Saved timings or Surat may be used while location is unavailable.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Open Settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices") {
                    openURL(url)
                }
            }
            .controlSize(.small)
        }
        .padding(12)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
}
