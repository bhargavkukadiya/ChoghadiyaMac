import ChoghadiyaKit
import SwiftUI

// MARK: - Content View

/// Primary dashboard view displaying the astronomical Choghadiya schedule, active slot card, sidebar date navigation, and location selector.
struct ContentView: View {
    // MARK: - Environment & State

    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel = ContentViewModel()
    @State private var showingCities = false

    // MARK: - Body

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    heading
                    notices
                    if let slot = viewModel.activeSlot {
                        ActiveSlotHeroCard(
                            slot: slot,
                            timeRemainingFormatted: viewModel.timeRemainingString,
                            timeZone: viewModel.selectionCalendar.timeZone
                        )
                    } else if viewModel.schedule != nil {
                        SelectedDateSummaryCard(
                            dateTitle: viewModel.formattedSelectedDate,
                            dayRuler: viewModel.selectedDayRuler,
                            sunriseTime: viewModel.sunriseTimeFormatted,
                            sunsetTime: viewModel.sunsetTimeFormatted,
                            onReturnToToday: viewModel.goToToday
                        )
                    }
                    if viewModel.schedule != nil {
                        scheduleSection
                    } else if viewModel.state == .loading {
                        ProgressView("Finding your timings…")
                            .frame(maxWidth: .infinity, minHeight: 240)
                    }
                }
                .padding(28)
                .frame(maxWidth: 1050)
                .frame(maxWidth: .infinity)
            }
        }
        .frame(minWidth: 880, minHeight: 660)
        .tint(.teal)
        .navigationTitle("Choghadiya")
        .toolbar {
            toolbarContent
        }
        .sheet(isPresented: $showingCities) {
            CityPickerSheet(onSelect: viewModel.selectCity)
        }
        .onAppear {
            viewModel.onAppear()
        }
        .onOpenURL { url in
            viewModel.openSchedule(url)
        }
        .onChangeCompat(of: scenePhase) { phase in
            if phase == .active {
                viewModel.onBecomeActive()
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup {
            Button {
                showingCities = true
            } label: {
                Label("Change city", systemImage: "building.2.crop.circle")
            }
            .help("Change city (⌘L)")
            .keyboardShortcut("l", modifiers: .command)

            Button(action: viewModel.refresh) {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .help("Refresh timings (⌘R)")
            .keyboardShortcut("r", modifiers: .command)
            .disabled(viewModel.state == .loading)

            Menu {
                Button("Refresh widgets", action: viewModel.reloadWidgets)
                Button("Go to today", action: viewModel.goToToday)
                    .keyboardShortcut("t", modifiers: .command)
            } label: {
                Label("More", systemImage: "ellipsis.circle")
            }
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 22) {
            Label {
                Text("Your almanac")
            } icon: {
                Image("BrandMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .accessibilityHidden(true)
            }
            .font(.headline)
            .foregroundStyle(.teal)
            .padding(.top, 8)

            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "LOCATION"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Button {
                    showingCities = true
                } label: {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: viewModel.selectedCity == nil ? "location.fill" : "building.2.fill")
                            .foregroundStyle(.teal)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(viewModel.selectedCity?.cityName ?? viewModel.cityName)
                                .fontWeight(.semibold)
                                .multilineTextAlignment(.leading)
                            Text("Change city")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                    }
                    .padding(12)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(String(localized: "DATE"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Today", action: viewModel.goToToday)
                        .buttonStyle(.borderless)
                }

                DatePicker(
                    "Choose date",
                    selection: Binding(get: { viewModel.selectedDate }, set: viewModel.selectDate),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .labelsHidden()
                .environment(\.timeZone, viewModel.selectionCalendar.timeZone)
                .environment(\.calendar, viewModel.selectionCalendar)

                HStack {
                    Button(action: viewModel.goToPreviousDay) {
                        Label("Previous", systemImage: "chevron.left")
                    }
                    .help("Previous day")

                    Spacer()

                    Button(action: viewModel.goToNextDay) {
                        Label("Next", systemImage: "chevron.right")
                    }
                    .help("Next day")
                }
                .controlSize(.small)
            }

            Spacer()

            VStack(alignment: .leading, spacing: 7) {
                Label("Local solar time", systemImage: "globe.asia.australia")
                    .font(.caption.weight(.medium))
                Text(viewModel.selectionCalendar.timeZone.identifier.replacingOccurrences(of: "_", with: " "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("A new Vedic day begins at sunrise.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(20)
        .frame(width: 238)
        .frame(maxHeight: .infinity)
        .background(.ultraThinMaterial)
    }

    // MARK: - Heading

    private var heading: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(viewModel.isViewingToday ? String(localized: "Today’s timings") : String(localized: "Explore a day"))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                Spacer()
                if viewModel.state == .loading {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            Text(viewModel.formattedSelectedDate)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if viewModel.schedule != nil {
                HStack(spacing: 20) {
                    Label(viewModel.sunriseTimeFormatted, systemImage: "sunrise")
                    Label(viewModel.sunsetTimeFormatted, systemImage: "sunset")
                    Spacer()
                    Link("Solar data by Sunrise-Sunset.org", destination: URL(string: "https://sunrise-sunset.org")!)
                        .font(.caption)
                        .foregroundStyle(.teal)
                }
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
            }
        }
    }

    // MARK: - Notices

    @ViewBuilder
    private var notices: some View {
        if viewModel.isLocationDenied {
            LocationBannerView()
        }
        if viewModel.needsLocationPermission {
            HStack {
                Label("Use your location or choose a city.", systemImage: "location.circle")
                Spacer()
                Button("Enable Location", action: viewModel.requestLocationPermission)
                    .disabled(viewModel.isRequestingPermission)
            }
            .font(.callout)
            .padding(12)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
        }
        if let message = viewModel.statusMessage {
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        if case let .failed(message) = viewModel.state {
            VStack(spacing: 12) {
                Image(systemName: "wifi.exclamationmark")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("Timings unavailable")
                    .font(.headline)
                Text(message)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Try again", action: viewModel.refresh)
            }
            .padding(28)
            .frame(maxWidth: .infinity)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Schedule Section

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Daily schedule")
                    .font(.title3.bold())
                Spacer()
                Picker("Period", selection: $viewModel.selectedTab) {
                    Label {
                        Text("Day")
                    } icon: {
                        Image("DayIcon").resizable().scaledToFit().frame(width: 16, height: 16)
                    }.tag(DayNightTab.day)
                    Label {
                        Text("Night")
                    } icon: {
                        Image("NightIcon").resizable().scaledToFit().frame(width: 16, height: 16)
                    }.tag(DayNightTab.night)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 190)
            }

            VStack(spacing: 0) {
                ForEach(viewModel.currentSlotsForTab) { slot in
                    SlotRowView(
                        slot: slot,
                        isCurrent: viewModel.activeSlot?.id == slot.id,
                        timeZone: viewModel.selectionCalendar.timeZone
                    )
                    if slot.id != viewModel.currentSlotsForTab.last?.id {
                        Divider().padding(.horizontal, 16)
                    }
                }
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))

            Text("\(viewModel.vedicDateString) · All times are local to the selected city.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Compatibility Helpers

private extension View {
    /// Backward-compatible wrapper that uses the new two-parameter `onChange` on macOS 14+
    /// and falls back to the deprecated single-parameter variant on macOS 12–13.
    @ViewBuilder
    func onChangeCompat<V: Equatable>(of value: V, perform action: @escaping (V) -> Void) -> some View {
        if #available(macOS 14.0, *) {
            onChange(of: value) { _, newValue in
                action(newValue)
            }
        } else {
            onChange(of: value, perform: action)
        }
    }
}
