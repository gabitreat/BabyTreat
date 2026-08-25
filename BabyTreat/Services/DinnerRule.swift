import Foundation

/// "At eight months, dinner is soup."
///
/// A **household preference**, not a clinical rule — which is why this filters
/// suggestions and never blocks a log. If a non-soup dinner was actually eaten,
/// it gets recorded as eaten. The journal reflects reality, not the plan.
enum DinnerRule {

    /// One month's dinner shape. Adding another month means adding a window
    /// here, not touching the engine.
    struct Window: Equatable {
        let slot: MealSlot
        /// Inclusive.
        let fromMonths: Int
        /// Exclusive.
        let toMonths: Int
        let forms: Set<MealForm>
        /// Shown on the planner so the reason is visible where the rule bites.
        let note: String

        func applies(slot: MealSlot, ageMonths: Int) -> Bool {
            self.slot == slot && ageMonths >= fromMonths && ageMonths < toMonths
        }
    }

    /// The whole tunable surface. Month 8 is the only window today.
    static let windows: [Window] = [
        Window(slot: .dinner, fromMonths: 8, toMonths: 9, forms: [.soup],
               note: "Month 8: dinner is soup.")
    ]

    static func window(for slot: MealSlot, ageMonths: Int) -> Window? {
        windows.first { $0.applies(slot: slot, ageMonths: ageMonths) }
    }

    /// The forms suggestions should be limited to, or nil when nothing applies.
    static func allowedForms(slot: MealSlot, ageMonths: Int) -> Set<MealForm>? {
        window(for: slot, ageMonths: ageMonths)?.forms
    }

    /// Filters a list of recipes down to what should be *suggested* for a slot.
    ///
    /// A recipe with no form set is left out when a window applies — unknown is
    /// not "probably a soup". Outside a window nothing is filtered.
    static func suggestions(from recipes: [Recipe], slot: MealSlot, ageMonths: Int) -> [Recipe] {
        let ageAppropriate = recipes.filter { $0.minAgeMonths <= ageMonths }
        guard let forms = allowedForms(slot: slot, ageMonths: ageMonths) else { return ageAppropriate }
        return ageAppropriate.filter { recipe in
            guard let form = recipe.form else { return false }
            return forms.contains(form)
        }
    }

    /// True when a manual choice sits outside the window. The UI says so quietly
    /// and still saves it — this is a note, never a refusal.
    static func isOffPlan(_ recipe: Recipe, slot: MealSlot, ageMonths: Int) -> Bool {
        guard let forms = allowedForms(slot: slot, ageMonths: ageMonths) else { return false }
        guard let form = recipe.form else { return true }
        return !forms.contains(form)
    }

    // MARK: - Texture progression

    /// Soup-only dinners are fine, but the rest of the day has to keep moving
    /// toward lumps and finger food. By eight months that progression matters,
    /// so the planner says so rather than letting a week of purée pass quietly.
    static let textureReminder =
        "Dinner stays liquid this month — that's your choice, not a rule. " +
        "Keep breakfast and lunch moving toward lumpier textures and finger foods."

    /// Whether the week's non-dinner meals include anything that asks for chewing.
    static func needsTextureNudge(recipes: [Recipe], ageMonths: Int) -> Bool {
        guard ageMonths >= 8 else { return false }
        guard !recipes.isEmpty else { return false }
        return !recipes.contains { $0.form?.advancesTexture == true }
    }
}
