import SwiftUI

/// Colours and metrics shared by every screen. The reference app uses a green
/// accent throughout, so it is defined once here rather than sprinkled around.
enum Theme {
    /// Green used for the active toggle, selected segment and current prayer.
    static let accent = Color(red: 0.18, green: 0.62, blue: 0.31)
    /// Slightly darker green for text on a tinted background.
    static let accentStrong = Color(red: 0.11, green: 0.48, blue: 0.23)

    /// Fill behind grouped settings rows.
    static let card = Color.primary.opacity(0.045)
    /// Fill behind a selected row in the prayer list.
    static let selectedRow = accent.opacity(0.13)
    /// Fill for secondary buttons and the segmented control track.
    static let control = Color.primary.opacity(0.07)

    static let cardRadius: CGFloat = 10
    static let rowHeight: CGFloat = 34
}

// MARK: - Settings card

/// A grouped block of settings rows, matching the reference app's rounded card.
struct SettingsCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) { content }
            .background(
                RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                    .fill(Theme.card)
            )
    }
}

/// Section heading shown above a card, e.g. "Startup" or "Menu bar".
struct SettingsSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.primary)
            .padding(.horizontal, 2)
            .padding(.bottom, 6)
            .padding(.top, 18)
    }
}

/// A single row: label (with optional caption) on the left, control on the right.
struct SettingsRow<Trailing: View>: View {
    let title: String
    var subtitle: String?
    var showsDivider: Bool = true
    @ViewBuilder var trailing: Trailing

    init(
        _ title: String,
        subtitle: String? = nil,
        showsDivider: Bool = true,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.showsDivider = showsDivider
        self.trailing = trailing()
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13))
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 8)
                trailing
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .frame(minHeight: Theme.rowHeight)

            if showsDivider {
                Divider().padding(.leading, 12)
            }
        }
    }
}

/// A row whose whole body is a caption rather than a control.
struct SettingsNote: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
    }
}

// MARK: - Controls

/// Segmented control drawn by hand so the selected pill can use the green
/// accent; the stock macOS control follows the system accent instead.
struct SegmentedPicker<Value: Hashable>: View {
    let options: [(Value, String)]
    @Binding var selection: Value

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                let isSelected = option.0 == selection
                Button {
                    selection = option.0
                } label: {
                    Text(option.1)
                        .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? Color.white : Color.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(isSelected ? Theme.accent : Color.clear)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            }
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Theme.control)
        )
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// A dropdown that reads as plain text until hovered, like the reference app's
/// right-aligned value pickers.
struct MenuPicker<Value: Hashable>: View {
    let options: [(Value, String)]
    @Binding var selection: Value
    var width: CGFloat? = nil

    var body: some View {
        Picker("", selection: $selection) {
            ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                Text(option.1).tag(option.0)
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .controlSize(.small)
        .frame(width: width, alignment: .trailing)
        .fixedSize(horizontal: width == nil, vertical: false)
    }
}

/// Toggle tinted with the app accent colour.
struct AccentToggle: View {
    @Binding var isOn: Bool

    var body: some View {
        Toggle("", isOn: $isOn)
            .labelsHidden()
            .toggleStyle(.switch)
            .tint(Theme.accent)
            .controlSize(.small)
    }
}

/// Compact numeric stepper matching the reference app's right-aligned value.
struct ValueStepper: View {
    @Binding var value: Int
    var range: ClosedRange<Int>
    var suffix: String = ""
    var step: Int = 1

    var body: some View {
        HStack(spacing: 6) {
            Text(suffix.isEmpty ? "\(value)" : "\(value) \(suffix)")
                .font(.system(size: 13))
                .foregroundStyle(value == 0 && !suffix.isEmpty ? .secondary : .primary)
                .monospacedDigit()
            Stepper("", value: $value, in: range, step: step)
                .labelsHidden()
                .controlSize(.small)
        }
    }
}

/// A left-aligned secondary button, as used for "Detect my location" and
/// "Send a sample notification".
struct ActionButton: View {
    let title: String
    var systemImage: String? = nil
    var isBusy: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isBusy {
                    ProgressView().controlSize(.small)
                } else if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Theme.control)
            )
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
    }
}

/// Inline error text, mirroring the red message shown in the reference app.
struct InlineError: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .font(.system(size: 11))
        .foregroundStyle(.red)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
