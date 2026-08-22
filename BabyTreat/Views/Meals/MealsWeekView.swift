import SwiftUI
import SwiftData

struct MealsWeekView: View {
    let birthDate: Date

    @Environment(\.modelContext) private var modelContext
    @Query private var foods: [Food]
    @Query private var menu: [MenuEntry]
    @Query private var recipes: [Recipe]

    @State private var weekOffset = 0
    @State private var editTarget: MealEditTarget?
    /// What the planner did, last time it was asked. Cleared once it is read.
    @State private var planNotes: [String] = []

    private var today: Date { MealRules.startOfDay(.now) }
    /// Opens on the week being planned *for*, which from Sunday is next week —
    /// the same turnover the shopping list uses.
    private var weekStart: Date { MealRules.addDays(weekOffset * 7, to: MealRules.planningWeekStart(for: today)) }
    private var weekEnd: Date { MealRules.addDays(6, to: weekStart) }
    private var months: Int { MealRules.ageMonths(on: weekStart, birthDate: birthDate) }
    private var activeSlots: [MealSlot] { MealRules.activeSlots(atAgeMonths: months) }
    private var foodsByID: [String: Food] { Dictionary(foods.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a }) }

    private var weekEntries: [MenuEntry] {
        menu.filter {
            let day = MealRules.startOfDay($0.date)
            return day >= weekStart && day <= weekEnd
        }
    }

    private var nutrition: MealRules.WeekNutrition {
        MealRules.weekNutrition(entries: weekEntries, foodsByID: foodsByID, activeSlots: activeSlots)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                weekPicker
                planner
                proposals
                nutritionSummary
                days
            }
            .padding(.horizontal, MealTheme.pad)
            .padding(.vertical, 20)
        }
        .onChange(of: weekOffset) { planNotes = [] }
        .sheet(item: $editTarget) { target in
            MealEditSheet(
                date: target.date,
                slot: target.slot,
                existing: target.entry,
                foods: foods,
                recipes: recipes,
                ageMonths: months,
                onSave: { dish, foodIDs, recipeID, isNew in
                    if let entry = target.entry {
                        entry.dish = dish
                        entry.foodIDs = foodIDs
                        entry.recipeID = recipeID
                        entry.isNewFood = isNew
                        entry.markEditedByHand()
                    } else {
                        modelContext.insert(
                            MenuEntry(date: target.date, slot: target.slot, dish: dish, foodIDs: foodIDs,
                                      recipeID: recipeID, isNewFood: isNew, calendar: MealRules.calendar)
                        )
                    }
                    try? modelContext.save()
                },
                onDelete: target.entry.map { entry in
                    { modelContext.delete(entry); try? modelContext.save() }
                }
            )
        }
    }

    // MARK: - Week picker

    private var weekPicker: some View {
        HStack {
            Button { weekOffset -= 1 } label: { Image(systemName: "chevron.left") }
            Spacer()
            VStack(spacing: 2) {
                Text("\(weekStart.mealDayLabel) – \(weekEnd.mealDayLabel)")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(MealTheme.ink)
                if let caption = weekCaption {
                    Text(caption)
                        .font(.system(size: 11.5))
                        .foregroundStyle(MealTheme.muted)
                }
            }
            Spacer()
            Button { weekOffset += 1 } label: { Image(systemName: "chevron.right") }
        }
        .foregroundStyle(MealTheme.lagoon)
    }

    /// On Sunday the tab already shows next week, so "current week" would be a
    /// lie — say which week it is instead.
    private var weekCaption: String? {
        if weekStart == MealRules.mondayOf(today) { return "current week" }
        if weekOffset == 0 { return "the week ahead" }
        return nil
    }

    // MARK: - Planner

    /// Empty slots in unlocked meals — what the planner would fill.
    private var emptySlotCount: Int {
        (0..<7).reduce(0) { total, offset in
            let day = MealRules.addDays(offset, to: weekStart)
            let planned = Set(weekEntries.filter { MealRules.startOfDay($0.date) == day }.map(\.slotRaw))
            return total + activeSlots.filter { !planned.contains($0.rawValue) }.count
        }
    }

    private var generatedCount: Int { weekEntries.filter(\.wasGenerated).count }

    /// Planning a week that has already been eaten is not useful, and would
    /// rewrite the record the allergen and rotation checks read from.
    private var isPlannable: Bool { weekStart >= MealRules.planningWeekStart(for: today) }

    @ViewBuilder
    private var planner: some View {
        if isPlannable, emptySlotCount > 0 || generatedCount > 0 || !planNotes.isEmpty {
            MealCard(background: .white, border: MealTheme.lagoon.opacity(0.35)) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "wand.and.stars")
                            .foregroundStyle(MealTheme.lagoon)
                        Text(emptySlotCount > 0 ? "Plan this week" : "Planned automatically")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(MealTheme.ink)
                        Spacer()
                    }

                    Text(emptySlotCount > 0
                         ? "Fills \(emptySlotCount) empty \(emptySlotCount == 1 ? "meal" : "meals") using the rules below: a new vegetable and a new fruit, the 7-day allergen loop, protein rotation, and foods due back."
                         : "Meals you edit are yours — planning again keeps them and rebuilds the rest.")
                        .font(.system(size: 13))
                        .foregroundStyle(MealTheme.muted)

                    if !planNotes.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(planNotes, id: \.self) { note in
                                HStack(alignment: .top, spacing: 7) {
                                    Circle().fill(MealTheme.lagoon).frame(width: 5, height: 5)
                                        .padding(.top, 6)
                                    Text(note)
                                        .font(.system(size: 12.5))
                                        .foregroundStyle(MealTheme.ink)
                                    Spacer(minLength: 0)
                                }
                            }
                        }
                        .padding(.top, 2)
                    }

                    HStack(spacing: 16) {
                        if emptySlotCount > 0 {
                            Button("Plan \(emptySlotCount) \(emptySlotCount == 1 ? "meal" : "meals")") {
                                run { MealPlanner.fill(weekStart: weekStart, birthDate: birthDate, in: modelContext) }
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(MealTheme.lagoon)
                        }
                        if generatedCount > 0 {
                            Button("Plan again") {
                                run { MealPlanner.replan(weekStart: weekStart, birthDate: birthDate, in: modelContext) }
                            }
                            .font(.system(size: 14, weight: emptySlotCount > 0 ? .regular : .semibold))
                            .foregroundStyle(emptySlotCount > 0 ? MealTheme.muted : MealTheme.lagoon)
                        }
                        Spacer()
                    }
                }
            }
        }
    }

    private func run(_ planning: () -> MealPlanner.Plan) {
        planNotes = planning().notes
    }

    // MARK: - Proposals

    /// Both halves of the weekly rule in one place: what to *introduce* and what
    /// to *keep in rotation*. Rotation returns show even on a fully planned week,
    /// because a rotation gap can exist inside a complete menu (D-4).
    @ViewBuilder
    private var proposals: some View {
        let introductions = MealRules.introductions(weekStart: weekStart, foods: foods, foodsByID: foodsByID, menu: menu)
        let suggestedVeg = introductions.newVegetable == nil
            ? MealRules.suggestNewFood(kind: .veg, on: weekStart, foods: foods, menu: menu) : nil
        let suggestedFruit = introductions.newFruit == nil
            ? MealRules.suggestNewFood(kind: .fruct, on: weekStart, foods: foods, menu: menu) : nil
        let returns = MealRules.rotationReturns(weekStart: weekStart, foods: foods, menu: menu)

        if suggestedVeg != nil || suggestedFruit != nil || !returns.isEmpty || !introductions.crowdedDays.isEmpty {
            MealCard(background: MealTheme.lagoonSoft, border: MealTheme.lagoon.opacity(0.35)) {
                VStack(alignment: .leading, spacing: 14) {
                    if suggestedVeg != nil || suggestedFruit != nil {
                        VStack(alignment: .leading, spacing: 8) {
                            Eyebrow(text: "New foods")
                            if let veg = suggestedVeg { ProposalRow(food: veg, reason: reason(for: veg)) }
                            if let fruit = suggestedFruit { ProposalRow(food: fruit, reason: reason(for: fruit)) }
                        }
                    }

                    if !returns.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Eyebrow(text: "Keep in rotation")
                            ForEach(returns.prefix(5)) { flag in
                                ProposalRow(
                                    food: flag.food,
                                    reason: flag.isRecent
                                        ? "at risk of dropping out"
                                        : flag.daysAbsent.map { "missing for \($0) days" } ?? "missing for over \(MealRules.rotationWindowDays) days",
                                    isUrgent: flag.isRecent
                                )
                            }
                        }
                    }

                    if !introductions.crowdedDays.isEmpty {
                        MealBadge(
                            text: "more than one new food in a day: \(introductions.crowdedDays.map(\.mealDayLabel).joined(separator: ", "))",
                            tint: MealTheme.bubblegum, soft: MealTheme.bubbleSoft
                        )
                    }
                }
            }
        }
    }

    private func reason(for food: Food) -> String {
        var parts: [String] = []
        if food.isInSeason(on: weekStart, calendar: MealRules.calendar) { parts.append("in season") }
        if food.isPriority { parts.append("priority") }
        return parts.isEmpty ? "next on the list" : parts.joined(separator: " · ")
    }

    // MARK: - Nutrition

    private var nutritionSummary: some View {
        let n = nutrition
        return VStack(alignment: .leading, spacing: 10) {
            Eyebrow(text: "Weekly check")
            VStack(spacing: 8) {
                NutritionRow(label: "Animal-source food", value: "\(n.animalSource)/\(n.days)", ok: n.days > 0 && n.animalSource == n.days)
                NutritionRow(label: "Fruit and vegetable", value: "\(n.fruitAndVeg)/\(n.days)", ok: n.days > 0 && n.fruitAndVeg == n.days)
                NutritionRow(label: "Iron source", value: "\(n.iron)/\(n.days)", ok: n.days > 0 && n.iron == n.days)
                NutritionRow(label: "Starch-free meals", value: "\(n.starchFreeMeals)/\(n.meals)", ok: n.meetsStarchTarget, isHeuristic: true)
            }

            if !n.lunchGaps.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(n.lunchGaps.enumerated()), id: \.offset) { _, gap in
                        MealBadge(text: "\(gap.date.mealDayLabel): missing \(gap.missing.joined(separator: ", "))",
                                  tint: MealTheme.bubblegum, soft: MealTheme.bubbleSoft)
                    }
                }
            }

            let proteins = MealRules.proteinsUsed(weekStart: weekStart, menu: menu)
            if !proteins.isEmpty {
                HStack(spacing: 6) {
                    Text("Proteins:")
                        .font(.system(size: 12))
                        .foregroundStyle(MealTheme.muted)
                    ForEach(proteins, id: \.self) { id in
                        if let food = foodsByID[id] { FoodChip(food: food, compact: true) }
                    }
                }
            }
        }
    }

    // MARK: - Days

    private var days: some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow(text: "Menu")
            ForEach(0..<7, id: \.self) { offset in
                let day = MealRules.addDays(offset, to: weekStart)
                let entries = weekEntries
                    .filter { MealRules.startOfDay($0.date) == day && activeSlots.contains($0.slot) }
                    .sorted { $0.slot.displayOrder < $1.slot.displayOrder }
                DayCard(
                    day: day,
                    entries: entries,
                    activeSlots: activeSlots,
                    foodsByID: foodsByID,
                    isToday: day == today,
                    onSelect: { slot, entry in
                        editTarget = MealEditTarget(date: day, slot: slot, entry: entry)
                    }
                )
            }
        }
    }
}

