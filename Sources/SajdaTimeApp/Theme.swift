import SwiftUI
import SajdaCore

// MARK: - Palette

enum Palette {
    /// Primary green used for selection, toggles and the app mark.
    static let green = Color(red: 0.16, green: 0.62, blue: 0.34)
    /// Mid-green, kept for the app mark's gradient and for shadows.
    static let greenDeep = Color(red: 0.09, green: 0.45, blue: 0.24)
    static let greenSoft = Color(red: 0.87, green: 0.96, blue: 0.90)

    /// Display ink: a deep emerald, dark enough to read as near-black at a
    /// glance while still clearly green. Used for every piece of text that sits
    /// on the pale banner or the reminder, so it stays consistent across both.
    static let greenInk = Color(red: 0.043, green: 0.243, blue: 0.176)
    /// One step deeper, for the foot of the display gradient.
    static let greenInkDeep = Color(red: 0.024, green: 0.176, blue: 0.125)

    /// Vertical gradient for large display type; a flat fill looks thin at
    /// heading sizes.
    static var inkGradient: LinearGradient {
        LinearGradient(
            colors: [greenInk, greenInkDeep],
            startPoint: .top, endPoint: .bottom
        )
    }

    // MARK: - The reminder card
    //
    // Deep emerald, brass and ivory, from the supplied design. Kept apart from
    // the greens above: these are for the full-screen reminder only, and the app
    // surfaces stay on the lighter palette.

    /// Card body. Slightly transparent so the photograph reads through it.
    static let emeraldCard = Color(red: 0.078, green: 0.220, blue: 0.173)
    /// Inset fills inside the card: the time chip and the hadith panel.
    static let emeraldInset = Color(red: 0.035, green: 0.141, blue: 0.110)
    /// The Dismiss fill, a step brighter so the primary action separates.
    static let emeraldAction = Color(red: 0.106, green: 0.361, blue: 0.255)
    /// Brass, for rules, borders and the ornamental work.
    static let gold = Color(red: 0.796, green: 0.663, blue: 0.416)
    /// Warm ivory for every piece of text on the emerald card.
    static let cream = Color(red: 0.957, green: 0.922, blue: 0.839)

    /// The app's interactive accent. Brass rather than green, so selections and
    /// toggles read as the same material as the reminder's ornament.
    static let accent = gold
    /// Fill behind a selected row or pill on a light surface.
    static let accentSoft = Color(red: 0.976, green: 0.941, blue: 0.859)
    /// Muted ivory for the secondary lines on an emerald card.
    static let creamMuted = Color(red: 0.957, green: 0.922, blue: 0.839).opacity(0.72)

    /// Warm tone for the sun-related prayers.
    static let amber = Color(red: 0.97, green: 0.65, blue: 0.20)
    /// Cool tone for the night prayer.
    static let night = Color(red: 0.28, green: 0.33, blue: 0.47)

    static let cardCorner: CGFloat = 16

    /// Icon tint for a prayer: sun prayers are warm, Isha is cool. The row that
    /// is currently in its time overrides this with green.
    static func tint(for prayer: Prayer) -> Color {
        switch prayer {
        case .isha: return night
        default: return amber
        }
    }

    /// Readable green for text sitting on a surface that follows the scheme.
    ///
    /// `greenDeep` is correct on the pale banner, but on a dark card or a
    /// dark-tinted row it became dark-on-dark and disappeared.
    static func accentText(_ scheme: ColorScheme) -> Color {
        // Brass is legible on the dark popover but not on a pale card, where the
        // deep emerald still carries. The emerald card supplies its own colours.
        scheme == .dark ? gold : greenInk
    }

    /// Fill for a selected row or pill.
    static func selectionFill(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? gold.opacity(0.22) : accentSoft
    }

