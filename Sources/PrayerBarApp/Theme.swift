import SwiftUI

/// Visual identity: a "night sky" palette with Liquid Glass surfaces.
///
/// Deliberately unlike the app this was modelled on: no flat green accent, no
/// grey grouped cards, no top tab strip. Warm amber marks the prayer that is
/// currently in its time; indigo and violet carry everything else.
enum Palette {
    static let indigo = Color(red: 0.33, green: 0.34, blue: 0.88)
    static let violet = Color(red: 0.55, green: 0.33, blue: 0.93)
    static let amber = Color(red: 1.00, green: 0.70, blue: 0.22)
    static let mint = Color(red: 0.29, green: 0.86, blue: 0.76)

    /// Accent used for selected controls.
    static let accent = indigo

    /// Gradient for progress and emphasis.
    static let aurora = LinearGradient(
        colors: [mint, indigo, violet],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Gradient used while a prayer's window is open.
    static let windowGradient = AngularGradient(
        colors: [amber, Color(red: 1.0, green: 0.45, blue: 0.35), amber],
        center: .center,
        startAngle: .degrees(-90),
        endAngle: .degrees(270)
    )
}

// MARK: - Glass surfaces

/// A rounded glass panel. The building block for every grouped surface.
struct GlassPanel<Content: View>: View {
    var cornerRadius: CGFloat = 22
    var tint: Color?
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(14)
            .glassEffect(glass, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    private var glass: Glass {
        if let tint { return .regular.tint(tint) }
        return .regular
    }
}

/// A small glass pill, used for the day's prayer chips.
struct GlassPill<Content: View>: View {
    var isActive: Bool = false
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .glassEffect(
                isActive
                    ? .regular.tint(Palette.amber.opacity(0.55)).interactive()
                    : .regular.interactive(),
                in: Capsule()
            )
    }
}

/// A circular glass icon button. Used instead of a list of text menu rows.
struct GlassIconButton: View {
    let systemImage: String
    var help: String = ""
    var tint: Color?
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint ?? .primary)
                .frame(width: 36, height: 36)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassEffect(
            tint == nil
                ? .regular.interactive()
                : .regular.tint(tint!.opacity(0.45)).interactive(),
            in: Circle()
        )
        .scaleEffect(hovering ? 1.06 : 1)
        .animation(.spring(duration: 0.22), value: hovering)
        .onHover { hovering = $0 }
        .help(help)
    }
}

// MARK: - Progress ring

/// The centrepiece of the panel: how much of the current prayer's window is left.
///
/// A ring makes the remaining time readable at a glance, and communicates that a
/// prayer's time is a *window* with a length rather than simply "until the next
/// one starts".
struct WindowRing: View {
    /// 0...1 of the window remaining, or nil when no window is open.
    let progress: Double?
    let title: String
    let subtitle: String
    let clock: String
    let symbol: String
    var diameter: CGFloat = 132

    private var lineWidth: CGFloat { diameter * 0.075 }

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(.white.opacity(0.10), lineWidth: lineWidth)

            if let progress {
                Circle()
                    .trim(from: 0, to: max(0.001, min(1, progress)))
                    .stroke(Palette.windowGradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: Palette.amber.opacity(0.45), radius: 6)
            }

            VStack(spacing: 2) {
                Image(systemName: symbol)
                    .font(.system(size: diameter * 0.13, weight: .medium))
                    .foregroundStyle(progress == nil ? AnyShapeStyle(.secondary) : AnyShapeStyle(Palette.amber))
                Text(title)
                    .font(.system(size: diameter * 0.15, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(subtitle)
                    .font(.system(size: diameter * 0.115, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                Text(clock)
                    .font(.system(size: diameter * 0.095, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
        }
        .frame(width: diameter, height: diameter)
    }
}

// MARK: - Inline messages

/// Compact status line for errors and caveats.
struct StatusLine: View {
    enum Kind { case info, warning, error }

    let text: String
    var kind: Kind = .info
    var action: (title: String, handler: () -> Void)?

    private var symbol: String {
        switch kind {
        case .info: return "info.circle"
        case .warning: return "exclamationmark.triangle"
        case .error: return "xmark.octagon"
        }
    }

    private var colour: Color {
        switch kind {
        case .info: return .secondary
        case .warning: return Palette.amber
        case .error: return .red
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 7) {
            Image(systemName: symbol)
                .font(.system(size: 11))
                .foregroundStyle(colour)
            VStack(alignment: .leading, spacing: 3) {
                Text(text)
                    .fixedSize(horizontal: false, vertical: true)
                if let action {
                    Button(action.title, action: action.handler)
                        .buttonStyle(.link)
                        .font(.system(size: 11))
                }
            }
            Spacer(minLength: 0)
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
    }
}
