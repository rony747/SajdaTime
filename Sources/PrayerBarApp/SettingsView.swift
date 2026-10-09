import SwiftUI
import PrayerCore

/// Settings sections, shown in the sidebar.
enum SettingsSection: String, CaseIterable, Identifiable {
    case general
    case prayerTimes
    case notifications
    case location
    case appearance
    case menubar
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "General"
        case .prayerTimes: return "Prayer Times"
        case .notifications: return "Notifications"
        case .location: return "Location"
        case .appearance: return "Appearance"
        case .menubar: return "Menubar"
        case .about: return "About"
        }
    }

    var symbol: String {
        switch self {
        case .general: return "gearshape.fill"
        case .prayerTimes: return "clock.fill"
        case .notifications: return "bell.fill"
        case .location: return "mappin.circle.fill"
        case .appearance: return "paintpalette.fill"
        case .menubar: return "menubar.rectangle"
        case .about: return "info.circle.fill"
        }
    }

    /// Heading shown above the cards.
    var heading: String {
        switch self {
        case .general: return "General"
        case .prayerTimes: return "Prayer Times"
        case .notifications: return "Notifications"
        case .location: return "Location"
        case .appearance: return "Appearance"
        case .menubar: return "Menubar"
        case .about: return "About"
        }
    }

    var subheading: String {
        switch self {
        case .general: return "Configure how PrayerBar works on your Mac."
        case .prayerTimes: return "How the times are calculated and from which source."
        case .notifications: return "When PrayerBar alerts you, for each prayer."
        case .location: return "Where you are, and which clock times are shown on."
        case .appearance: return "Clock format and what the panel displays."
        case .menubar: return "What the menu bar item shows."
        case .about: return "Version and where the times come from."
        }
    }
}

struct SettingsView: View {
    @ObservedObject var state: AppState
    @State private var section: SettingsSection

    init(state: AppState) {
        self.state = state
        _section = State(initialValue: state.requestedSettingsSection)
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            detail
        }
        .frame(width: 880, height: 640)
        .background(Color(nsColor: .windowBackgroundColor))
        .onChange(of: state.requestedSettingsSection) { _, newValue in
            section = newValue
        }
        .onAppear {
            section = state.requestedSettingsSection
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 11) {
                AppMark(size: 46)
                VStack(alignment: .leading, spacing: 0) {
                    Text("PrayerBar")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                    Text("Your daily prayer companion")
                        .font(.system(size: 10.5, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.top, 18)
            .padding(.bottom, 16)

            VStack(spacing: 3) {
                ForEach(SettingsSection.allCases) { item in
                    sidebarRow(item)
                }
            }
            .padding(.horizontal, 10)

            Spacer(minLength: 0)
        }
        .frame(width: 214)
        .background(Color.primary.opacity(0.025))
    }

    private func sidebarRow(_ item: SettingsSection) -> some View {
        let selected = item == section
        return Button {
            section = item
            state.requestedSettingsSection = item
        } label: {
            HStack(spacing: 10) {
                Image(systemName: item.symbol)
                    .font(.system(size: 13))
                    .frame(width: 20)
                    .foregroundStyle(selected ? Palette.greenDeep : Color.secondary)
                Text(item.title)
                    .font(.system(size: 13, weight: selected ? .semibold : .regular))
                    .foregroundStyle(selected ? Palette.greenDeep : Color.primary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(selected ? Palette.greenSoft : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Detail

    private var detail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(section.heading)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                    Text(section.subheading)
                        .font(.system(size: 12.5, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 2)

                switch section {
                case .general: GeneralSection(state: state, goTo: { section = $0 })
                case .prayerTimes: PrayerTimesSection(state: state)
                case .notifications: NotificationsSection(state: state)
                case .location: LocationSection(state: state)
                case .appearance: AppearanceSection(state: state)
                case .menubar: MenubarSection(state: state)
                case .about: AboutSection(state: state)
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Binding helpers

extension AppState {
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
