import Foundation

/// A short saying shown on the full-screen reminder.
public struct ReminderQuote: Sendable, Identifiable, Equatable {
    public enum Kind: String, Sendable {
        case hadith
        case quran
    }

    public let id: String
    public let kind: Kind
    public let text: String
    /// Collection and number, e.g. "Jami` at-Tirmidhi 413".
    public let reference: String

    public init(id: String, kind: Kind, text: String, reference: String) {
        self.id = id
        self.kind = kind
        self.text = text
        self.reference = reference
    }
}

/// Short sayings on the importance of salah.
///
/// Deliberately short: a reminder that appears at the moment of prayer should be
/// readable at a glance, not a paragraph. Texts and references are taken from
/// the QuranExplorer compilation of ahadith on the merit of salah; the wording
/// is quoted, not paraphrased, and no narrator is given where the source does
/// not give one.
public enum ReminderQuotes {

    public static let all: [ReminderQuote] = [
        ReminderQuote(
            id: "tirmidhi-413",
            kind: .hadith,
            text: "Indeed the first deed by which a servant will be called to account on the Day of Resurrection is his Salat.",
            reference: "Jami` at-Tirmidhi 413"
        ),
        ReminderQuote(
            id: "tirmidhi-4",
            kind: .hadith,
            text: "The key to Paradise is Salat, and the key to Salat is Wudu'.",
            reference: "Jami` at-Tirmidhi 4"
        ),
        ReminderQuote(
            id: "tirmidhi-2618",
            kind: .hadith,
            text: "Between disbelief and faith is abandoning the Salat.",
            reference: "Jami` at-Tirmidhi 2618"
        ),
        ReminderQuote(
            id: "tirmidhi-170",
            kind: .hadith,
            text: "The Prophet was asked, “Which deed is the best?” He said, “Salat in the beginning of its time.”",
            reference: "Jami` at-Tirmidhi 170"
        ),
        ReminderQuote(
            id: "riyad-1102",
            kind: .hadith,
            text: "The two Rak'ah before the dawn prayer are better than this world and all it contains.",
            reference: "Riyad as-Salihin 1102 · Muslim"
        ),
        ReminderQuote(
            id: "riyad-1073",
            kind: .hadith,
            text: "No Salat is more burdensome to the hypocrites than the Fajr and the Isha prayer.",
            reference: "Riyad as-Salihin 1073 · Al-Bukhari and Muslim"
        ),
        ReminderQuote(
            id: "tirmidhi-221",
            kind: .hadith,
            text: "Whoever attends Isha in congregation has the reward as if he had stood half of the night.",
            reference: "Jami` at-Tirmidhi 221"
        ),
        ReminderQuote(
            id: "quran-29-45",
            kind: .quran,
            text: "Indeed, prayer prohibits immorality and wrongdoing.",
            reference: "Qur'an 29:45"
        ),
        ReminderQuote(
            id: "quran-23-1",
            kind: .quran,
            text: "Successful indeed are the believers: those who humble themselves in prayer.",
            reference: "Qur'an 23:1–2"
        ),
        ReminderQuote(
            id: "quran-2-153",
            kind: .quran,
            text: "Seek help through patience and prayer. Indeed, Allah is with the patient.",
            reference: "Qur'an 2:153"
        ),
    ]

    /// A quote at random, avoiding an immediate repeat.
    public static func random(excluding previous: String? = nil) -> ReminderQuote {
        let pool = all.filter { $0.id != previous }
        return (pool.isEmpty ? all : pool).randomElement() ?? all[0]
    }
}
