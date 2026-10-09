import SwiftUI
import SajdaCore

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
        case .general: return "Configure how Sajda Time works on your Mac."
        case .prayerTimes: return "How the times are calculated and from which source."
        case .notifications: return "When Sajda Time alerts you, for each prayer."
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
    @Environment(\.colorScheme) private var scheme

    init(state: AppState) {
        self.state = state
        _section = State(initialValue: state.requestedSettingsSection)
    }

    var body: some View {
        SettingsChrome(state: state, section: section, onSelect: { section = $0 })
        .frame(width: 880, height: 640)
        // The window is a full-size content view, so SwiftUI insets the top by
        // the titlebar height on top of our own padding, which left a large gap
        // above the heading. The sidebar carries its own clearance instead.
        .ignoresSafeArea(.container, edges: .top)
        // Glass alone let the desktop through far too strongly, which hurt
        // contrast in dark mode. The scrim is deliberately asymmetric: dark mode
        // needs a firm base for light text, while light mode needs very little or
        // the window turns into a solid white sheet and the glass disappears.
        .background(Color(nsColor: .windowBackgroundColor).opacity(scheme == .dark ? 0.58 : 0.20))
        .onChange(of: state.requestedSettingsSection) { _, newValue in
            section = newValue
        }
        .onAppear {
            section = state.requestedSettingsSection
            NSApp.activate(ignoringOtherApps: true)
        }
    }

}

/// Sidebar and detail together.
///
/// `scrolls` exists so the whole window can also be rendered offscreen for
/// inspection: `ScrollView` is AppKit-backed and produces a blank image.
struct SettingsChrome: View {
    @ObservedObject var state: AppState
    let section: SettingsSection
    let onSelect: (SettingsSection) -> Void
    var scrolls: Bool = true

    var body: some View {
        HStack(spacing: 0) {
            SettingsSidebar(state: state, section: section, onSelect: onSelect)
            Divider()
            if scrolls {
                ScrollView { SettingsDetailContent(state: state, section: section, goTo: onSelect) }
            } else {
                SettingsDetailContent(state: state, section: section, goTo: onSelect)
            }
        }
    }
}

struct SettingsSidebar: View {
    @ObservedObject var state: AppState
    let section: SettingsSection
    let onSelect: (SettingsSection) -> Void

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            BrandLogo(width: 178)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
            .padding(.horizontal, 14)
            // Clears the window's traffic lights, which now overlay the content.
            .padding(.top, 40)
            .padding(.bottom, 14)

            VStack(spacing: 3) {
                ForEach(SettingsSection.allCases) { item in
                    sidebarRow(item)
                }
            }
            .padding(.horizontal, 10)

            Spacer(minLength: 0)
        }
        .frame(width: 214)
        .background(Color.primary.opacity(0.04))
    }

    private func sidebarRow(_ item: SettingsSection) -> some View {
        let selected = item == section
        return Button {
            onSelect(item)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: item.symbol)
                    .font(.system(size: 13))
                    .frame(width: 20)
                    .foregroundStyle(selected ? Palette.accentText(scheme) : Color.secondary)
                Text(item.title)
                    .font(.system(size: 13, weight: selected ? .semibold : .regular))
                    .foregroundStyle(selected ? Palette.accentText(scheme) : Color.primary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(selected ? Palette.selectionFill(scheme) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

}

struct SettingsDetailContent: View {
    @ObservedObject var state: AppState
    let section: SettingsSection
    let goTo: (SettingsSection) -> Void

    var body: some View {
        // One container for the page of glass cards — the documented way to
        // render several effects at once. The container spacing is deliberately
        // *below* the 14pt spacing between cards: a larger value makes separate
        // effects blend into one shape at rest, which would merge the cards.
        GlassEffectContainer(spacing: 8) {
            content
        }
    }

    private var content: some View {
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
            case .general: GeneralSection(state: state, goTo: goTo)
            case .prayerTimes: PrayerTimesSection(state: state)
            case .notifications: NotificationsSection(state: state)
            case .location: LocationSection(state: state)
            case .appearance: AppearanceSection(state: state)
            case .menubar: MenubarSection(state: state)
            case .about: AboutSection(state: state)
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 30)
        .padding(.bottom, 22)
        .frame(maxWidth: .infinity, alignment: .leading)
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
