import SwiftUI
import SajdaCore

/// The full-screen reminder shown when a prayer begins.
///
/// Deliberately a screen-filling modal rather than a banner: it is meant to be
/// noticed. The backdrop is chosen by prayer, since the light in each image
/// matches the time of day that prayer falls at.
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
        case .isha: return 0.44
        case .maghrib: return 0.22
        default: return 0.17
        }
    }

    var body: some View {
        ZStack {
            backdrop
            // Dark text needs a light backing, but how much depends on the
            // backdrop: the daytime images are already bright, while the night
            // one used for Isha is dark enough to swallow it.
            Color.white.opacity(washOpacity)
            LinearGradient(
                colors: [Color.white.opacity(0.35), .clear, Color.white.opacity(0.25)],
                startPoint: .top, endPoint: .bottom
            )

            VStack(spacing: 0) {
                header
                Spacer(minLength: 12)
                title
                timeChip
                metaLine
                hadithCard
                Spacer(minLength: 12)
                // Fitted, so the whole scene is visible rather than a slice of it.
                BannerArt(mode: .fit)
                    .frame(maxWidth: .infinity)
                    .frame(height: 240)
                    .allowsHitTesting(false)
                actions
                muteRow
            }
            .padding(.horizontal, 60)
            .padding(.vertical, 40)
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared ? 0.985 : 1)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeOut(duration: 0.35)) { appeared = true }
        }
    }

    // MARK: - Pieces

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

    private var header: some View {
        HStack(spacing: 12) {
            AppMark(size: 54)
            VStack(alignment: .leading, spacing: 0) {
                Text("Sajda Time")
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                Text("Your Daily Connection")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "bell.fill").font(.system(size: 11))
                Text("Prayer Reminder").font(.system(size: 14, weight: .medium, design: .rounded))
            }
            .foregroundStyle(Palette.greenDeep)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Capsule().fill(Color.white.opacity(0.65)))
        }
        .foregroundStyle(Palette.greenDeep)
    }

    private var title: some View {
        VStack(spacing: 6) {
            Text("It's time for \(prayer.displayName)")
                .font(.system(size: 78, weight: .bold, design: .serif))
                .foregroundStyle(Palette.greenDeep)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text("Pause for prayer and reconnect.")
                .font(.system(size: 27, design: .serif))
                .foregroundStyle(Palette.greenDeep.opacity(0.85))
        }
        .multilineTextAlignment(.center)
    }

    private var timeChip: some View {
        HStack(spacing: 12) {
            Image(systemName: "clock")
                .font(.system(size: 36, weight: .medium))
            Text(settings.clock(time))
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .monospacedDigit()
        }
        .foregroundStyle(Palette.greenDeep)
        .padding(.horizontal, 34)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.55))
        )
        .padding(.top, 16)
    }

    private var metaLine: some View {
        HStack(spacing: 8) {
            Image(systemName: "mappin.and.ellipse").font(.system(size: 13))
            Text(metaText)
                .font(.system(size: 17, design: .rounded))
        }
        .foregroundStyle(Palette.greenDeep.opacity(0.9))
        .padding(.top, 14)
    }

    private var metaText: String {
        var parts: [String] = []
        if !place.isEmpty { parts.append(place) }
        parts.append(TimeFormatting.longDate(time, timeZone: settings.displayTimeZone))
        if settings.showHijriDate, let hijri { parts.append(hijri) }
        return parts.joined(separator: "  •  ")
    }

    private var hadithCard: some View {
        VStack(spacing: 10) {
            Image(systemName: quote.kind == .quran ? "book.closed.fill" : "text.book.closed.fill")
                .font(.system(size: 22))
                .foregroundStyle(Palette.greenDeep)
                .frame(width: 46, height: 46)
                .background(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(Palette.greenSoft)
                )

            Text("“\(quote.text)”")
                .font(.system(size: 23, design: .serif))
                .foregroundStyle(Palette.greenDeep)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Rectangle().fill(Palette.greenDeep.opacity(0.25)).frame(width: 46, height: 1)
                Text(quote.kind == .quran ? quote.reference : "— \(quote.reference)")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(Palette.greenDeep.opacity(0.75))
                Rectangle().fill(Palette.greenDeep.opacity(0.25)).frame(width: 46, height: 1)
            }
        }
        .padding(28)
        .frame(maxWidth: 800)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.55))
        )
        .padding(.top, 18)
    }

    private var actions: some View {
        HStack(spacing: 16) {
            alertButton("Dismiss", systemImage: "xmark", action: onDismiss)
            alertButton("Snooze \(snoozeMinutes) min", systemImage: "clock.arrow.circlepath", action: onSnooze)
        }
        .padding(.top, 18)
    }

    private func alertButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage).font(.system(size: 13, weight: .semibold))
                Text(title).font(.system(size: 17, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(Palette.greenDeep)
            .frame(width: 250)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.7))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var muteRow: some View {
        Button(action: onMuteToday) {
            HStack(spacing: 6) {
                Rectangle().fill(Palette.greenDeep.opacity(0.3)).frame(width: 40, height: 1)
                Image(systemName: "speaker.slash.fill").font(.system(size: 11))
                Text("Mute Adhan Today").font(.system(size: 14, design: .rounded))
                Rectangle().fill(Palette.greenDeep.opacity(0.3)).frame(width: 40, height: 1)
            }
            .foregroundStyle(Palette.greenDeep.opacity(0.8))
        }
        .buttonStyle(.plain)
        .padding(.top, 16)
    }
}
