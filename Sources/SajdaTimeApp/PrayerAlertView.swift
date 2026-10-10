import SwiftUI
import SajdaCore

/// The full-screen reminder shown when a prayer begins.
///
/// Built to the supplied design: the photograph is dimmed back, and an emerald
/// card with brass ornament sits over it carrying the prayer, its time, a short
/// saying and the actions. Type stays on the system faces — New York for the
/// display lines and the saying, SF Rounded for the numerals and labels.
struct PrayerAlertView: View {
    let prayer: Prayer
    let time: Date
    let place: String
    let hijri: String?
    let settings: AppSettings
    let quote: ReminderQuote
    let snoozeMinutes: Int
    /// Seconds before it closes itself. 0 keeps it up until dismissed.
    let autoCloseAfter: TimeInterval
    let onDismiss: () -> Void
    let onSnooze: () -> Void
    let onMuteToday: () -> Void

    @State private var appeared = false
    @State private var remaining: TimeInterval = 0

    /// One publisher per view instance, rather than one built on every redraw.
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var backdropName: String { "alert-\(prayer.rawValue)" }

    var body: some View {
        // Overlays on a plain fill rather than a ZStack: a ZStack sizes to its
        // largest child, and `aspectRatio(.fill)` makes the backdrop larger than
        // the screen, which would push the card off it.
        Color.black
            .overlay { backdrop }
            // Held well back so the card carries the screen.
            .overlay { Color.black.opacity(0.52) }
            .overlay { content }
            .clipped()
            .ignoresSafeArea()
            .onAppear {
                remaining = autoCloseAfter
                withAnimation(.easeOut(duration: 0.45)) { appeared = true }
            }
            .onReceive(ticker) { _ in
                guard autoCloseAfter > 0 else { return }
                remaining = max(0, remaining - 1)
                if remaining == 0 { onDismiss() }
            }
    }

    // MARK: - Layout

