import SwiftUI

// MARK: - City Picker Sheet

/// Modal sheet allowing the user to search and select a geographic city or revert to device location.
struct CityPickerSheet: View {
    // MARK: - Dependencies & Callbacks

    let onSelect: (ScheduleLocation?) -> Void

    // MARK: - Environment & State

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results = ScheduleLocation.suggestions
    @State private var isSearching = false
    @State private var error: String?
    @State private var searchTask: Task<Void, Never>?

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            headerView
            searchBarView

            Button {
                choose(nil)
            } label: {
                Label("Use current location", systemImage: "location.fill")
            }

            Divider()

            Text(query.isEmpty ? String(localized: "POPULAR CITIES") : String(localized: "SEARCH RESULTS"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if let error {
                Text(error)
                    .foregroundStyle(.secondary)
            }

            cityListView
        }
        .padding(24)
        .frame(width: 480, height: 490)
        .onDisappear {
            searchTask?.cancel()
            isSearching = false
        }
        .onChange(of: query) { value in
            searchTask?.cancel()
            isSearching = false
            error = nil
            if value.isEmpty {
                results = ScheduleLocation.suggestions
            }
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Choose a city")
                    .font(.title2.bold())
                Text("Timings follow the city’s local time.")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Done") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)
        }
    }

    private var searchBarView: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search city or place", text: $query)
                .textFieldStyle(.plain)
                .onSubmit {
                    search()
                }

            if isSearching {
                ProgressView()
                    .controlSize(.small)
            }

            Button("Search", action: search)
                .disabled(query.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(12)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
    }

    private var cityListView: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                ForEach(results) { city in
                    Button {
                        choose(city)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "building.2")
                                .foregroundStyle(.teal)
                                .frame(width: 26)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(city.cityName)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.primary)
                                Text(city.timeZone.identifier.replacingOccurrences(of: "_", with: " "))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Actions & Search

    private func choose(_ city: ScheduleLocation?) {
        onSelect(city)
        dismiss()
    }

    private func search() {
        searchTask?.cancel()
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            return
        }
        isSearching = true
        results = []
        error = nil
        searchTask = Task {
            defer {
                if !Task.isCancelled {
                    isSearching = false
                }
            }
            do {
                let matches = try await CitySearch.search(text)
                guard !Task.isCancelled else {
                    return
                }
                results = matches
                if matches.isEmpty {
                    error = String(localized: "No cities found. Try adding a country or region.")
                }
            } catch {
                guard !Task.isCancelled else {
                    return
                }
                self.error = String(localized: "Search is unavailable. Check your connection and try again.")
            }
        }
    }
}
