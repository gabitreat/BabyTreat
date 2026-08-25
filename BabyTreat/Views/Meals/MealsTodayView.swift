import SwiftUI
import SwiftData

struct MealsTodayView: View {
    let birthDate: Date

    @Environment(\.modelContext) private var modelContext
    @Query private var foods: [Food]
    @Query private var menu: [MenuEntry]
    @Query private var logs: [MealLog]
    @Query private var recipes: [Recipe]
    @Query private var reactions: [ReactionLog]

    @State private var editTarget: MealEditTarget?
    @State private var logTarget: MealEditTarget?
    @State private var reactionTarget: ReactionEditTarget?

    private var today: Date { MealRules.startOfDay(.now) }
    private var months: Int { MealRules.ageMonths(on: today, birthDate: birthDate) }
    private var activeSlots: [MealSlot] { MealRules.activeSlots(atAgeMonths: months) }
    private var foodsByID: [String: Food] { Dictionary(foods.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a }) }

    private var todaysEntries: [MenuEntry] {
        menu.filter { MealRules.startOfDay($0.date) == today && activeSlots.contains($0.slot) }
            .sorted { $0.slot.displayOrder < $1.slot.displayOrder }
    }

    /// Unlocked slots with nothing planned — the entry point for an improvised meal.
    private var emptySlots: [MealSlot] {
        let planned = Set(todaysEntries.map(\.slotRaw))
        return activeSlots.filter { !planned.contains($0.rawValue) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                Text(today.mealDayLabel)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(MealTheme.ink)

                VStack(spacing: 12) {
                    ForEach(todaysEntries) { entry in
                        MealEntryCard(
                            entry: entry,
                            foodsByID: foodsByID,
                            log: log(for: entry),
                            onEdit: { editTarget = MealEditTarget(date: entry.date, slot: entry.slot, entry: entry) },
                            onLog: { logTarget = MealEditTarget(date: entry.date, slot: entry.slot, entry: entry) }
                        )
                    }

                    ForEach(emptySlots) { slot in
                        Button {
                            editTarget = MealEditTarget(date: today, slot: slot, entry: nil)
                        } label: {
                            MealCard(background: .white, dashed: true) {
                                HStack(spacing: 8) {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Add \(slot.label.lowercased())")
                                        .fontWeight(.semibold)
                                    Spacer()
                                }
                                .font(.system(size: 14))
                                .foregroundStyle(MealTheme.lagoon)
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    lockedSlotRows
                }

                reactionSection

                allergenSection
            }
            .padding(.horizontal, MealTheme.pad)
            .padding(.vertical, 20)
        }
        .sheet(item: $reactionTarget) { target in
            ReactionLogSheet(
                existing: target.reaction,
                onSave: { observedAt, severity, symptoms, notes in
                    saveReaction(target: target, observedAt: observedAt, severity: severity,
                                 symptoms: symptoms, notes: notes)
                },
                onDelete: target.reaction.map { reaction in
                    { modelContext.delete(reaction); try? modelContext.save() }
                }
            )
        }
        .sheet(item: $editTarget) { target in
            MealEditSheet(
                date: target.date,
                slot: target.slot,
                existing: target.entry,
                foods: foods,
                recipes: recipes,
                ageMonths: months,
                onSave: { dish, foodIDs, recipeID, isNew in
                    save(target: target, dish: dish, foodIDs: foodIDs, recipeID: recipeID, isNew: isNew)
                },
                onDelete: target.entry.map { entry in
                    { modelContext.delete(entry); try? modelContext.save() }
                }
            )
        }
        .sheet(item: $logTarget) { target in
            MealLogSheet(
                date: target.date,
                slot: target.slot,
                dish: target.entry?.dish ?? "",
                existing: target.entry.flatMap(log(for:)),
                attribution: attribution(for: target),
                nameForFood: { foodsByID[$0]?.name ?? $0 },
                onSave: { draft in
                    setLog(target: target, draft: draft)
                },
                onClear: {
                    if let entry = target.entry, let existing = log(for: entry) {
                        modelContext.delete(existing)
                        try? modelContext.save()
                    }
                }
            )
        }
    }

    // MARK: - Dairy hold


    // MARK: - Locked slots

    /// Disabled, not hidden. A slot that appears one morning with no warning is
    /// a worse surprise than one you have been watching approach.
    @ViewBuilder
    private var lockedSlotRows: some View {
        ForEach(MealRules.lockedSlots(atAgeMonths: months)) { slot in
            MealCard(background: Color(.secondarySystemBackground)) {
                HStack(spacing: 8) {
                    Image(systemName: "lock.fill")
                    VStack(alignment: .leading, spacing: 1) {
                        Text(slot.label)
                            .fontWeight(.semibold)
                        Text(unlockCaption(for: slot))
                            .font(.system(size: 11.5))
                    }
                    Spacer()
                }
                .font(.system(size: 14))
                .foregroundStyle(MealTheme.muted)
            }
            .allowsHitTesting(false)
        }
    }

    private func unlockCaption(for slot: MealSlot) -> String {
        guard let months = slot.unlocksAtMonths else { return "no date set yet" }
        guard let date = MealRules.unlockDate(for: slot, birthDate: birthDate) else {
            return "from \(months) months"
        }
        let days = MealRules.daysBetween(today, date)
        if days <= 0 { return "from \(months) months" }
        return "from \(months) months · \(date.mealDayLabel), \(days) day\(days == 1 ? "" : "s") away"
    }

    // MARK: - Reactions

    /// Logged independently of any meal, on purpose. The button sits here
    /// because this is the screen open when something gets noticed — but what
    /// it opens knows nothing about today's meals.
    @ViewBuilder
    private var reactionSection: some View {
        let meals = LoggedMeal.join(menu: menu, logs: logs)

        VStack(alignment: .leading, spacing: 12) {
            ReactionCandidatesView(
                reactions: reactions,
                meals: meals,
                foodsByID: foodsByID,
                onEdit: { reactionTarget = ReactionEditTarget(reaction: $0) }
            )

            Button {
                reactionTarget = ReactionEditTarget(reaction: nil)
            } label: {
                MealCard(background: .white, dashed: true) {
                    HStack(spacing: 8) {
                        Image(systemName: "bandage")
                        Text("Log a reaction")
                            .fontWeight(.semibold)
                        Spacer()
                    }
                    .font(.system(size: 14))
                    .foregroundStyle(MealTheme.sugar)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private func saveReaction(
        target: ReactionEditTarget,
        observedAt: Date,
        severity: ToleranceLevel,
        symptoms: [String],
        notes: String
    ) {
        if let reaction = target.reaction {
            reaction.observedAt = ReactionLog.roundedToMinute(observedAt)
            reaction.severity = severity
            reaction.symptoms = symptoms
            reaction.notes = notes
        } else {
            modelContext.insert(
                ReactionLog(observedAt: observedAt, severity: severity, symptoms: symptoms, notes: notes)
            )
        }
        try? modelContext.save()
    }

    // MARK: - Allergen meter

    private var allergenSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow(text: "Allergen rotation")
            Text("Re-expose every \(MealRules.allergenIntervalDays) days")
                .font(.system(size: 13))
                .foregroundStyle(MealTheme.muted)

            ForEach(foods.filter(\.isAllergen).sorted { $0.name < $1.name }) { food in
                let state = MealRules.allergenState(
                    foodID: food.id,
                    baselineLast: MealSeed.allergenBaselines[food.id] ?? today,
                    menu: menu,
                    logs: logs,
                    today: today,
                    activeSlots: activeSlots
                )
                AllergenRow(food: food, state: state)
            }
        }
    }

    // MARK: - Persistence

    private func log(for entry: MenuEntry) -> MealLog? {
        logs.first { MealRules.startOfDay($0.date) == MealRules.startOfDay(entry.date) && $0.slotRaw == entry.slotRaw }
    }

    private func save(target: MealEditTarget, dish: String, foodIDs: [String], recipeID: String?, isNew: Bool) {
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
    }

    private func setLog(target: MealEditTarget, draft: MealLogDraft) {
        if let entry = target.entry, let existing = log(for: entry) {
            existing.portion = draft.portion
            existing.grams = draft.grams
            existing.note = draft.note
            existing.tolerance = draft.tolerance
            existing.toleranceNote = draft.toleranceNote
            existing.excludeFromTaste = draft.excludeFromTaste
            existing.eatenAt = draft.eatenAt.map(MealLog.roundedToMinute)
            existing.timeZoneID = TimeZone.current.identifier
            // Re-recording a flag revives it; the old clearing no longer applies.
            existing.clearedAt = nil
            existing.loggedAt = .now
        } else {
            modelContext.insert(
                MealLog(date: target.date, slot: target.slot, portion: draft.portion,
                        grams: draft.grams, note: draft.note,
                        tolerance: draft.tolerance, toleranceNote: draft.toleranceNote,
                        excludeFromTaste: draft.excludeFromTaste, eatenAt: draft.eatenAt,
                        calendar: MealRules.calendar)
            )
        }
        try? modelContext.save()
    }

    /// Which food would carry a flag recorded against this meal. Computed from
    /// the journal as it stands, before the meal being edited is written back.
    private func attribution(for target: MealEditTarget) -> ToleranceEngine.Attribution? {
        guard let entry = target.entry, !entry.foodIDs.isEmpty else { return nil }
        let meals = LoggedMeal.join(menu: menu, logs: logs)
        let probe = LoggedMeal(
            date: MealRules.startOfDay(target.date), slot: target.slot, dish: entry.dish,
            foodIDs: entry.foodIDs, portion: .refused, tolerance: nil,
            isCleared: false, excludeFromTaste: false
        )
        return ToleranceEngine.attribution(for: probe, in: meals)
    }
}

// MARK: - Cards

struct MealEntryCard: View {
    let entry: MenuEntry
    let foodsByID: [String: Food]
    let log: MealLog?
    let onEdit: () -> Void
    let onLog: () -> Void

    private var entryFoods: [Food] { entry.foodIDs.compactMap { foodsByID[$0] } }
    private var gaps: [String] { MealRules.lunchGaps(entry: entry, foodsByID: foodsByID) }

    var body: some View {
        MealCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text(entry.slot.label)
                        .font(.system(size: 11.5, weight: .semibold))
                        .tracking(1.2)
                        .foregroundStyle(MealTheme.muted)
                    if entry.isNewFood {
                        MealBadge(text: "new food", tint: MealTheme.marigold, soft: MealTheme.marigoldSoft)
                    }
                    Spacer()
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(MealTheme.muted)
                            .padding(6)
                            .background(MealTheme.line.opacity(0.35), in: Circle())
                    }
                    .buttonStyle(.plain)
                }

                FoodColorStrip(colors: entryFoods.map(\.color))

                Text(entry.dish)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(MealTheme.ink)

                if !entryFoods.isEmpty {
                    MealChipFlow(foods: entryFoods)
                }

                if entry.slot == .lunch, !gaps.isEmpty {
                    MealBadge(text: "missing: \(gaps.joined(separator: ", "))",
                              tint: MealTheme.bubblegum, soft: MealTheme.bubbleSoft)
                }

                if let log, !log.note.isEmpty {
                    Text(log.note)
                        .font(.system(size: 12.5))
                        .foregroundStyle(MealTheme.muted)
                }

                Button(action: onLog) {
                    HStack(spacing: 6) {
                        Image(systemName: log == nil ? "square.and.pencil" : "checkmark.circle.fill")
                        Text(log?.summary ?? "Log this meal")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(logTint)
                    .padding(.vertical, 7)
                    .padding(.horizontal, 12)
                    .background(logBackground, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var logTint: Color {
        log?.portion == .refused ? MealTheme.bubblegum : MealTheme.lagoon
    }

    private var logBackground: Color {
        log?.portion == .refused ? MealTheme.bubbleSoft : MealTheme.lagoonSoft
    }
}

struct AllergenRow: View {
    let food: Food
    let state: MealRules.AllergenState

    var body: some View {
        MealCard(
            background: state.isDue ? MealTheme.marigoldSoft : .white,
            border: state.isDue ? MealTheme.marigold.opacity(0.45) : MealTheme.line
        ) {
            HStack(spacing: 12) {
                Circle().fill(food.color).frame(width: 14, height: 14)

                VStack(alignment: .leading, spacing: 2) {
                    Text(food.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(MealTheme.ink)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(MealTheme.muted)
                }

                Spacer()

                if state.isDue {
                    MealBadge(text: "due", tint: MealTheme.sugar, soft: MealTheme.sugarSoft)
                }
                Text("\(state.daysSince)d")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(state.isDue ? MealTheme.sugar : MealTheme.lagoon)
            }
        }
    }

    private var subtitle: String {
        var parts = ["last: \(state.last.mealDayLabel)"]
        if !state.isConfirmed { parts.append("estimated") }
        if let next = state.next { parts.append("next: \(next.mealDayLabel)") }
        return parts.joined(separator: " · ")
    }
}

/// Wrapping row of food chips.
struct MealChipFlow: View {
    let foods: [Food]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(foods) { FoodChip(food: $0, compact: true) }
            }
        }
    }
}
