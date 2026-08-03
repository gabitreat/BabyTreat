import Foundation
import SwiftData

/// Builds a week of meals out of the rules that already exist in `MealRules` —
/// it adds no new nutrition rules of its own. Everything it does is one of:
///
/// - one new vegetable + one new fruit a week, at most one new food a day
///   (`suggestNewFood`, `introductions`)
/// - allergens re-exposed on a 7-day loop, counted off the journal
///   (`allergenState`)
/// - protein rotation across the six rotation proteins (`rotationProteins`)
/// - accepted foods brought back before they fall out of the 14-day window
///   (`rotationReturns`)
/// - lunch = protein + vegetable + fat, starch optional (`lunchGaps`)
/// - animal-source food, fruit + vegetable, and an iron source every day
///   (`weekNutrition`)
///
/// It is deliberately **deterministic**: the same inputs give the same week, so
/// a plan can be reasoned about and re-derived. It only ever fills slots that
/// are empty — a meal that was written or edited by hand is never touched.
///
/// Free of SwiftUI. The `ModelContext` wrappers at the bottom are the only part
/// that touches storage.
enum MealPlanner {

    // MARK: - Output

    struct PlannedMeal {
        let date: Date
        let slot: MealSlot
        let dish: String
        let foodIDs: [String]
        let recipeID: String?
        let isNewFood: Bool
    }

    struct Plan {
        let weekStart: Date
        let meals: [PlannedMeal]
        /// Plain-language account of what the planner did, and why. Shown to the
        /// caregiver — a plan they cannot interrogate is a plan they cannot trust.
        let notes: [String]
        var isEmpty: Bool { meals.isEmpty }
    }

    /// **Heuristic, not guidance.** `weekNutrition` asks for at least two
    /// starch-free meals a week; every breakfast here is cereal-based, so the
    /// lunches have to supply them. Three leaves one meal of margin for an
    /// improvised swap.
    static let starchFreeLunchTarget = 3

    /// The day of the week a new food is first offered — Monday is shopping day,
    /// so the first introduction waits for Tuesday.
    private static let firstIntroductionDay = 1
    /// Days to leave between the two introductions of a week.
    private static let introductionSpacing = 3

    // MARK: - The planner