    static var markGradient: LinearGradient {
        LinearGradient(
            colors: [Color(red: 0.30, green: 0.78, blue: 0.47), greenDeep],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var bannerGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.094, green: 0.259, blue: 0.204),
                Color(red: 0.043, green: 0.169, blue: 0.133),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

// MARK: - App mark

/// The mosque glyph used for the app mark, drawn rather than imported so it
/// scales cleanly at every size (menu bar, sidebar, panel header).
struct MosqueShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        func x(_ f: CGFloat) -> CGFloat { rect.minX + f * w }
        func y(_ f: CGFloat) -> CGFloat { rect.minY + f * h }
        var path = Path()

        // Base block.
        path.addRoundedRect(
            in: CGRect(x: x(0.24), y: y(0.52), width: w * 0.52, height: h * 0.36),
            cornerSize: CGSize(width: w * 0.05, height: w * 0.05)
        )

        // Central dome.
        path.move(to: CGPoint(x: x(0.22), y: y(0.54)))
        path.addQuadCurve(
            to: CGPoint(x: x(0.78), y: y(0.54)),
            control: CGPoint(x: x(0.50), y: y(0.14))
        )
        path.closeSubpath()

        // Finial.
        path.addRect(CGRect(x: x(0.475), y: y(0.08), width: w * 0.05, height: h * 0.12))

        // Minarets.
        for centre in [CGFloat(0.14), CGFloat(0.86)] {
            path.addRoundedRect(
                in: CGRect(x: x(centre) - w * 0.045, y: y(0.34), width: w * 0.09, height: h * 0.54),
                cornerSize: CGSize(width: w * 0.045, height: w * 0.045)
            )
            path.addEllipse(in: CGRect(
                x: x(centre) - w * 0.06, y: y(0.26), width: w * 0.12, height: h * 0.12
            ))
        }

        // Doorway, cut out by even-odd fill at the call site.
        path.addRoundedRect(
            in: CGRect(x: x(0.43), y: y(0.66), width: w * 0.14, height: h * 0.22),
            cornerSize: CGSize(width: w * 0.07, height: w * 0.07)
        )
        return path
    }
}

/// The rounded-square app mark.
///
/// Uses the supplied icon artwork; the drawn mosque remains as a fallback so the
/// UI still renders if the resource is missing.
struct AppMark: View {
    var size: CGFloat = 44
    var showsShadow: Bool = true

    var body: some View {
        Group {
            if let image = NSImage(named: "appicon") {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
            } else {
                RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                    .fill(Palette.markGradient)
                    .overlay {
                        MosqueShape()
                            .fill(.white, style: FillStyle(eoFill: true))
                            .padding(size * 0.16)
                    }
            }
        }
        .frame(width: size, height: size)
        .shadow(color: Palette.greenDeep.opacity(showsShadow ? 0.20 : 0), radius: size * 0.10, y: size * 0.04)
    }
}

/// The full wordmark, used where the app introduces itself.
struct BrandLogo: View {
    var width: CGFloat

    @Environment(\.colorScheme) private var scheme

    /// The wordmark is dark green, so it needs a light counterpart on dark
    /// backgrounds; the dome keeps its colour in both.
    private var assetName: String {
        scheme == .dark ? "logo-dark" : "logo"
    }

    var body: some View {
        if let image = NSImage(named: assetName) {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: width)
        } else {
            HStack(spacing: 10) {
                AppMark(size: width * 0.24)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Sajda Time")
                        .font(.system(size: width * 0.10, weight: .bold, design: .rounded))
                    Text("Your Daily Connection")
                        .font(.system(size: width * 0.055, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: width)
        }
    }
}

/// Landscape artwork for the next-prayer surfaces.
///
/// Fills rather than fits, so the illustration spans the full width and reads as
/// a background instead of a picture floating in the middle of the card. Callers
/// must clip, otherwise it overflows its band and draws over the text above it.
struct BannerArt: View {
    /// `.fill` spans the width and crops, for a band behind content. `.fit`
    /// shows the whole scene, which is what the reminder wants at its foot.
    var mode: ContentMode = .fill

    var body: some View {
        if let image = NSImage(named: "banner") {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: mode)
        } else {
            SkylineSilhouette()
        }
    }
}

// MARK: - Cards

/// A settings card with the icon-and-title header used throughout the design.
struct SettingsCard<Content: View>: View {
    var title: String?
    var symbol: String?
    var tint: Color = Palette.accent
    @ViewBuilder var content: Content

    @Environment(\.colorScheme) private var scheme

