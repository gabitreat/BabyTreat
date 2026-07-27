import Foundation

/// The meal-planning rule engine, ported from `design/baby-meal-planner.html`.
///
/// Every rule here is documented in `instructions/meal-planning/rules.md`, which
/// cites the prototype line it came from. Two thresholds are **heuristics, not
/// guidance** and are marked as such below — do not present them to a caregiver
/// as if WHO said them.
///
/// Deliberately free of SwiftData and SwiftUI so it can be reasoned about, and
/// eventually tested, on its own.
enum MealRules {

    // MARK: - Calendar

    /// Romanian weeks start Monday.
    static var calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2
        return cal
    }()

    static func startOfDay(_ date: Date) -> Date { calendar.startOfDay(for: date) }

    static func mondayOf(_ date: Date) -> Date {
        let day = startOfDay(date)
        // weekday: 1 = Sunday … 7 = Saturday
        let weekday = calendar.component(.weekday, from: day)
        let offset = (weekday + 5) % 7          // Monday -> 0, Sunday -> 6
        return calendar.date(byAdding: .day, value: -offset, to: day) ?? day
    }

    /// Which week a shopping list belongs to. Sunday is the planning day, so a
    /// list made on Sunday is for the week that *starts tomorrow*, not the week
    /// that is ending — `mondayOf` alone files it six days into the past.
    static func shoppingWeekStart(for date: Date) -> Date {
        let day = startOfDay(date)
        if calendar.component(.weekday, from: day) == 1 {    // Sunday
            return mondayOf(addDays(1, to: day))
        }
        return mondayOf(day)
    }

    static func addDays(_ count: Int, to date: Date) -> Date {
        calendar.date(byAdding: .day, value: count, to: date) ?? date
    }

    static func daysBetween(_ from: Date, _ to: Date) -> Int {
        calendar.dateComponents([.day], from: startOfDay(from), to: startOfDay(to)).day ?? 0
    }

    // MARK: - Age and slots

    /// Whole months completed. The "stages roll over on the 23rd" rule is not a
    /// separate rule — it falls straight out of a 23 December birth date.
    static func ageMonths(on date: Date, birthDate: Date) -> Int {
        max(0, calendar.dateComponents([.month], from: startOfDay(birthDate), to: startOfDay(date)).month ?? 0)
    }

    /// The date the next monthly stage begins.
    static func nextStageDate(after date: Date, birthDate: Date) -> Date {
        let months = ageMonths(on: date, birthDate: birthDate)
        return calendar.date(byAdding: .month, value: months + 1, to: startOfDay(birthDate)) ?? date
    }

    static func activeSlots(atAgeMonths months: Int) -> [MealSlot] {
        MealSlot.allCases.filter { $0.isUnlocked(atAgeMonths: months) }
    }

    // MARK: - Lunch composition

    /// Revised down after the WHO check: protein + vegetable + fat are required,
    /// **starch is optional**. Returns the missing components, empty if complete.
    static func lunchGaps(entry: MenuEntry, foodsByID: [String: Food]) -> [String] {
        let ids = entry.foodIDs
        guard !ids.isEmpty else { return [] }

        // The prototype credits fat when the dish names an oil, because a
        // teaspoon of olive oil is rarely modelled as its own food. The seed
        // dishes are English, so this matches "oil", not "ulei".
        let oilNamed = entry.dish.range(of: "oil", options: .caseInsensitive) != nil

        var missing: [String] = []
        if !has(.proteina, in: ids, foodsByID: foodsByID) { missing.append("protein") }
        if !has(.veg,      in: ids, foodsByID: foodsByID) { missing.append("vegetable") }
        if !oilNamed, !has(.grasime, in: ids, foodsByID: foodsByID) { missing.append("fat") }
        return missing
    }

    static func has(_ group: FoodGroup, in ids: [String], foodsByID: [String: Food]) -> Bool {
        ids.contains { foodsByID[$0]?.has(group) ?? false }
    }

    // MARK: - Weekly nutrition

    struct WeekNutrition {
        var days = 0
        /// Days with an animal-source food. Target: every day.
        var animalSource = 0
        /// Days with both fruit and vegetable. Target: every day.
        var fruitAndVeg = 0
        /// Days with an iron source. Target: every day.
        var iron = 0
        var meals = 0
        var starchMeals = 0
        var lunchGaps: [(date: Date, missing: [String])] = []

        var starchFreeMeals: Int { meals - starchMeals }
        var starchPercent: Int { meals == 0 ? 0 : Int((Double(starchMeals) / Double(meals) * 100).rounded()) }

        /// **Heuristic, not guidance.** WHO says to minimize starch without
        /// naming a number; this threshold was chosen, not derived.
        var meetsStarchTarget: Bool { starchFreeMeals >= 2 }
    }

    static func weekNutrition(
        entries: [MenuEntry],
        foodsByID: [String: Food],
        activeSlots: [MealSlot]
    ) -> WeekNutrition {
        var result = WeekNutrition()
        let byDay = Dictionary(grouping: entries) { startOfDay($0.date) }

        for (day, dayEntries) in byDay.sorted(by: { $0.key < $1.key }) {
            let slotted = dayEntries.filter { activeSlots.contains($0.slot) && !$0.foodIDs.isEmpty }
            guard !slotted.isEmpty else { continue }
            result.days += 1

            var hasAnimal = false, hasFruit = false, hasVeg = false, hasIron = false
            for entry in slotted {
                result.meals += 1
                let ids = entry.foodIDs
                if has(.amidon, in: ids, foodsByID: foodsByID) { result.starchMeals += 1 }
                if has(.asf,    in: ids, foodsByID: foodsByID) { hasAnimal = true }
                if has(.fruct,  in: ids, foodsByID: foodsByID) { hasFruit = true }
                if has(.veg,    in: ids, foodsByID: foodsByID) { hasVeg = true }
                if has(.fier,   in: ids, foodsByID: foodsByID) { hasIron = true }
            }
            if hasAnimal { result.animalSource += 1 }
            if hasFruit && hasVeg { result.fruitAndVeg += 1 }
            if hasIron { result.iron += 1 }

            if let lunch = slotted.first(where: { $0.slot == .lunch }) {
                let missing = lunchGaps(entry: lunch, foodsByID: foodsByID)
                if !missing.isEmpty { result.lunchGaps.append((date: day, missing: missing)) }
            }
        }
        return result
    }

    // MARK: - Allergen re-exposure

    /// Target interval between exposures, in days.
    static let allergenIntervalDays = 7

    struct AllergenState {
        let foodID: String
        /// Last exposure that actually happened — journal-confirmed, or the
        /// seeded baseline if nothing has been logged yet.
        let last: Date
        /// True when `last` came from the journal rather than the baseline.
        let isConfirmed: Bool
        /// Next planned-but-not-yet-eaten exposure.
        let next: Date?
        let daysSince: Int

        var isDue: Bool { daysSince >= allergenIntervalDays }
    }

    /// Counts from the **journal, not the plan**: a meal logged as refused does
    /// not reset the clock, and any amount actually eaten does (D-3).
    static func allergenState(
        foodID: String,
        baselineLast: Date,
        menu: [MenuEntry],
        logs: [MealLog],
        today: Date,
        activeSlots: [MealSlot]
    ) -> AllergenState {
        let today = startOfDay(today)
        var logIndex: [String: MealLog] = [:]
        for log in logs {
            logIndex["\(startOfDay(log.date).timeIntervalSince1970):\(log.slotRaw)"] = log
        }

        var last: Date?
        var next: Date?

        for entry in menu where activeSlots.contains(entry.slot) && entry.foodIDs.contains(foodID) {
            let day = startOfDay(entry.date)
            let key = "\(day.timeIntervalSince1970):\(entry.slotRaw)"
            let ate = logIndex[key]?.portion.countsAsExposure ?? false

            if day <= today, ate {
                if last == nil || day > last! { last = day }
            } else if day >= today, !ate {
                if next == nil || day < next! { next = day }
            }
        }

        let resolved = last ?? startOfDay(baselineLast)
        return AllergenState(
            foodID: foodID,
            last: resolved,
            isConfirmed: last != nil,
            next: next,
            daysSince: daysBetween(resolved, today)
        )
    }

    // MARK: - Introductions

    /// Every food ever marked as a new introduction, and the first date it was.
    static func introducedMap(menu: [MenuEntry]) -> [String: Date] {
        var out: [String: Date] = [:]
        for entry in menu where entry.isNewFood {
            let day = startOfDay(entry.date)
            for id in entry.foodIDs {
                if let existing = out[id], existing <= day { continue }
                out[id] = day
            }
        }
        return out
    }

    /// Proposes the next new food of a kind, ranked **in-season → priority flag
    /// → list order**. Foods under a hold are excluded until the hold lifts,
    /// which is what keeps dairy out of suggestions before 8 months.
    static func suggestNewFood(
        kind: FoodKind,
        on date: Date,
        foods: [Food],
        menu: [MenuEntry]
    ) -> Food? {
        let already = introducedMap(menu: menu)
        let day = startOfDay(date)

        let pool = foods.enumerated().filter { _, food in
            (food.kind == .veg || food.kind == .fruct)
                && food.kind == kind
                && food.status == .planned
                && already[food.id] == nil
                && !food.isHeld(on: day)
        }
        guard !pool.isEmpty else { return nil }

        return pool.min { lhs, rhs in
            let lSeason = lhs.element.isInSeason(on: day, calendar: calendar)
            let rSeason = rhs.element.isInSeason(on: day, calendar: calendar)
            if lSeason != rSeason { return lSeason }                       // in-season first
            if lhs.element.isPriority != rhs.element.isPriority {
                return lhs.element.isPriority                               // then priority
            }
            return lhs.offset < rhs.offset                                 // then list order
        }?.element
    }

    // MARK: - Rotation

    /// **Heuristic, not guidance.** Accepted foods should reappear inside this
    /// window; the number was chosen, not derived, and is largely untested with
    /// only a few weeks of menus seeded.
    static let rotationWindowDays = 14
    /// A food introduced within this many days is treated as still fragile.
    static let recentIntroductionDays = 42

    struct RotationFlag: Identifiable {
        var id: String { food.id }
        let food: Food
        let introducedOn: Date?
        /// Recently introduced — at real risk of being lost after one exposure.
        let isRecent: Bool
        let daysAbsent: Int?
    }

    /// Half one: accepted foods that have dropped out of the trailing window.
    static func rotationCheck(refDate: Date, foods: [Food], menu: [MenuEntry]) -> [RotationFlag] {
        let to = startOfDay(refDate)
        let from = addDays(-(rotationWindowDays - 1), to: to)

        var seen = Set<String>()
        var lastSeen: [String: Date] = [:]
        for entry in menu {
            let day = startOfDay(entry.date)
            guard day >= from, day <= to else {
                // Track the last appearance outside the window too, so the UI can
                // say *how long* a food has been missing rather than just "> 14d".
                if day < from {
                    for id in entry.foodIDs where lastSeen[id] == nil || lastSeen[id]! < day {
                        lastSeen[id] = day
                    }
                }
                continue
            }
            entry.foodIDs.forEach { seen.insert($0) }
        }

        let introduced = introducedMap(menu: menu)
        return foods
            .filter { $0.status == .accepted && !seen.contains($0.id) }
            .map { food in
                let intro = introduced[food.id]
                return RotationFlag(
                    food: food,
                    introducedOn: intro,
                    isRecent: intro.map { daysBetween($0, to) <= recentIntroductionDays } ?? false,
                    daysAbsent: lastSeen[food.id].map { daysBetween($0, to) }
                )
            }
            .sorted { lhs, rhs in
                if lhs.isRecent != rhs.isRecent { return lhs.isRecent }
                return (lhs.daysAbsent ?? .max) > (rhs.daysAbsent ?? .max)
            }
    }

    /// Half two, the active one (D-4): which tolerated foods to put **back into**
    /// the week being planned, before they cross the threshold.
    ///
    /// Detection alone only told you after you had already planned the week
    /// wrong. Foods already scheduled that week are suppressed, so this never
    /// proposes a duplicate.
    static func rotationReturns(weekStart: Date, foods: [Food], menu: [MenuEntry]) -> [RotationFlag] {
        let start = mondayOf(weekStart)
        let end = addDays(6, to: start)

        var scheduledThisWeek = Set<String>()
        for entry in menu {
            let day = startOfDay(entry.date)
            if day >= start, day <= end { entry.foodIDs.forEach { scheduledThisWeek.insert($0) } }
        }

        return rotationCheck(refDate: start, foods: foods, menu: menu)
            .filter { !scheduledThisWeek.contains($0.food.id) }
    }

    // MARK: - Weekly introduction targets

    struct WeekIntroductions {
        let newVegetable: Food?
        let newFruit: Food?
        /// Days carrying more than one new food — violates "one new food per day".
        let crowdedDays: [Date]
    }

    /// One new vegetable + one new fruit per week where possible, at most one new
    /// food per day.
    static func introductions(
        weekStart: Date,
        foods: [Food],
        foodsByID: [String: Food],
        menu: [MenuEntry]
    ) -> WeekIntroductions {
        let start = mondayOf(weekStart)
        let end = addDays(6, to: start)
        let inWeek = menu.filter {
            let day = startOfDay($0.date)
            return day >= start && day <= end && $0.isNewFood
        }

        var newVeg: Food?
        var newFruit: Food?
        for entry in inWeek {
            for id in entry.foodIDs {
                guard let food = foodsByID[id] else { continue }
                if food.kind == .veg, newVeg == nil { newVeg = food }
                if food.kind == .fruct, newFruit == nil { newFruit = food }
            }
        }

        // One new food per day means one *new-food meal* per day. Counting the
        // foods inside the meal would flag every introduction, since a new food
        // is served alongside familiar ones ("Mango + ovăz" is one introduction).
        let crowded = Dictionary(grouping: inWeek) { startOfDay($0.date) }
            .filter { _, entries in entries.count > 1 }
            .keys
            .sorted()

        return WeekIntroductions(newVegetable: newVeg, newFruit: newFruit, crowdedDays: Array(crowded))
    }

    // MARK: - Shopping

    /// Every food the week's menu actually calls for, with how many meals it
    /// appears in, in first-appearance order.
    ///
    /// The shopping list has to be derived from the plan rather than fixed, or
    /// it silently omits exactly the foods that need buying — the new
    /// introductions, which by definition were never on last week's list.
    static func foodsUsed(weekStart: Date, menu: [MenuEntry]) -> [(id: String, meals: Int)] {
        let start = mondayOf(weekStart)
        let end = addDays(6, to: start)

        var order: [String] = []
        var counts: [String: Int] = [:]
        for entry in menu.sorted(by: { ($0.date, $0.slot.displayOrder) < ($1.date, $1.slot.displayOrder) }) {
            let day = startOfDay(entry.date)
            guard day >= start, day <= end else { continue }
            for id in entry.foodIDs {
                if counts[id] == nil { order.append(id) }
                counts[id, default: 0] += 1
            }
        }
        return order.map { (id: $0, meals: counts[$0] ?? 0) }
    }

    // MARK: - Protein rotation

    static let rotationProteins = ["pui", "curcan", "somon", "vita", "ou", "linte"]

    /// Proteins used in a week, in menu order — used to show the rotation spread.
    static func proteinsUsed(weekStart: Date, menu: [MenuEntry]) -> [String] {
        let start = mondayOf(weekStart)
        let end = addDays(6, to: start)
        var used: [String] = []
        for entry in menu.sorted(by: { $0.date < $1.date }) {
            let day = startOfDay(entry.date)
            guard day >= start, day <= end else { continue }
            for id in entry.foodIDs where rotationProteins.contains(id) && !used.contains(id) {
                used.append(id)
            }
        }
        return used
    }
}