    static func plan(
        weekStart: Date,
        birthDate: Date,
        foods: [Food],
        recipes: [Recipe],
        menu: [MenuEntry],
        logs: [MealLog]
    ) -> Plan {
        let start = MealRules.mondayOf(weekStart)
        let days = (0..<7).map { MealRules.addDays($0, to: start) }
        let months = MealRules.ageMonths(on: start, birthDate: birthDate)
        let slots = MealRules.activeSlots(atAgeMonths: months)
        let foodsByID = Dictionary(foods.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let introduced = MealRules.introducedMap(menu: menu)

        // Slots already planned. These are never overwritten, but they do count
        // towards the week — a hand-written salmon lunch is still a salmon lunch.
        var occupied: [Int: [MealSlot: MenuEntry]] = [:]
        for entry in menu {
            guard let index = days.firstIndex(of: MealRules.startOfDay(entry.date)) else { continue }
            occupied[index, default: [:]][entry.slot] = entry
        }

        // When each food was last served, from everything before this week.
        var lastServed: [String: Date] = [:]
        for entry in menu {
            let day = MealRules.startOfDay(entry.date)
            guard day < start else { continue }
            for id in entry.foodIDs where (lastServed[id] ?? .distantPast) < day {
                lastServed[id] = day
            }
        }

        /// Nothing may be served while it is on hold, or before its retry date —
        /// this is what keeps dairy out until the APLV question is settled, and
        /// mango out until 17 August.
        func isAvailable(_ food: Food, on day: Date) -> Bool {
            if food.isHeld(on: day) { return false }
            if let retry = food.retryOn, day < MealRules.startOfDay(retry) { return false }
            return true
        }

        /// Everyday cooking additionally needs the food to have been met before.
        /// Beef and cauliflower are still filed as "planned" but have been
        /// eaten — those belong in the pool. A food nobody has tried yet only
        /// ever arrives as *the* introduction of the week, which goes through
        /// `isAvailable` instead.
        func canPlan(_ food: Food, on day: Date) -> Bool {
            isAvailable(food, on: day) && (food.status != .planned || introduced[food.id] != nil)
        }

        // MARK: Allergen days

        // Each allergen gets the day its 7-day loop falls due, clamped into the
        // week, and no two share a day — a reaction has to be attributable.
        var allergenDay: [String: Int] = [:]
        var claimed = Set<Int>()
        let dueDates = foods
            .filter { $0.isAllergen && canPlan($0, on: start) }
            .map { food -> (food: Food, due: Date) in
                let state = MealRules.allergenState(
                    foodID: food.id,
                    baselineLast: MealSeed.allergenBaselines[food.id] ?? start,
                    menu: menu,
                    logs: logs,
                    today: start,
                    activeSlots: slots
                )
                return (food, MealRules.addDays(MealRules.allergenIntervalDays, to: state.last))
            }
            .sorted { $0.due < $1.due }

        for (food, due) in dueDates {
            let wanted = min(max(MealRules.daysBetween(start, due), 0), 6)
            guard let index = freeDay(from: wanted, avoiding: claimed) else { continue }
            allergenDay[food.id] = index
            claimed.insert(index)
        }

        // MARK: New food days

        let newVegetable = MealRules.suggestNewFood(kind: .veg, on: start, foods: foods, menu: menu)
        let newFruit = MealRules.suggestNewFood(kind: .fruct, on: start, foods: foods, menu: menu)

        // Spaced apart, and kept off allergen days where possible so that one
        // day never carries two things that could explain a reaction.
        var introductionDay: [String: Int] = [:]
        var introductionsClaimed = Set<Int>()
        for food in [newVegetable, newFruit].compactMap({ $0 }) {
            let preferred = introductionsClaimed.isEmpty
                ? firstIntroductionDay
                : (introductionsClaimed.max() ?? 0) + introductionSpacing
            let index = freeDay(from: preferred, avoiding: introductionsClaimed.union(claimed))
                ?? freeDay(from: preferred, avoiding: introductionsClaimed)
                ?? 0
            introductionDay[food.id] = index
            introductionsClaimed.insert(index)
        }

        // MARK: Protein rotation

        var proteinForDay: [Int: String] = [:]
        for (id, index) in allergenDay where MealRules.rotationProteins.contains(id) {
            proteinForDay[index] = id
        }

        let rotation = MealRules.rotationProteins
            .compactMap { foodsByID[$0] }
            .filter { canPlan($0, on: start) && !proteinForDay.values.contains($0.id) }

        // Spread first, longest-unserved next. With six rotation proteins over
        // seven lunches one has to come round twice — this makes that the one
        // longest away, rather than whichever the cycle happened to land on.
        var proteinUses: [String: Int] = [:]
        for index in 0..<7 where proteinForDay[index] == nil {
            let candidates = rotation.filter { $0.id != proteinForDay[index - 1] }
            let pick = (candidates.isEmpty ? rotation : candidates).min { lhs, rhs in
                let usedLeft = proteinUses[lhs.id] ?? 0, usedRight = proteinUses[rhs.id] ?? 0
                if usedLeft != usedRight { return usedLeft < usedRight }
                return (lastServed[lhs.id] ?? .distantPast) < (lastServed[rhs.id] ?? .distantPast)
            }
            guard let pick else { break }
            proteinForDay[index] = pick.id
            proteinUses[pick.id, default: 0] += 1
        }

        // MARK: Starch-free lunches

        // Midweek by preference, so the starch-free days are spread out. A
        // lentil lunch is never one of them — lentils are a starch in their own
        // right, and pretending otherwise would flatter the count.
        var starchFree = Set<Int>()
        for index in [1, 3, 5, 0, 2, 4, 6] where starchFree.count < starchFreeLunchTarget {
            if proteinForDay[index] == "linte" { continue }
            starchFree.insert(index)
        }

        // MARK: Pools

        let vegetables = foods.filter { $0.has(.veg) && !$0.has(.proteina) }
        let leafyVegetables = vegetables.filter { !$0.has(.amidon) }
        let starches = foods.filter { $0.has(.amidon) && $0.kind == .veg }
        let fruit = foods.filter { $0.kind == .fruct }
        let cereals = foods.filter { $0.kind == .cereale && $0.has(.amidon) }
        let animalSource = foods.filter { $0.has(.asf) && $0.has(.proteina) }

        // How often each food has been used *in this generated week*, and on
        // which day last — both feed the ranking below.
        var timesUsed: [String: Int] = [:]
        var servedOnDay: [String: Int] = [:]
        let returning = Set(MealRules.rotationReturns(weekStart: start, foods: foods, menu: menu).map(\.food.id))

        // Everything already on the week's hand-written meals counts as used.
        for (index, entries) in occupied {
            for entry in entries.values {
                for id in entry.foodIDs {
                    timesUsed[id, default: 0] += 1
                    servedOnDay[id] = max(servedOnDay[id] ?? index, index)
                }
            }
        }

        /// Spread first, then rescue what is dropping out of rotation, then
        /// whatever has gone longest without appearing.
        func ranked(_ lhs: Food, _ rhs: Food) -> Bool {
            let usedLeft = timesUsed[lhs.id] ?? 0, usedRight = timesUsed[rhs.id] ?? 0
            if usedLeft != usedRight { return usedLeft < usedRight }
            let returnsLeft = returning.contains(lhs.id), returnsRight = returning.contains(rhs.id)
            if returnsLeft != returnsRight { return returnsLeft }
            let seenLeft = lastServed[lhs.id] ?? .distantPast, seenRight = lastServed[rhs.id] ?? .distantPast
            if seenLeft != seenRight { return seenLeft < seenRight }
            return lhs.name < rhs.name
        }

        func choose(from pool: [Food], dayIndex: Int, excluding used: Set<String>) -> Food? {
            let allowed = pool.filter { !used.contains($0.id) && canPlan($0, on: days[dayIndex]) }
            let notYesterdays = allowed.filter { servedOnDay[$0.id] != dayIndex - 1 }
            return (notYesterdays.isEmpty ? allowed : notYesterdays).min(by: ranked)
        }

        func record(_ id: String, dayIndex: Int) {
            timesUsed[id, default: 0] += 1
            servedOnDay[id] = dayIndex
        }

        /// A recipe fits when every food it needs is in the meal. Single-food
        /// recipes are skipped: the coconut porridge lists only oats, so it
        /// would attach itself to every oat breakfast and quietly blow past the
        /// "coconut milk 1–2 times a week" limit.
        func recipe(for ids: [String]) -> String? {
            let inMeal = Set(ids)
            return recipes
                .filter { $0.minAgeMonths <= months && $0.foodIDs.count >= 2 && Set($0.foodIDs).isSubset(of: inMeal) }
                .max { Set($0.foodIDs).count < Set($1.foodIDs).count }?
                .id
        }

        func name(_ ids: [String]) -> String {
            ids.compactMap { foodsByID[$0]?.name }.joined(separator: " + ")
        }

        // MARK: Build the week

        var meals: [PlannedMeal] = []
        var introducedThisWeek: [(food: Food, day: Date)] = []

        for index in 0..<7 {
            let day = days[index]
            var lunchIDs: [String] = []
            var lunchIsNew = false

            // ---- Lunch ----
            if slots.contains(.lunch), occupied[index]?[.lunch] == nil {
                if let proteinID = proteinForDay[index], let protein = foodsByID[proteinID] {
                    lunchIDs.append(proteinID)
                    record(proteinID, dayIndex: index)

                    // Lentils are the one rotation protein that is not an
                    // animal-source food, and WHO asks for one every day — so a
                    // lentil lunch gets a meat alongside it. Allergens are kept
                    // out of this slot: an extra egg outside its own day would
                    // muddle the exposure the allergen loop is counting.
                    if !protein.has(.asf),
                       let partner = choose(from: animalSource.filter { !$0.isAllergen },
                                            dayIndex: index, excluding: Set(lunchIDs))
                           ?? choose(from: animalSource, dayIndex: index, excluding: Set(lunchIDs)) {
                        lunchIDs.append(partner.id)
                        record(partner.id, dayIndex: index)
                    }
                }

                var vegetablesWanted = starchFree.contains(index) ? 2 : 1

                if let newVegetable, introductionDay[newVegetable.id] == index, isAvailable(newVegetable, on: day) {
                    lunchIDs.append(newVegetable.id)
                    record(newVegetable.id, dayIndex: index)
                    vegetablesWanted -= 1
                    lunchIsNew = true
                    introducedThisWeek.append((newVegetable, day))
                }

                while vegetablesWanted > 0 {
                    guard let pick = choose(from: leafyVegetables, dayIndex: index, excluding: Set(lunchIDs)) else { break }
                    lunchIDs.append(pick.id)
                    record(pick.id, dayIndex: index)
                    vegetablesWanted -= 1
                }

                if !starchFree.contains(index), proteinForDay[index] != "linte",
                   let starch = choose(from: starches, dayIndex: index, excluding: Set(lunchIDs)) {
                    lunchIDs.append(starch.id)
                    record(starch.id, dayIndex: index)
                }

                if !lunchIDs.isEmpty {
                    // The fat requirement is met by a fatty food, or by naming an
                    // oil in the dish — see MealRules.lunchGaps.
                    let hasFat = lunchIDs.contains { foodsByID[$0]?.has(.grasime) == true }
                    let dish = name(lunchIDs) + (hasFat ? "" : " + olive oil")
                    meals.append(
                        PlannedMeal(date: day, slot: .lunch, dish: dish, foodIDs: lunchIDs,
                                    recipeID: recipe(for: lunchIDs), isNewFood: lunchIsNew)
                    )
                }
            } else if let planned = occupied[index]?[.lunch] {
                lunchIDs = planned.foodIDs
            }

            // ---- Breakfast ----
            if slots.contains(.breakfast), occupied[index]?[.breakfast] == nil {
                var breakfastIDs: [String] = []
                var breakfastIsNew = false

                // Iron every day. Salmon is the one rotation protein without
                // it, so on a salmon day the iron-fortified cereal carries it.
                let lunchHasIron = lunchIDs.contains { foodsByID[$0]?.has(.fier) == true }
                let ironCereal = lunchHasIron ? nil : cereals.filter { $0.has(.fier) }
                    .first { canPlan($0, on: day) }
                if let cereal = ironCereal ?? choose(from: cereals, dayIndex: index, excluding: []) {
                    breakfastIDs.append(cereal.id)
                    record(cereal.id, dayIndex: index)
                }

                let peanutDay = allergenDay["arahide"] == index
                if let newFruit, introductionDay[newFruit.id] == index, isAvailable(newFruit, on: day) {
                    breakfastIDs.append(newFruit.id)
                    record(newFruit.id, dayIndex: index)
                    breakfastIsNew = true
                    introducedThisWeek.append((newFruit, day))
                } else if peanutDay, let banana = foodsByID["banana"], canPlan(banana, on: day) {
                    // Peanut butter dissolves into a banana porridge — that is
                    // the shape recipe r6 already describes.
                    breakfastIDs.append(banana.id)
                    record(banana.id, dayIndex: index)
                } else if let pick = choose(from: fruit, dayIndex: index, excluding: Set(breakfastIDs)) {
                    breakfastIDs.append(pick.id)
                    record(pick.id, dayIndex: index)
                }

                if peanutDay, let peanut = foodsByID["arahide"], canPlan(peanut, on: day) {
                    breakfastIDs.append(peanut.id)
                    record(peanut.id, dayIndex: index)
                }

                if !breakfastIDs.isEmpty {
                    meals.append(
                        PlannedMeal(date: day, slot: .breakfast, dish: name(breakfastIDs), foodIDs: breakfastIDs,
                                    recipeID: recipe(for: breakfastIDs), isNewFood: breakfastIsNew)
                    )
                }
            }

            // ---- Dinner ----
            // Only the lunch composition is specified in rules.md, so dinner is
            // kept deliberately plain: a vegetable and a starch, distinct from
            // lunch. The day's protein and animal-source food come from lunch.
            if slots.contains(.dinner), occupied[index]?[.dinner] == nil {
                var dinnerIDs: [String] = []
                if let vegetable = choose(from: leafyVegetables, dayIndex: index, excluding: Set(lunchIDs)) {
                    dinnerIDs.append(vegetable.id)
                    record(vegetable.id, dayIndex: index)
                }
                if let starch = choose(from: starches, dayIndex: index, excluding: Set(lunchIDs + dinnerIDs)) {
                    dinnerIDs.append(starch.id)
                    record(starch.id, dayIndex: index)
                }
                if !dinnerIDs.isEmpty {
                    let hasFat = dinnerIDs.contains { foodsByID[$0]?.has(.grasime) == true }
                    meals.append(
                        PlannedMeal(date: day, slot: .dinner, dish: name(dinnerIDs) + (hasFat ? "" : " + olive oil"),
                                    foodIDs: dinnerIDs, recipeID: recipe(for: dinnerIDs), isNewFood: false)
                    )
                }
            }
        }

        return Plan(
            weekStart: start,
            meals: meals,
            notes: notes(
                meals: meals,
                introduced: introducedThisWeek,
                allergenDay: allergenDay,
                days: days,
                foods: foods,
                foodsByID: foodsByID,
                returning: returning,
                menu: menu,
                slots: slots
            )
        )
    }

    // MARK: - Explanation

    private static func notes(
        meals: [PlannedMeal],
        introduced: [(food: Food, day: Date)],
        allergenDay: [String: Int],
        days: [Date],
        foods: [Food],
        foodsByID: [String: Food],
        returning: Set<String>,
        menu: [MenuEntry],
        slots: [MealSlot]
    ) -> [String] {
        var notes: [String] = []

        for (food, day) in introduced {
            notes.append("New \(food.kind == .veg ? "vegetable" : "fruit"): \(food.name) on \(day.mealDayLabel)")
        }

        let allergens = allergenDay
            .compactMap { id, index -> (String, Int)? in foodsByID[id].map { ($0.name, index) } }
            .sorted { $0.1 < $1.1 }
        if !allergens.isEmpty {
            let listed = allergens.map { "\($0.0) \(days[$0.1].mealDayLabel)" }.joined(separator: ", ")
            notes.append("Allergen loop: \(listed)")
        }

        let proteins = meals
            .flatMap(\.foodIDs)
            .filter { MealRules.rotationProteins.contains($0) }
            .reduce(into: [String]()) { list, id in if !list.contains(id) { list.append(id) } }
        if !proteins.isEmpty {
            notes.append("Proteins: \(proteins.compactMap { foodsByID[$0]?.name }.joined(separator: ", "))")
        }

        let broughtBack = Set(meals.flatMap(\.foodIDs).filter { returning.contains($0) })
        if !broughtBack.isEmpty {
            // After a long gap in the menu this can be most of the pantry, so
            // name a few and count the rest.
            let names = broughtBack.compactMap { foodsByID[$0]?.name }.sorted()
            let shown = names.prefix(5).joined(separator: ", ")
            notes.append("Back in rotation: \(shown)" + (names.count > 5 ? " and \(names.count - 5) more" : ""))
        }

        // Verify the finished week against the same checks the Week tab shows,
        // rather than asserting it is correct because the rules were followed.
        let probes = meals.map {
            MenuEntry(date: $0.date, slot: $0.slot, dish: $0.dish, foodIDs: $0.foodIDs,
                      recipeID: $0.recipeID, isNewFood: $0.isNewFood, calendar: MealRules.calendar)
        }
        let inWeek = menu.filter { days.contains(MealRules.startOfDay($0.date)) }
        let nutrition = MealRules.weekNutrition(entries: probes + inWeek, foodsByID: foodsByID, activeSlots: slots)

        var gaps: [String] = []
        if nutrition.days > 0, nutrition.animalSource < nutrition.days { gaps.append("animal-source food") }
        if nutrition.days > 0, nutrition.fruitAndVeg < nutrition.days { gaps.append("fruit and vegetable") }
        if nutrition.days > 0, nutrition.iron < nutrition.days { gaps.append("iron") }
        if !nutrition.meetsStarchTarget { gaps.append("starch-free meals") }
        if !nutrition.lunchGaps.isEmpty { gaps.append("lunch composition") }

        notes.append(gaps.isEmpty
            ? "\(nutrition.starchFreeMeals) starch-free meals · every daily target met"
            : "Not covered on its own: \(gaps.joined(separator: ", "))")

        return notes
    }

    /// First unclaimed day at or after `wanted`, then working backwards.
    private static func freeDay(from wanted: Int, avoiding claimed: Set<Int>) -> Int? {
        for index in wanted..<7 where !claimed.contains(index) { return index }
        for index in stride(from: wanted - 1, through: 0, by: -1) where !claimed.contains(index) { return index }
        return nil
    }

    // MARK: - Storage

    /// Plans the week from what is currently in the store. Fetching rather than
    /// taking a `@Query` snapshot matters: after deleting the previous auto-plan
    /// the view's arrays are still stale, and the planner would treat the week
    /// as full.
    @MainActor
    static func plan(weekStart: Date, birthDate: Date, in context: ModelContext) -> Plan {
        let foods = (try? context.fetch(FetchDescriptor<Food>())) ?? []
        let recipes = (try? context.fetch(FetchDescriptor<Recipe>())) ?? []
        let menu = (try? context.fetch(FetchDescriptor<MenuEntry>())) ?? []
        let logs = (try? context.fetch(FetchDescriptor<MealLog>())) ?? []
        return plan(weekStart: weekStart, birthDate: birthDate,
                    foods: foods, recipes: recipes, menu: menu, logs: logs)
    }

    @MainActor
    @discardableResult
    static func apply(_ plan: Plan, in context: ModelContext) -> Int {
        for meal in plan.meals {
            let entry = MenuEntry(date: meal.date, slot: meal.slot, dish: meal.dish, foodIDs: meal.foodIDs,
                                  recipeID: meal.recipeID, isNewFood: meal.isNewFood, calendar: MealRules.calendar)
            entry.isGenerated = true
            context.insert(entry)
        }
        try? context.save()
        return plan.meals.count
    }

    /// Fills every empty slot in the week.
    @MainActor
    @discardableResult
    static func fill(weekStart: Date, birthDate: Date, in context: ModelContext) -> Plan {
        let plan = plan(weekStart: weekStart, birthDate: birthDate, in: context)
        apply(plan, in: context)
        return plan
    }

    /// Throws away what the planner produced last time and plans again. Meals
    /// that were written or edited by hand survive — the flag is cleared the
    /// moment one is edited, which is exactly what makes this safe to press.
    @MainActor
    @discardableResult
    static func replan(weekStart: Date, birthDate: Date, in context: ModelContext) -> Plan {
        let start = MealRules.mondayOf(weekStart)
        let end = MealRules.addDays(6, to: start)
        let existing = (try? context.fetch(FetchDescriptor<MenuEntry>())) ?? []
        for entry in existing where entry.wasGenerated {
            let day = MealRules.startOfDay(entry.date)
            if day >= start, day <= end { context.delete(entry) }
        }
        try? context.save()
        return fill(weekStart: start, birthDate: birthDate, in: context)
    }

    private static let autoPlannedKey = "mealAutoPlannedWeek"

    /// Runs when the Meals section opens. Plans the week that is coming — which
    /// from Sunday onwards is next week, the same turnover the shopping list
    /// uses — but only when that week is completely empty, and only once per
    /// week. A week the caregiver deliberately cleared stays cleared.
    @MainActor
    @discardableResult
    static func autoPlanIfNeeded(birthDate: Date, in context: ModelContext) -> Plan? {
        let week = MealRules.planningWeekStart(for: .now)
        let stamp = UserDefaults.standard.double(forKey: autoPlannedKey)
        guard stamp != week.timeIntervalSince1970 else { return nil }

        let months = MealRules.ageMonths(on: week, birthDate: birthDate)
        let slots = MealRules.activeSlots(atAgeMonths: months)
        let end = MealRules.addDays(6, to: week)
        let existing = (try? context.fetch(FetchDescriptor<MenuEntry>())) ?? []
        let alreadyPlanned = existing.contains { entry in
            let day = MealRules.startOfDay(entry.date)
            return day >= week && day <= end && slots.contains(entry.slot)
        }
        guard !alreadyPlanned else {
            UserDefaults.standard.set(week.timeIntervalSince1970, forKey: autoPlannedKey)
            return nil
        }

        let plan = fill(weekStart: week, birthDate: birthDate, in: context)
        UserDefaults.standard.set(week.timeIntervalSince1970, forKey: autoPlannedKey)
        return plan.isEmpty ? nil : plan
    }
}