// MARK: - Rows

struct ProposalRow: View {
    let food: Food
    let reason: String
    var isUrgent: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            Circle().fill(food.color).frame(width: 12, height: 12)
            Text(food.name)
                .font(.system(size: 14.5, weight: .semibold))
                .foregroundStyle(MealTheme.ink)
            Spacer()
            Text(reason)
                .font(.system(size: 12, weight: isUrgent ? .semibold : .regular))
                .foregroundStyle(isUrgent ? MealTheme.sugar : MealTheme.muted)
        }
    }
}

struct NutritionRow: View {
    let label: String
    let value: String
    let ok: Bool
    var isHeuristic: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: ok ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundStyle(ok ? MealTheme.lagoon : MealTheme.bubblegum)
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(MealTheme.ink)
            if isHeuristic {
                // The threshold behind this row was chosen, not derived from WHO.
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 11))
                    .foregroundStyle(MealTheme.muted)
            }
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(MealTheme.muted)
        }
    }
}

struct DayCard: View {
    let day: Date
    /// Already sorted by `MealSlot.displayOrder` — breakfast before lunch.
    let entries: [MenuEntry]
    let activeSlots: [MealSlot]
    let foodsByID: [String: Food]
    let isToday: Bool
    let onSelect: (MealSlot, MenuEntry?) -> Void

