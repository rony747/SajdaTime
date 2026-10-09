import SwiftUI
import SajdaCore

// MARK: - Palette

enum Palette {
    /// Primary green used for selection, toggles and the app mark.
    static let green = Color(red: 0.16, green: 0.62, blue: 0.34)
    static let greenDeep = Color(red: 0.09, green: 0.45, blue: 0.24)
    static let greenSoft = Color(red: 0.87, green: 0.96, blue: 0.90)

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
                Color(red: 0.90, green: 0.97, blue: 0.92),
                Color(red: 0.98, green: 0.95, blue: 0.86),
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

    var body: some View {
        if let image = NSImage(named: "logo") {
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

/// Landscape artwork used behind the next-prayer surfaces.
struct BannerArt: View {
    var body: some View {
        if let image = NSImage(named: "banner") {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fill)
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
    var tint: Color = Palette.green
    @ViewBuilder var content: Content

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
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: Palette.cardCorner, style: .continuous))
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
struct GreenToggle: View {
    @Binding var isOn: Bool

    var body: some View {
        Toggle("", isOn: $isOn)
            .labelsHidden()
            .toggleStyle(.switch)
            .tint(Palette.green)
            .controlSize(.small)
    }
}

/// Two-or-more option segmented control with a green pill for the selection.
struct GreenSegmented<Value: Hashable>: View {
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
                                .fill(selected ? Palette.green : Color.clear)
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
struct GreenPicker<Value: Hashable>: View {
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
        .tint(Palette.green)
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
        case .info: return Palette.green
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
