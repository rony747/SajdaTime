import SwiftUI
import SajdaCore

/// A month at a glance: Gregorian day numbers with the corresponding Hijri day,
/// and today marked. Uses the Umm al-Qura calendar, the same one the times use.
struct MonthView: View {
    @ObservedObject var state: AppState
    let onBack: () -> Void

    private var zone: TimeZone { state.settings.displayTimeZone }

    private var gregorianCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        return calendar
    }

    private var hijriCalendar: Calendar {
        var calendar = Calendar(identifier: .islamicUmmAlQura)
        calendar.timeZone = zone
        return calendar
    }

    private var monthStart: Date {
        let components = gregorianCalendar.dateComponents([.year, .month], from: state.now)
        return gregorianCalendar.date(from: components) ?? state.now
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.timeZone = zone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: monthStart)
    }

    /// Leading blanks so the 1st lands on its weekday column.
    private var leadingBlanks: Int {
        let weekday = gregorianCalendar.component(.weekday, from: monthStart)
        return (weekday - gregorianCalendar.firstWeekday + 7) % 7
    }

    private var dayCount: Int {
        gregorianCalendar.range(of: .day, in: .month, for: monthStart)?.count ?? 30
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 3), count: 7)

    var body: some View {
        VStack(spacing: 12) {
            PageHeader(title: "Calendar", subtitle: monthTitle, onBack: onBack)

            LazyVGrid(columns: columns, spacing: 3) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }

                ForEach(0..<leadingBlanks, id: \.self) { _ in
                    Color.clear.frame(height: 40)
                }

                ForEach(1...dayCount, id: \.self) { day in
                    dayCell(day)
                }
            }

            if let hijri = state.today?.hijri {
                Text("Today is \(hijri.formatted)")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func dayCell(_ day: Int) -> some View {
        let date = gregorianCalendar.date(byAdding: .day, value: day - 1, to: monthStart) ?? monthStart
        let hijriDay = hijriCalendar.component(.day, from: date)
        let isToday = gregorianCalendar.isDate(date, inSameDayAs: state.now)

        return VStack(spacing: 0) {
            Text("\(day)")
                .font(.system(size: 12, weight: isToday ? .bold : .regular, design: .rounded))
                .foregroundStyle(isToday ? Color.white : Color.primary)
            Text("\(hijriDay)")
                .font(.system(size: 9, design: .rounded))
                .foregroundStyle(isToday ? Color.white.opacity(0.85) : Color.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 40)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isToday ? Palette.green : Color.primary.opacity(0.04))
        )
    }

    private var weekdaySymbols: [String] {
        var calendar = gregorianCalendar
        calendar.locale = Locale(identifier: "en_US_POSIX")
        let symbols = calendar.veryShortWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }
}
