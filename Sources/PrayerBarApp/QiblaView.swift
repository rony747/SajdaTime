import SwiftUI
import PrayerCore

/// Qibla direction for the configured location.
///
/// Shows a bearing from true north rather than a live compass: Macs have no
/// magnetometer, so a needle driven by device heading would be fiction.
struct QiblaView: View {
    let coordinate: Coordinate
    let placeName: String
    let onBack: () -> Void

    private var bearing: Double { Qibla.bearing(from: coordinate) }
    private var distance: Double { Qibla.distance(from: coordinate) }

    private let cardinals: [(label: String, x: CGFloat, y: CGFloat)] = [
        ("N", 0, -58), ("E", 58, 0), ("S", 0, 58), ("W", -58, 0),
    ]

    var body: some View {
        VStack(spacing: 12) {
            PageHeader(
                title: "Qibla",
                subtitle: placeName.isEmpty ? "Current location" : placeName,
                onBack: onBack
            )

            ZStack {
                Circle()
                    .fill(Color.primary.opacity(0.05))
                    .frame(width: 168, height: 168)

                ForEach(0..<72, id: \.self) { tick in
                    Capsule()
                        .fill(Color.primary.opacity(tick % 18 == 0 ? 0.32 : 0.12))
                        .frame(width: tick % 18 == 0 ? 2 : 1, height: tick % 18 == 0 ? 9 : 5)
                        .offset(y: -76)
                        .rotationEffect(.degrees(Double(tick) * 5))
                }

                ForEach(cardinals.indices, id: \.self) { index in
                    let cardinal = cardinals[index]
                    Text(cardinal.label)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(cardinal.label == "N" ? Palette.green : Color.secondary)
                        .offset(x: cardinal.x, y: cardinal.y)
                }

                // Needle, rotated about the dial centre to the computed bearing.
                ZStack {
                    Rectangle()
                        .fill(Palette.green)
                        .frame(width: 3, height: 52)
                        .offset(y: -26)
                    Image(systemName: "location.north.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Palette.green)
                        .offset(y: -60)
                }
                .rotationEffect(.degrees(bearing))

                Circle()
                    .fill(Palette.green)
                    .frame(width: 9, height: 9)
            }
            .frame(height: 176)

            VStack(spacing: 3) {
                Text(String(format: "%.1f° %@", bearing, Qibla.compassPoint(for: bearing)))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text(String(format: "%.0f km to the Kaaba", distance))
                    .font(.system(size: 11.5, design: .rounded))
                    .foregroundStyle(.secondary)
                Text("Measured from true north, not magnetic north.")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

/// Shared back-header for the popover's secondary pages.
struct PageHeader: View {
    let title: String
    let subtitle: String
    let onBack: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color.primary.opacity(0.07)))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                Text(subtitle)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
    }
}
