import Foundation

/// On-disk cache of fetched days, so a cold launch does not need the network
/// and the app keeps working offline.
public final class PrayerTimesCache: @unchecked Sendable {

    /// Resolved once per process. Honours `PRAYERTIMES_DATA_DIR` so the app can
    /// be exercised from a sandboxed shell without touching the real home folder.
    public static var defaultDirectory: URL {
        if let override = ProcessInfo.processInfo.environment["PRAYERTIMES_DATA_DIR"], !override.isEmpty {
            return URL(fileURLWithPath: override, isDirectory: true)
        }
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return base.appendingPathComponent("PrayerBar", isDirectory: true)
    }

    private let directory: URL

    /// Most recent failure, surfaced so a broken cache is visible rather than
    /// silently making every launch hit the network.
    public private(set) var lastError: String?

    public init(directory: URL? = nil) {
        self.directory = directory ?? Self.defaultDirectory
        do {
            try FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)
        } catch {
            lastError = "Could not create cache directory: \(error.localizedDescription)"
        }
    }

    public var location: URL { directory }

    /// Stable key for a day's request. Two settings that would produce different
    /// times must never collide.
    public static func key(settings: AppSettings, date: Date, timeZone: TimeZone) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        let day = String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
        // Coordinates are rounded to ~1km; that is far finer than prayer times
        // change, and keeps the cache from growing without bound.
        let lat = String(format: "%.3f", settings.latitude)
        let lng = String(format: "%.3f", settings.longitude)
        return "\(day)_\(lat)_\(lng)_\(settings.methodID)_\(settings.madhab.rawValue)_\(settings.highLatitudeRule.rawValue)_\(timeZone.identifier)"
            .replacingOccurrences(of: "/", with: "-")
    }

    public func load(key: String) -> PrayerTimes? {
        let url = directory.appendingPathComponent(key).appendingPathExtension("json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            let decoded = try decoder.decode(PrayerTimes.self, from: data)
            // An entry with no times is useless; treat it as a miss so the day is
            // re-fetched rather than showing an empty panel.
            guard !decoded.times.isEmpty else { return nil }
            return decoded
        } catch {
            lastError = "Could not read cached day \(key): \(error.localizedDescription)"
            return nil
        }
    }

    public func save(_ times: PrayerTimes, key: String) {
        let url = directory.appendingPathComponent(key).appendingPathExtension("json")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        do {
            let data = try encoder.encode(times)
            do {
                // Preferred: a crash mid-write cannot leave a truncated file.
                try data.write(to: url, options: .atomic)
            } catch {
                // Atomic writes need a rename, which some volumes (network
                // shares, removable media, sandboxed mounts) refuse. The cache
                // is disposable, so fall back rather than lose caching entirely.
                try data.write(to: url, options: [])
            }
            lastError = nil
        } catch {
            lastError = "Could not cache day \(key): \(error.localizedDescription)"
        }
    }

    /// Remove cached days older than `days`, plus anything unreadable.
    public func prune(olderThan days: Int = 30) {
        let cutoff = Date().addingTimeInterval(-Double(days) * 86_400)
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.contentModificationDateKey]
        ) else { return }
        for entry in entries where entry.pathExtension == "json" {
            let modified = (try? entry.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
            if let modified, modified < cutoff {
                try? FileManager.default.removeItem(at: entry)
            }
        }
    }

    /// Remove every cached day.
    public func clearAll() {
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil
        ) else { return }
        for entry in entries where entry.pathExtension == "json" {
            try? FileManager.default.removeItem(at: entry)
        }
    }
}
