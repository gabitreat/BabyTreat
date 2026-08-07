import Foundation
import SwiftUI

/// How badly a meal went, when it went badly enough to be worth recording.
///
/// The first level is deliberately **not** a reaction. Separating "didn't like
/// it" from "reacted to it" is the whole point: they look identical at the table
/// — a refused bowl — and they call for opposite responses. A disliked food
/// needs to come back, repeatedly. A food that caused symptoms needs to go away.
enum ToleranceLevel: String, Codable, CaseIterable, Identifiable {
    case dislike
    case mild
    case moderate
    case severe

    var id: String { rawValue }

    var label: String {
        switch self {
        case .dislike:  "Didn't like it"
        case .mild:     "Mild reaction"
        case .moderate: "Moderate reaction"
        case .severe:   "Severe reaction"
        }
    }

    /// Concrete signs, because "mild" and "moderate" mean nothing on their own
    /// at 7pm with a crying baby.
    var hint: String {
        switch self {
        case .dislike:  "Taste or texture. No physical signs."
        case .mild:     "Gas, loose stool, redness around the mouth."
        case .moderate: "Vomiting, eczema flare, blood in stool."
        case .severe:   "Hives, swelling, difficulty breathing. Call the doctor."
        }
    }

    /// Mapped onto the meal palette rather than system colours, so the severity
    /// scale reads as part of this section: lagoon → marigold → sugar → bubblegum.
    var color: Color {
        switch self {
        case .dislike:  MealTheme.lagoon
        case .mild:     MealTheme.marigold
        case .moderate: MealTheme.sugar
        case .severe:   MealTheme.bubblegum
        }
    }

    var softColor: Color {
        switch self {
        case .dislike:  MealTheme.lagoonSoft
        case .mild:     MealTheme.marigoldSoft
        case .moderate: MealTheme.sugarSoft
        case .severe:   MealTheme.bubbleSoft
        }
    }

    /// Days to keep the food off the menu. `0` means never suppress; `nil` means
    /// indefinitely, until a person decides otherwise.
    var suppressDays: Int? {
        switch self {
        case .dislike:  0
        case .mild:     21
        case .moderate: nil
        case .severe:   nil
        }
    }

    var needsPediatrician: Bool { self == .moderate || self == .severe }

    /// Only severe. A hard block cannot be cleared by tapping past it.
    var hardBlock: Bool { self == .severe }
}
