import SwiftUI
import SajdaCore

/// The full-screen reminder shown when a prayer begins.
///
/// Laid out to match the supplied design: the app header sits at the top, the
/// prayer name and time are centred, and the artwork spans the foot of the
/// screen with the buttons sitting on it.
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

    /// Isha uses the night image, which needs a much stronger wash to carry
    /// dark text; the rest are daylight or golden hour.
    private var washOpacity: Double {
        switch prayer {
        case .isha: return 0.38
        case .maghrib: return 0.18
        default: return 0.10
        }
    }

    var body: some View {
        // Laid out as overlays on a plain fill rather than as a ZStack.
        //
        // A ZStack sizes itself to its largest child, and `aspectRatio(.fill)`
        // makes the backdrop larger than the screen — `.clipped()` only clips
        // drawing, it does not shrink layout. The stack therefore grew to the
        // image's real size, the Spacers expanded to fill that phantom height,
        // and everything below the header was pushed off screen. Overlay children
        // never resize their parent, so the fill stays exactly the display size.
        Color.black
            .overlay { backdrop }
            .overlay { wash }
            // A gentle pool of light behind the middle, so the text sits on a
            // calm area while the photograph still reads.
            .overlay {
                RadialGradient(
                    colors: [Color.white.opacity(0.34), .clear],
                    center: .center,
                    startRadius: 40,
                    endRadius: 820
                )
            }
            .overlay(alignment: .top) { header }
            .overlay { centredContent }
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

    /// Everything from the prayer name to the buttons, as a single block centred
    /// on the screen.
    private var centredContent: some View {
        VStack(spacing: 0) {
            titleBlock
            timeChip.padding(.top, 20)
            metaLine.padding(.top, 14)
            hadithCard.padding(.top, 26)
            actions.padding(.top, 32)
        }
        .padding(.horizontal, 56)
        .frame(maxWidth: 1000)
        .frame(maxHeight: .infinity)
        // On the column, not on `titleBlock`: applying it there left the hadith
        // and the reference left-aligned inside their card.
        .multilineTextAlignment(.center)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 14)
    }

    // MARK: - Backdrop

    private var backdrop: some View {
        Group {
            if let image = NSImage(named: backdropName) {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fill)
            } else {
                Palette.bannerGradient
            }
        }
        .ignoresSafeArea()
        .clipped()
    }

    private var wash: some View {
        ZStack {
            Color.white.opacity(washOpacity)
            // A vignette adds depth and pulls the eye to the middle.
            RadialGradient(
                colors: [.clear, .clear, Color.black.opacity(0.26)],
                center: .center,
                startRadius: 140,
                endRadius: 1150
            )
        }
        .ignoresSafeArea()
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 14) {
            AppMark(size: 60)
            VStack(alignment: .leading, spacing: 1) {
                Text("Sajda Time")
                    .font(.system(size: 27, weight: .bold, design: .rounded))
                    .tracking(-0.4)
                Text("Your Daily Connection")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(Palette.greenInk.opacity(0.75))
            }
            Spacer()
        }
        .foregroundStyle(Palette.greenInk)
        // The header lands on bright cloud in several of the backdrops.
        .shadow(color: .white.opacity(0.95), radius: 12, y: 1)
        .padding(.horizontal, 56)
        .padding(.top, 36)
    }

    // MARK: - Centre

    private var titleBlock: some View {
        VStack(spacing: 8) {
            Text("It's time for \(prayer.displayName)")
                // New York, the system serif — no third-party faces.
                .font(.system(size: 78, weight: .bold, design: .serif))
                .tracking(-1.6)
                .foregroundStyle(Palette.inkGradient)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                // Lifts the heading off a busy photograph.
                .shadow(color: .white.opacity(0.9), radius: 20, y: 2)

            Text("Pause for prayer and reconnect.")
                .font(.system(size: 27, weight: .regular, design: .serif))
                .tracking(0.2)
                .foregroundStyle(Palette.greenInk.opacity(0.72))
        }
    }

    private var timeChip: some View {
        HStack(spacing: 14) {
            Image(systemName: "clock")
                .font(.system(size: 38, weight: .medium))
            Text(settings.clock(time))
                .font(.system(size: 58, weight: .bold, design: .rounded))
                .monospacedDigit()
        }
        .foregroundStyle(Palette.greenInk)
        .padding(.horizontal, 40)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.white.opacity(0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Palette.green.opacity(0.3), lineWidth: 1.5)
        )
        .shadow(color: Palette.greenDeep.opacity(0.16), radius: 16, y: 5)
    }

    private var metaLine: some View {
        HStack(spacing: 8) {
            Image(systemName: "mappin.and.ellipse").font(.system(size: 14))
            Text(metaText)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .tracking(0.3)
        }
        .foregroundStyle(Palette.greenInk.opacity(0.9))
    }

    private var metaText: String {
        var parts: [String] = []
        if !place.isEmpty { parts.append(place) }
        parts.append(TimeFormatting.longDate(time, timeZone: settings.displayTimeZone))
        if settings.showHijriDate, let hijri { parts.append(hijri) }
        return parts.joined(separator: "   •   ")
    }

    private var hadithCard: some View {
        VStack(spacing: 12) {
            Image(systemName: quote.kind == .quran ? "book.closed.fill" : "text.book.closed.fill")
                .font(.system(size: 22))
                .foregroundStyle(Palette.greenInk)
                .frame(width: 50, height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Palette.greenSoft)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(.white.opacity(0.9), lineWidth: 1)
                )

            Text(quote.displayText)
                .font(.system(size: 28, weight: .regular, design: .serif))
                .italic()
                .tracking(0.2)
                .lineSpacing(12)
                .foregroundStyle(Palette.greenInk)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                Rectangle().fill(Palette.greenInk.opacity(0.22)).frame(width: 50, height: 1)
                Text(quote.kind == .quran ? quote.reference : "— \(quote.reference)")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .tracking(0.6)
                    .foregroundStyle(Palette.greenInk.opacity(0.68))
                Rectangle().fill(Palette.greenInk.opacity(0.22)).frame(width: 50, height: 1)
            }
        }
        .padding(.horizontal, 36)
        .padding(.vertical, 26)
        .frame(maxWidth: 820)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.white.opacity(0.64))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.white.opacity(0.85), lineWidth: 1.5)
        )
        .shadow(color: Palette.greenDeep.opacity(0.12), radius: 22, y: 8)
    }

    // MARK: - Foot

    private var actions: some View {
        VStack(spacing: 16) {
            // The one action the design wants people to take, so it is by far
            // the largest target and the only filled button.
            dismissButton

            HStack(spacing: 12) {
                secondaryButton("Snooze \(snoozeMinutes) min",
                                systemImage: "clock.arrow.circlepath",
                                action: onSnooze)
                secondaryButton("Mute Adhan Today",
                                systemImage: "speaker.slash.fill",
                                action: onMuteToday)
            }

            if autoCloseAfter > 0 {
                // Over the artwork the green ink alone was hard to read, so it
                // gets the same light backing as the rest of the controls.
                Text("Closes in \(countdownText)")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Palette.greenInk.opacity(0.85))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(.white.opacity(0.72)))
            }
        }
    }

    private var countdownText: String {
        let total = Int(remaining.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    /// The primary action: wide, tall, filled, and bound to Return.
    private var dismissButton: some View {
        Button(action: onDismiss) {
            HStack(spacing: 14) {
                Image(systemName: "xmark")
                    .font(.system(size: 21, weight: .bold))
                Text("Dismiss")
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                    .tracking(0.2)
            }
            .foregroundStyle(.white)
            .frame(width: 480, height: 76)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Palette.inkGradient)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(.white.opacity(0.35), lineWidth: 1.5)
            )
            .shadow(color: Palette.greenInk.opacity(0.45), radius: 26, y: 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.defaultAction)
    }

    private func secondaryButton(
        _ title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage).font(.system(size: 13, weight: .semibold))
                Text(title).font(.system(size: 16, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(Palette.greenInk)
            .frame(width: 234, height: 50)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.white.opacity(0.78))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(.white.opacity(0.9), lineWidth: 1.5)
            )
            .shadow(color: Palette.greenDeep.opacity(0.14), radius: 12, y: 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
