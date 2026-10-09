import SwiftUI
import SajdaCore

/// Qibla compass.
///
/// Behaves like a physical compass: the bezel turns so its north marks true
/// north, a marker sits on the bezel at the Qibla bearing, and a fixed pointer
/// at the top shows the direction the device is facing. Only reachable on a
/// machine that reports a real heading — see `HeadingService`.
struct QiblaView: View {
    let coordinate: Coordinate
    let placeName: String
    /// Degrees clockwise from true north that the device is facing.
    let heading: Double
    let onBack: () -> Void

    private var bearing: Double { Qibla.bearing(from: coordinate) }
    private var distance: Double { Qibla.distance(from: coordinate) }

    /// Degrees the user must still turn to face the Qibla.
    private var offset: Double {
        let delta = (bearing - heading).truncatingRemainder(dividingBy: 360)
        return delta < 0 ? delta + 360 : delta
    }

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

                // Fixed pointer: the direction the device is facing.
                Image(systemName: "triangle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .offset(y: -86)

                // Rotating bezel. Turning it by -heading puts the bezel's north
                // on true north, and carries the Qibla marker with it.
                ZStack {
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
                            .foregroundStyle(cardinal.label == "N" ? Palette.accent : Color.secondary)
                            .offset(x: cardinal.x, y: cardinal.y)
                    }

                    // Qibla marker, fixed to the bezel at the bearing.
                    VStack(spacing: 1) {
                        Image(systemName: "location.north.fill")
                            .font(.system(size: 20, weight: .bold))
                        Text("Qibla")
                            .font(.system(size: 8, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(Palette.accent)
                    .offset(y: -46)
                    .rotationEffect(.degrees(bearing))
                }
                .rotationEffect(.degrees(-heading))
                .animation(.spring(duration: 0.25), value: heading)

                Circle()
                    .fill(Color.primary.opacity(0.35))
                    .frame(width: 7, height: 7)
            }
            .frame(height: 190)

            VStack(spacing: 3) {
                Text(String(format: "%.1f° %@", bearing, Qibla.compassPoint(for: bearing)))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text(turnInstruction)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Palette.accent)
                Text(String(format: "%.0f km to the Kaaba · facing %.0f°", distance, heading))
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }

    private var turnInstruction: String {
        if offset < 4 || offset > 356 { return "You are facing the Qibla" }
        return offset < 180
            ? String(format: "Turn %.0f° right", offset)
            : String(format: "Turn %.0f° left", 360 - offset)
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
