import Foundation
import SwiftData

/// Something observed, at a time, with **no link to any meal**.
///
/// CRITICAL — there is deliberately no `meal` property, no foreign key, and no
/// "attach to the last meal" convenience. Auto-attaching a reaction to the most
/// recent meal systematically blames dinner, because dinner is nearly always the
/// most recent meal when symptoms get noticed in the evening. Attribution is
/// computed at read time by `ReactionAttribution`, across a 48-hour window, and
/// returns ranked candidates rather than a verdict.
///
/// This sits alongside the tolerance fields on `MealLog`, which answer a
/// different question: *which food in this one meal*. This answers *which meal
/// in the last two days*.
@Model
final class ReactionLog {
    /// User-set, independent of any meal. Never prefilled from one.
    var observedAt: Date
    var severityRaw: String
    var symptoms: [String]
    var notes: String
    /// Audit only.
    var loggedAt: Date

    init(
        observedAt: Date,
        severity: ToleranceLevel,
        symptoms: [String] = [],
        notes: String = "",
        loggedAt: Date = .now
    ) {
        // Minute precision: seconds are noise, and a stored second implies a
        // confidence nobody has about when a rash started.
        self.observedAt = ReactionLog.roundedToMinute(observedAt)
        self.severityRaw = severity.rawValue
        self.symptoms = symptoms
        self.notes = notes
        self.loggedAt = loggedAt
    }

    /// Reuses `ToleranceLevel` — dislike / mild / moderate / severe — rather
    /// than defining a second four-case severity scale that would drift out of
    /// step with the one already on `MealLog`.
    var severity: ToleranceLevel {
        get { ToleranceLevel(rawValue: severityRaw) ?? .mild }
        set { severityRaw = newValue.rawValue }
    }

    /// `dislike` is a taste signal, not a reaction, and is excluded from
    /// attribution scoring entirely.
    var countsForAttribution: Bool { severity != .dislike }

    static func roundedToMinute(_ date: Date) -> Date {
        let seconds = Calendar.current.component(.second, from: date)
        return Calendar.current.date(byAdding: .second, value: -seconds, to: date) ?? date
    }

    /// Symptoms offered in the picker, grouped the way they present.
    static let commonSymptoms = [
        "Hives", "Swelling", "Difficulty breathing",
        "Vomiting", "Repetitive vomiting", "Diarrhoea", "Blood in stool",
        "Gas", "Loose stool", "Constipation",
        "Redness around mouth", "Eczema flare", "Rash",
        "Irritability", "Poor sleep",
    ]
}
