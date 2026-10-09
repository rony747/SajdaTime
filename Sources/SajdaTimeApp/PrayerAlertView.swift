import SwiftUI
import SajdaCore

/// The full-screen reminder shown when a prayer begins.
///
/// Deliberately a screen-filling modal rather than a banner: it is meant to be
/// noticed. The backdrop is chosen by prayer, since the light in each image
/// matches the time of day that prayer falls at, and the whole composition is
/// laid out for a single screen — the controller creates one window per display.
struct PrayerAlertView: View {
    let prayer: Prayer
    let time: Date
    let place: String
    let hijri: String?
    let settings: AppSettings
    let quote: ReminderQuote
    let snoozeMinutes: Int
    let onDismiss: () -> Void
    let onSnooze: () -> Void
    let onMuteToday: () -> Void

    @State private var appeared = false

    private var backdropName: String { "alert-\(prayer.rawValue)" }

    /// Isha uses the night image, which needs a much stronger wash to carry
    /// dark text; the rest are daylight or golden hour.
    private var washOpacity: Double {
        switch prayer {
        case .isha: return 0.46
        case .maghrib: return 0.26
        default: return 0.20
        }
    }

    var body: some View {
        ZStack {
            backdrop
            wash
            // A soft pool of light behind the middle so the text sits on a calm
            // area while the photograph still reads at the edges.
            RadialGradient(
                colors: [Color.white.opacity(0.60), .clear],
                center: .center,
                startRadius: 60,
                endRadius: 900
            )

            VStack(spacing: 0) {
                header
                Spacer(minLength: 16)
                centreBlock
                Spacer(minLength: 16)
                footer
            }
            .padding(.horizontal, 64)
            .padding(.vertical, 44)
            .frame(maxWidth: 1560)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 14)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeOut(duration: 0.45)) { appeared = true }
        }
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
            // Slight darkening at the very top and bottom frames the photograph.
            LinearGradient(
                colors: [Color.black.opacity(0.16), .clear, Color.black.opacity(0.10)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 14) {
            AppMark(size: 58)
            VStack(alignment: .leading, spacing: 1) {
                Text("Sajda Time")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                Text("Your Daily Connection")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(Palette.greenDeep.opacity(0.75))
            }
            Spacer()
            HStack(spacing: 7) {
                Image(systemName: "bell.fill").font(.system(size: 12))
                Text("Prayer Reminder")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(Palette.greenDeep)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(Capsule().fill(.white.opacity(0.75)))
            .overlay(Capsule().strokeBorder(.white.opacity(0.9)))
        }
        .foregroundStyle(Palette.greenDeep)
    }

    // MARK: - Centre

    private var centreBlock: some View {
        VStack(spacing: 16) {
            Text("It's time for \(prayer.displayName)")
                .font(.system(size: 84, weight: .bold, design: .serif))
                .tracking(-1.5)
                .foregroundStyle(Palette.greenDeep)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                // Lifts the heading off a busy photograph.
                .shadow(color: .white.opacity(0.85), radius: 22, y: 2)

            Text("Pause for prayer and reconnect.")
                .font(.system(size: 28, design: .serif))
                .foregroundStyle(Palette.greenDeep.opacity(0.82))

            timeChip

            Text(metaText)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(Palette.greenDeep.opacity(0.85))
                .padding(.top, 2)

            hadithCard
        }
        .multilineTextAlignment(.center)
    }

    private var timeChip: some View {
        HStack(spacing: 14) {
            Image(systemName: "clock")
                .font(.system(size: 40, weight: .medium))
            Text(settings.clock(time))
                .font(.system(size: 62, weight: .bold, design: .rounded))
                .monospacedDigit()
        }
        .foregroundStyle(Palette.greenDeep)
        .padding(.horizontal, 42)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.white.opacity(0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Palette.green.opacity(0.35), lineWidth: 1.5)
        )
        .shadow(color: Palette.greenDeep.opacity(0.18), radius: 18, y: 6)
    }

    private var metaText: String {
        var parts: [String] = []
        if !place.isEmpty { parts.append(place) }
        parts.append(TimeFormatting.longDate(time, timeZone: settings.displayTimeZone))
        if settings.showHijriDate, let hijri { parts.append(hijri) }
        return parts.joined(separator: "   •   ")
    }

    private var hadithCard: some View {
        VStack(spacing: 14) {
            Image(systemName: quote.kind == .quran ? "book.closed.fill" : "text.book.closed.fill")
                .font(.system(size: 24))
                .foregroundStyle(Palette.greenDeep)
                .frame(width: 54, height: 54)
                .background(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(Palette.greenSoft)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .strokeBorder(.white.opacity(0.9), lineWidth: 1)
                )

            Text(quote.displayText)
                .font(.system(size: 26, design: .serif))
                .lineSpacing(9)
                .foregroundStyle(Palette.greenDeep)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                Rectangle().fill(Palette.greenDeep.opacity(0.22)).frame(width: 54, height: 1)
                Text(quote.kind == .quran ? quote.reference : "— \(quote.reference)")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(Palette.greenDeep.opacity(0.7))
                Rectangle().fill(Palette.greenDeep.opacity(0.22)).frame(width: 54, height: 1)
            }
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 30)
        .frame(maxWidth: 880)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(.white.opacity(0.66))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(.white.opacity(0.85), lineWidth: 1.5)
        )
        .shadow(color: Palette.greenDeep.opacity(0.14), radius: 24, y: 10)
        .padding(.top, 6)
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 14) {
            BannerArt(mode: .fit)
                .frame(maxWidth: .infinity)
                .frame(height: 230)
                // Feathered, otherwise the artwork's pale sky reads as a
                // rectangle pasted onto the photograph.
                .mask(
                    RadialGradient(
                        colors: [.black, .black.opacity(0.85), .clear],
                        center: .center,
                        startRadius: 40,
                        endRadius: 430
                    )
                )
                .allowsHitTesting(false)

            HStack(spacing: 18) {
                alertButton("Dismiss", systemImage: "xmark", action: onDismiss)
                alertButton("Snooze \(snoozeMinutes) min",
                            systemImage: "clock.arrow.circlepath",
                            action: onSnooze)
            }

            Button(action: onMuteToday) {
                HStack(spacing: 8) {
                    Rectangle().fill(Palette.greenDeep.opacity(0.3)).frame(width: 44, height: 1)
                    Image(systemName: "speaker.slash.fill").font(.system(size: 12))
                    Text("Mute Adhan Today")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                    Rectangle().fill(Palette.greenDeep.opacity(0.3)).frame(width: 44, height: 1)
                }
                .foregroundStyle(Palette.greenDeep.opacity(0.85))
            }
            .buttonStyle(.plain)
        }
    }

    private func alertButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: systemImage).font(.system(size: 14, weight: .bold))
                Text(title).font(.system(size: 17, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(Palette.greenDeep)
            .frame(width: 260)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.white.opacity(0.8))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(.white.opacity(0.95), lineWidth: 1.5)
            )
            .shadow(color: Palette.greenDeep.opacity(0.16), radius: 14, y: 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
