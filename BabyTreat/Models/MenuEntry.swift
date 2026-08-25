import Foundation
import SwiftData

enum MealSlot: String, Codable, CaseIterable, Identifiable {
    case breakfast = "md"
    case lunch     = "pranz"
    case dinner    = "cina"
    case snack     = "gustare"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .breakfast: "Breakfast"
        case .lunch:     "Lunch"
        case .dinner:    "Dinner"
        case .snack:     "Snack"
        }
    }

    var short: String {
        switch self {
        case .breakfast: "BF"
        case .lunch:     "LU"
        case .dinner:    "DI"
        case .snack:     "SN"
        }
    }

    /// Chronological order within a day. Sort by this anywhere slots are listed —
    /// `unlocksAtMonths` is not a stand-in for it (breakfast and lunch both
    /// unlock at 0, so sorting by that leaves their order to chance).
    var displayOrder: Int {
        switch self {
        case .breakfast: 0
        case .lunch:     1
        case .snack:     2
        case .dinner:    3
        }
    }

    /// Months completed before this slot unlocks.
    ///
    /// Snack was left open as OQ-2 and is now 12, taken from the figure written
    /// into `Tasks/babytreat-meal-module-spec.md`. One line to change back.
    var unlocksAtMonths: Int? {
        switch self {
        case .breakfast, .lunch: 0
        case .dinner:            8
        case .snack:             12
        }
    }

    func isUnlocked(atAgeMonths months: Int) -> Bool {
        guard let unlocksAtMonths else { return false }
        return months >= unlocksAtMonths
    }
}

@Model
final class MenuEntry {
    /// Normalised to start-of-day so `date + slot` is a stable key.
    var date: Date
    var slotRaw: String
    var dish: String
    var foodIDs: [String]
    var recipeID: String?
    /// Marks the planned first exposure to a food — drives the "one new food per
    /// day" rule and the introduction history.
    var isNewFood: Bool
    /// Set by `MealPlanner`, cleared the moment the meal is edited by hand.
    /// Re-planning a week only throws away meals that still carry it.
    ///
    /// Optional so stores written before the planner existed migrate cleanly;
    /// read it through `wasGenerated`.
    var isGenerated: Bool?
    /// Set when this meal came from a cooked batch. Optional so older stores
    /// migrate cleanly. Two days off one batch each keep their own entry — this
    /// links them, it does not merge them.
    var batchID: String?

    init(
        date: Date,
        slot: MealSlot,
        dish: String,
        foodIDs: [String],
        recipeID: String? = nil,
        isNewFood: Bool = false,
        calendar: Calendar = .current
    ) {
        self.date = calendar.startOfDay(for: date)
        self.slotRaw = slot.rawValue
        self.dish = dish
        self.foodIDs = foodIDs
        self.recipeID = recipeID
        self.isNewFood = isNewFood
    }

    var slot: MealSlot {
        get { MealSlot(rawValue: slotRaw) ?? .lunch }
        set { slotRaw = newValue.rawValue }
    }

    var wasGenerated: Bool { isGenerated ?? false }

    /// Call from every edit path. A meal the caregiver has touched is theirs,
    /// and must survive a re-plan.
    func markEditedByHand() { isGenerated = false }
}