    private var content: some View {
        VStack(spacing: 0) {
            header
            Spacer(minLength: 14)
            card
                .frame(maxWidth: 760)
            Spacer(minLength: 14)
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 32)
        .multilineTextAlignment(.center)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 14)
    }

    private var backdrop: some View {
        Group {
            if let image = NSImage(named: backdropName) {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fill)
            } else {
                Palette.emeraldInset
            }
        }
        .ignoresSafeArea()
        .clipped()
    }

    // MARK: - Header, above the card

    private var header: some View {
        HStack(spacing: 12) {
            AppMark(size: 46)
            VStack(alignment: .leading, spacing: 0) {
                Text("Sajda Time")
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                Text("Your Daily Connection")
                    .font(.system(size: 12.5, design: .rounded))
                    .foregroundStyle(Palette.cream.opacity(0.72))
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(Palette.cream)
        .shadow(color: .black.opacity(0.55), radius: 10, y: 1)
    }

    // MARK: - The card

    private var card: some View {
        VStack(spacing: 0) {
            Text("It's time for \(prayer.displayName)")
                .font(.system(size: 52, weight: .bold, design: .serif))
                .tracking(-1.0)
                .foregroundStyle(Palette.cream)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(.top, 30)

            Text("Pause for prayer and reconnect.")
                .font(.system(size: 21, design: .serif))
                .foregroundStyle(Palette.cream.opacity(0.78))
                .padding(.top, 6)

            RuleDivider(width: 78, symbol: true)
                .padding(.top, 16)

            timeChip.padding(.top, 20)
            metaLine.padding(.top, 16)
            hadithCard.padding(.top, 20)
            dismissButton.padding(.top, 22)
            secondaryRow.padding(.top, 12)

            RuleDivider(width: 52, text: "Closes in \(countdownText)")
                .padding(.top, 16)
                .padding(.bottom, 22)
                .opacity(autoCloseAfter > 0 ? 1 : 0)
        }
        .padding(.horizontal, 38)
        .background(
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .fill(Palette.emeraldCard.opacity(0.94))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .strokeBorder(Palette.gold.opacity(0.55), lineWidth: 1.4)
        )
        .overlay { filigree }
        .shadow(color: .black.opacity(0.55), radius: 46, y: 22)
    }

    private var timeChip: some View {
        HStack(spacing: 12) {
            Image(systemName: "clock")
                .font(.system(size: 25, weight: .light))
                .foregroundStyle(Palette.gold)
            Text(settings.clock(time))
                .font(.system(size: 42, weight: .semibold, design: .serif))
                .foregroundStyle(Palette.cream)
        }
        .padding(.horizontal, 38)
        .padding(.vertical, 9)
        .background(Capsule().fill(Palette.emeraldInset.opacity(0.85)))
        .overlay(Capsule().strokeBorder(Palette.gold.opacity(0.55), lineWidth: 1.2))
    }

    private var metaLine: some View {
        HStack(spacing: 9) {
            metaItem("mappin.and.ellipse", place.isEmpty ? "Unknown place" : place)
            metaDot
            metaItem("calendar", TimeFormatting.longDate(time, timeZone: settings.displayTimeZone))
            if settings.showHijriDate, let hijri {
                metaDot
                metaItem("moon.fill", hijri)
            }
        }
    }

    private var metaDot: some View {
        Circle()
            .fill(Palette.gold.opacity(0.7))
            .frame(width: 3, height: 3)
    }

    private func metaItem(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 12))
                .foregroundStyle(Palette.gold.opacity(0.85))
            Text(text)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Palette.cream.opacity(0.88))
        }
    }

    private var hadithCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "quote.opening")
                .font(.system(size: 20))
                .foregroundStyle(Palette.gold)

            Text(quote.displayText)
                .font(.system(size: 21, design: .serif))
                .italic()
                .lineSpacing(9)
                .foregroundStyle(Palette.cream)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 22)

            RuleDivider(width: 40, text: quote.reference)
                .padding(.top, 2)
        }
        .padding(.vertical, 20)
        .frame(maxWidth: 620)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Palette.emeraldInset.opacity(0.62))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Palette.gold.opacity(0.40), lineWidth: 1)
        )
        .overlay(alignment: .leading) { quoteBracket.padding(.leading, 12) }
        .overlay(alignment: .trailing) { quoteBracket.padding(.trailing, 12) }
    }

    /// A thin brushed upright, standing in for the design's curly flourish.
    private var quoteBracket: some View {
        Capsule()
            .fill(Palette.gold.opacity(0.45))
            .frame(width: 1.6, height: 34)
    }

    private var dismissButton: some View {
        Button(action: onDismiss) {
            HStack(spacing: 12) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                Text("Dismiss")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(Palette.cream)
            .frame(width: 420, height: 56)
            .background(Capsule().fill(Palette.emeraldAction))
            .overlay(Capsule().strokeBorder(Palette.gold.opacity(0.55), lineWidth: 1.2))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.defaultAction)
    }

    private var secondaryRow: some View {
        HStack(spacing: 12) {
            secondaryButton("Snooze \(snoozeMinutes) min",
                            systemImage: "clock.arrow.circlepath",
                            action: onSnooze)
            secondaryButton("Mute Adhan Today",
                            systemImage: "speaker.slash.fill",
                            action: onMuteToday)
        }
    }

    private func secondaryButton(
        _ title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage).font(.system(size: 13))
                Text(title).font(.system(size: 14.5, weight: .medium, design: .rounded))
            }
            .foregroundStyle(Palette.cream.opacity(0.9))
            .frame(width: 202, height: 42)
            .background(Capsule().fill(.white.opacity(0.05)))
            .overlay(Capsule().strokeBorder(Palette.gold.opacity(0.32), lineWidth: 1))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var filigree: some View {
        let stroke = Palette.gold.opacity(0.28)
        return ZStack {
            CornerFiligree().stroke(stroke, lineWidth: 1)
                .frame(width: 44, height: 44)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .rotationEffect(.degrees(0))
                .padding(12)
            CornerFiligree().stroke(stroke, lineWidth: 1)
                .frame(width: 44, height: 44)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .rotationEffect(.degrees(90))
                .padding(12)
            CornerFiligree().stroke(stroke, lineWidth: 1)
                .frame(width: 44, height: 44)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .rotationEffect(.degrees(180))
                .padding(12)
            CornerFiligree().stroke(stroke, lineWidth: 1)
                .frame(width: 44, height: 44)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .rotationEffect(.degrees(270))
                .padding(12)
        }
    }

    private var countdownText: String {
        let total = Int(remaining.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

// MARK: - Ornaments

/// A gold rule with a centred ornament or label, used under the subtitle, inside
/// the hadith panel and above the countdown.
struct RuleDivider: View {
    var width: CGFloat = 70
    var symbol: Bool = false
    var text: String?

    var body: some View {
        HStack(spacing: 10) {
            rule
            if symbol {
                Rectangle()
                    .fill(Palette.gold.opacity(0.85))
                    .frame(width: 5, height: 5)
                    .rotationEffect(.degrees(45))
            }
            if let text {
                Text(text)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Palette.cream.opacity(0.62))
                    .fixedSize()
            }
            rule
        }
    }

    private var rule: some View {
        Rectangle()
            .fill(Palette.gold.opacity(0.35))
            .frame(width: width, height: 1)
    }
}

/// Nested curves in one corner, standing in for the design's filigree.
struct CornerFiligree: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width, h = rect.height
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.minX + w * 0.08, y: rect.minY + h * 0.08)
        )
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + h * 0.55))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + w * 0.55, y: rect.minY),
            control: CGPoint(x: rect.minX + w * 0.10, y: rect.minY + h * 0.10)
        )
        return path
    }
}
