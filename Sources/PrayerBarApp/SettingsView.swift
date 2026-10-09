import SwiftUI
import PrayerCore

/// Settings sections, shown in a sidebar.
///
/// Intentionally not a horizontal strip of tabs across the top: a source list is
/// the native macOS shape for preferences and reads very differently.
enum SettingsSection: String, CaseIterable, Identifiable {
    case overview
    case location
    case calculation
    case reminders
    case focus

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: return "Overview"
        case .location: return "Place & Time"
        case .calculation: return "Method"
        case .reminders: return "Reminders"
        case .focus: return "Focus"
        }
    }

    var symbol: String {
        switch self {
        case .overview: return "sparkles"
        case .location: return "globe.americas.fill"
        case .calculation: return "function"
        case .reminders: return "bell.badge.fill"
        case .focus: return "moon.haze.fill"
        }
    }

    var blurb: String {
        switch self {
        case .overview: return "Startup, menu bar and panel behaviour."
        case .location: return "Where you are, and which clock the times are shown on."
        case .calculation: return "How the times are derived, and from which source."
        case .reminders: return "When PrayerBar alerts you, per prayer."
        case .focus: return "Cover the screen for a set period at prayer time."
        }
    }
}

struct SettingsView: View {
    @ObservedObject var state: AppState
    @State private var section: SettingsSection? = .overview

    private var active: SettingsSection { section ?? .overview }

    var body: some View {
        NavigationSplitView {
            List(SettingsSection.allCases, selection: $section) { item in
                Label(item.title, systemImage: item.symbol)
                    .tag(item)
            }
            .navigationSplitViewColumnWidth(min: 186, ideal: 200, max: 240)
        } detail: {
            VStack(alignment: .leading, spacing: 0) {
                Text(active.blurb)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 2)

                Form {
                    switch active {
                    case .overview: OverviewSection(state: state)
                    case .location: PlaceSection(state: state)
                    case .calculation: MethodSection(state: state)
                    case .reminders: ReminderSection(state: state)
                    case .focus: FocusSection(state: state)
                    }
                }
                .formStyle(.grouped)
            }
            .navigationTitle(active.title)
        }
        .tint(Palette.accent)
        .frame(width: 780, height: 580)
        .onAppear {
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}

// MARK: - Binding helpers

extension AppState {
    /// Two-way binding into a nested settings field.
    func binding<T>(_ keyPath: WritableKeyPath<AppSettings, T>) -> Binding<T> {
        Binding(
            get: { self.settings[keyPath: keyPath] },
            set: { self.settings[keyPath: keyPath] = $0 }
        )
    }

    /// Optional-integer preference surfaced as a plain Int with 0 meaning "off".
    func optionalIntBinding(_ keyPath: WritableKeyPath<AppSettings, Int?>) -> Binding<Int> {
        Binding(
            get: { self.settings[keyPath: keyPath] ?? 0 },
            set: { self.settings[keyPath: keyPath] = $0 == 0 ? nil : $0 }
        )
    }

    func reminderBinding(_ prayer: Prayer, _ keyPath: WritableKeyPath<PrayerReminderSettings, Bool>) -> Binding<Bool> {
        Binding(
            get: { self.settings.reminder(for: prayer)[keyPath: keyPath] },
            set: { value in
                var reminder = self.settings.reminder(for: prayer)
                reminder[keyPath: keyPath] = value
                self.settings.perPrayer[prayer.rawValue] = reminder
            }
        )
    }

    func reminderModeBinding(_ prayer: Prayer) -> Binding<ReminderMode> {
        Binding(
            get: { self.settings.reminder(for: prayer).mode },
            set: { value in
                var reminder = self.settings.reminder(for: prayer)
                reminder.mode = value
                self.settings.perPrayer[prayer.rawValue] = reminder
            }
        )
    }

    /// Editing a coordinate by hand makes it the user's own choice, so the
    /// "estimated from your timezone" caveat no longer applies.
    func userCoordinateBinding(_ keyPath: WritableKeyPath<AppSettings, Double>) -> Binding<Double> {
        Binding(
            get: { self.settings[keyPath: keyPath] },
            set: { value in
                self.settings[keyPath: keyPath] = value
                self.settings.locationIsEstimated = false
                self.settings.locationMode = .manual
            }
        )
    }
}
