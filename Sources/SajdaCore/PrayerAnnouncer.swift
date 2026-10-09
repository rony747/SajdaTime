import Foundation

/// Decides which prayer, if any, is due to be announced right now.
///
/// This lives in the library rather than in the app so the rule can be tested.
/// The rule it replaces could not be: it required a timer tick to land inside the
/// 60 seconds after a prayer began, which fails whenever the app is App Napped or
/// the Mac is asleep. Notifications kept arriving through those gaps because the
/// system schedules them in advance, which made the reminder look broken next to
/// them.
public enum PrayerAnnouncer {

    public struct Decision: Sendable {
        public let prayer: Prayer
        public let time: Date
        /// Every prayer that has already started, so none is announced twice and
        /// a wake after a long sleep does not produce a burst.
        public let keys: [String]
        /// False when the prayer began too long ago to be worth interrupting for.
        /// The keys are still returned, so it is recorded as dealt with.
        public let shouldAnnounce: Bool
    }

    /// Key for one prayer on one occasion.
    public static func key(_ prayer: Prayer, _ time: Date, prefix: String = "") -> String {
        "\(prefix)\(prayer.rawValue)-\(Int(time.timeIntervalSince1970))"
    }

    /// The most recent prayer that has started and not yet been announced.
    ///
    /// - Parameters:
    ///   - grace: how late it is still worth announcing. Anything older is
    ///     marked as dealt with but stays silent.
    public static func pending(
        times: PrayerTimes,
        now: Date,
        announced: Set<String>,
        prefix: String = "",
        grace: TimeInterval
    ) -> Decision? {
        let started = Prayer.obligatory
            .compactMap { prayer -> (prayer: Prayer, time: Date)? in
                guard let time = times.times[prayer], now >= time else { return nil }
                return (prayer, time)
            }
            .sorted { $0.time > $1.time }

        guard let latest = started.first else { return nil }
        guard !announced.contains(key(latest.prayer, latest.time, prefix: prefix)) else {
            return nil
        }

        return Decision(
            prayer: latest.prayer,
            time: latest.time,
            keys: started.map { key($0.prayer, $0.time, prefix: prefix) },
            shouldAnnounce: now.timeIntervalSince(latest.time) <= grace
        )
    }
}