    private var emptySlots: [MealSlot] {
        let planned = Set(entries.map(\.slotRaw))
        return activeSlots.filter { !planned.contains($0.rawValue) }
    }

    var body: some View {
        MealCard(
            background: isToday ? MealTheme.lagoonSoft : .white,
            border: isToday ? MealTheme.lagoon.opacity(0.4) : MealTheme.line,
            dashed: entries.isEmpty
        ) {
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Text(day.mealDayLabel)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(MealTheme.ink)
                    Spacer()
                    if entries.contains(where: \.isNewFood) {
                        MealBadge(text: "new food", tint: MealTheme.marigold, soft: MealTheme.marigoldSoft)
                    }
                }

                ForEach(entries) { entry in
                    Button { onSelect(entry.slot, entry) } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            FoodColorStrip(colors: entry.foodIDs.compactMap { foodsByID[$0]?.color }, height: 4)
                            HStack(alignment: .top, spacing: 8) {
                                Text(entry.slot.short)
                                    .font(.system(size: 10.5, weight: .bold))
                                    .foregroundStyle(MealTheme.muted)
                                    .frame(width: 22, alignment: .leading)
                                Text(entry.dish)
                                    .font(.system(size: 13.5))
                                    .foregroundStyle(MealTheme.ink)
                                    .multilineTextAlignment(.leading)
                                Spacer(minLength: 0)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }

                ForEach(emptySlots) { slot in
                    Button { onSelect(slot, nil) } label: {
                        HStack(spacing: 8) {
                            Text(slot.short)
                                .font(.system(size: 10.5, weight: .bold))
                                .frame(width: 22, alignment: .leading)
                            Text("add \(slot.label.lowercased())")
                                .font(.system(size: 13))
                            Spacer(minLength: 0)
                        }
                        .foregroundStyle(MealTheme.lagoon.opacity(0.85))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
