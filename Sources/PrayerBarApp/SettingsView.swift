import SwiftUI
import PrayerCore

enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case location
    case calculation
    case notifications
    case focusMode

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "General"
        case .location: return "Location & Time"
        case .calculation: return "Calculation"
        case .notifications: return "Notifications"
        case .focusMode: return "Focus Mode"
        }
    }

    var symbol: String {
        switch self {
        case .general: return "gearshape"
        case .location: return "location.north.line"
        case .calculation: return "clock"
        case .notifications: return "bell"
        case .focusMode: return "eye.slash"
        }
    }
}

/// Settings window, laid out as a custom tab strip over a scrolling body to
/// match the reference app's appearance.
struct SettingsView: View {
    @ObservedObject var state: AppState
    @State private var tab: SettingsTab = .general

    var body: some View {
        VStack(spacing: 0) {
            tabStrip
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    switch tab {
                    case .general: GeneralSettingsTab(state: state)
                    case .location: LocationSettingsTab(state: state)
                    case .calculation: CalculationSettingsTab(state: state)
                    case .notifications: NotificationSettingsTab(state: state)
                    case .focusMode: FocusModeSettingsTab(state: state)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(width: 580, height: 640)
        .onAppear {
            // An accessory (menu bar) app has to be brought forward explicitly
            // for its settings window to become usable.
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private var tabStrip: some View {
        HStack(spacing: 4) {
            ForEach(SettingsTab.allCases) { item in
                let isSelected = item == tab
                Button {
                    tab = item
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: item.symbol)
                            .font(.system(size: 18, weight: .regular))
                        Text(item.title)
                            .font(.system(size: 11))
                            .lineLimit(1)
                    }
                    .foregroundStyle(isSelected ? Theme.accent : Color.secondary)
                    .frame(width: 104, height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(isSelected ? Color.primary.opacity(0.06) : Color.clear)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Shared binding helpers

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
}