    /// A tinted glass rather than plain `.regular`.
    ///
    /// Untinted glass is fully see-through, so over a busy or dark desktop the
    /// text inside lost contrast. The tint raises the backing opacity in both
    /// schemes without turning the card opaque.
    private var cardGlass: Glass {
        // Dark mode needs a real tint to hold contrast. Light mode needs only a
        // hint, otherwise the card turns into a plain white rectangle and the
        // glass effect disappears.
        scheme == .dark
            ? .regular.tint(Color.black.opacity(0.34))
            : .regular.tint(Color.white.opacity(0.14))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                HStack(spacing: 8) {
                    if let symbol {
                        Image(systemName: symbol)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(tint)
                            .frame(width: 18)
                    }
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)
            }
            VStack(alignment: .leading, spacing: 8) {
                content
            }
            .padding(.horizontal, 14)
            .padding(.bottom, title == nil ? 12 : 14)
            .padding(.top, title == nil ? 12 : 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(cardGlass, in: RoundedRectangle(cornerRadius: Palette.cardCorner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Palette.cardCorner, style: .continuous)
                .strokeBorder(Color.primary.opacity(scheme == .dark ? 0.10 : 0.06))
        )
    }
}

/// A row inside a card: label on the left, control on the right.
struct CardRow<Trailing: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder var trailing: Trailing

    init(_ title: String, subtitle: String? = nil, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 12.5))
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            trailing
        }
        .frame(minHeight: 26)
    }
}

// MARK: - Controls

/// Green-tinted switch, as used throughout the design.
struct SettingToggle: View {
    @Binding var isOn: Bool

    var body: some View {
        Toggle("", isOn: $isOn)
            .labelsHidden()
            .toggleStyle(.switch)
            .tint(Palette.accent)
            .controlSize(.small)
    }
}

/// Two-or-more option segmented control with a green pill for the selection.
struct SettingSegmented<Value: Hashable>: View {
    let options: [(Value, String)]
    @Binding var selection: Value

    var body: some View {
        HStack(spacing: 3) {
            ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                let selected = option.0 == selection
                Button {
                    selection = option.0
                } label: {
                    Text(option.1)
                        .font(.system(size: 12, weight: selected ? .semibold : .regular))
                        .foregroundStyle(selected ? Color.white : Color.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(selected ? Palette.accent : Color.clear)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.06))
        )
    }
}

/// Plain dropdown that sits flush with the card background.
struct SettingPicker<Value: Hashable>: View {
    let options: [(Value, String)]
    @Binding var selection: Value
    var width: CGFloat?

    var body: some View {
        Picker("", selection: $selection) {
            ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                Text(option.1).tag(option.0)
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .controlSize(.regular)
        .tint(Palette.accent)
        .frame(width: width, alignment: .trailing)
    }
}

/// Bordered secondary button, as used for "Detect Again" and "Test Sound".
struct CardButton: View {
    let title: String
    var systemImage: String?
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title)
            }
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.10))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Banner illustration

/// Fallback skyline, drawn rather than loaded. Only used when the supplied
/// banner artwork is unavailable.
struct SkylineSilhouette: View {
    var tint: Color = Palette.greenDeep

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack(alignment: .bottomLeading) {
                Circle()
                    .fill(Palette.amber.opacity(0.55))
                    .frame(width: h * 0.42, height: h * 0.42)
                    .offset(x: w * 0.60, y: -h * 0.42)

                HStack(alignment: .bottom, spacing: w * 0.02) {
                    silhouette(width: w * 0.13, height: h * 0.52)
                    silhouette(width: w * 0.17, height: h * 0.78)
                    silhouette(width: w * 0.11, height: h * 0.44)
                    silhouette(width: w * 0.15, height: h * 0.62)
                }

                Rectangle()
                    .fill(tint.opacity(0.45))
                    .frame(height: h * 0.10)
            }
        }
        .clipped()
    }

    private func silhouette(width: CGFloat, height: CGFloat) -> some View {
        MosqueShape()
            .fill(tint.opacity(0.55), style: FillStyle(eoFill: true))
            .frame(width: width, height: height)
    }
}

// MARK: - Inline messages

/// Compact status line for errors and caveats.
struct StatusLine: View {
    enum Kind { case info, warning, error }

    let text: String
    var kind: Kind = .info

    private var symbol: String {
        switch kind {
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.octagon.fill"
        }
    }

    private var colour: Color {
        switch kind {
        case .info: return Palette.accent
        case .warning: return Palette.amber
        case .error: return .red
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 7) {
            Image(systemName: symbol)
                .font(.system(size: 11))
                .foregroundStyle(colour)
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
    }
}
