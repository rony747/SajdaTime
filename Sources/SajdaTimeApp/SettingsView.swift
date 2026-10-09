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
    case focus
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
        case .focus: return "Focus"
        case .about: return "About"
        }
    }

    /// Outlined throughout, at a single weight.
    ///
    /// The set used to mix the two: every row was a `.fill` glyph except
    /// Menubar, which has no filled variant (`menubar.rectangle.fill` does not
    /// exist, and the near-misses `rectangle.topthird.inset.filled` and
    /// `rectangle.inset.filled` are both hollow at 14pt). One outlined glyph
    /// among solid ones read as a mistake. Since the odd one out cannot be
    /// filled, the set is outlined instead — every symbol then carries the same
    /// stroke weight, and Menubar keeps its proper glyph. Selection is carried
    /// by the tinted pill, the weight of the label and the accent colour.
    var symbol: String {
        switch self {
        case .general: return "square.grid.2x2"
        case .prayerTimes: return "clock"
        case .notifications: return "bell"
        case .location: return "location"
        case .appearance: return "paintpalette"
        case .menubar: return "menubar.rectangle"
        case .focus: return "moon.haze"
        case .about: return "info.circle"
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
        case .focus: return "Focus"
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
        case .focus: return "Cover the screen for a set period at prayer time."
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
        // No fixed frame here. A titled window under `.fullSizeContentView` has a
        // content view as tall as the frame *including* the titlebar — 672 for a
        // 640 content rect — so pinning this to 640 left a 32pt band at the
        // bottom showing the bare backdrop, which reads as a darker strip than
        // the scrimmed content above it. Filling the window removes the band; the
        // offscreen renderer sets its own frame.
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
            HStack(spacing: 11) {
                Image(systemName: item.symbol)
                    // A touch larger and a step heavier, so the glyphs hold
                    // their own beside 13pt labels instead of looking thin.
                    .font(.system(size: 14, weight: .medium))
                    // Fixed width keeps every label on the same left edge; SF
                    // Symbols vary in width quite a lot.
                    .frame(width: 22)
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
            case .focus: FocusSection(state: state)
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
