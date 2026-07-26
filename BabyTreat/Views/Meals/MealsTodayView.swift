import SwiftUI
import SwiftData

struct MealsTodayView: View {
    let birthDate: Date

    @Environment(\.modelContext) private var modelContext
    @Query private var foods: [Food]
    @Query private var menu: [MenuEntry]
    @Query private var logs: [MealLog]

    @AppStorage("dairyHoldNoticeSeen") private var dairyHoldNoticeSeen = false

    private var today: Date { MealRules.startOfDay(.now) }
    private var months: Int { MealRules.ageMonths(on: today, birthDate: birthDate) }
    private var activeSlots: [MealSlot] { MealRules.activeSlots(atAgeMonths: months) }
    private var foodsByID: [String: Food] { Dictionary(foods.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a }) }

    private var todaysEntries: [MenuEntry] {
        menu.filter { MealRules.startOfDay($0.date) == today && activeSlots.contains($0.slot) }
            .sorted { ($0.slot.unlocksAtMonths ?? 0, $0.slot.rawValue) < ($1.slot.unlocksAtMonths ?? 0, $1.slot.rawValue) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                Text(today.mealDayLabel)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(MealTheme.ink)

                dairyHoldNotice

                if todaysEntries.isEmpty {
                    MealCard(background: MealTheme.lagoonSoft, border: MealTheme.lagoon.opacity(0.3)) {
                        Text("No meals planned today. Open the Week tab to plan.")
                            .font(.system(size: 14))
                            .foregroundStyle(MealTheme.muted)
                    }
                } else {
                    VStack(spacing: 12) {
                        ForEach(todaysEntries) { entry in
                            MealEntryCard(
                                entry: entry,
                                foodsByID: foodsByID,
                                log: log(for: entry),
                                onLog: { portion in setLog(entry: entry, portion: portion) }
                            )
                        }
                    }
                }

                allergenSection
            }
            .padding(.horizontal, MealTheme.pad)
            .padding(.vertical, 20)
        }
    }

    // MARK: - Dairy hold

    /// The dairy hold expires by **date** (23 Aug 2026), but its reason is
    /// unconfirmed CMPA — and the two can come apart (OQ-7, D-12). The hold is
    /// left to expire on schedule; this notice fires once on the day it does, so
    /// the suggestion never appears without the caveat attached to it.
    @ViewBuilder
    private var dairyHoldNotice: some View {
        if today >= MealSeed.dairyHoldUntil, !dairyHoldNoticeSeen {
            MealCard(background: MealTheme.marigoldSoft, border: MealTheme.marigold.opacity(0.5)) {
                VStack(alignment: .leading, spacing: 9) {
                    HStack(spacing: 7) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(MealTheme.marigold)
                        Text("Dairy hold has expired")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(MealTheme.ink)
                    }
                    Text("Yogurt and cottage cheese can now be suggested. CMPA was last recorded as unconfirmed — confirm with the pediatrician before introducing them.")
                        .font(.system(size: 13))
                        .foregroundStyle(MealTheme.muted)
                    Button("Got it") { dairyHoldNoticeSeen = true }
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(MealTheme.sugar)
                }
            }
        }
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

    // MARK: - Logging

    private func log(for entry: MenuEntry) -> MealLog? {
        logs.first { MealRules.startOfDay($0.date) == MealRules.startOfDay(entry.date) && $0.slotRaw == entry.slotRaw }
    }

    private func setLog(entry: MenuEntry, portion: MealPortion) {
        if let existing = log(for: entry) {
            // Tapping the same portion again clears the log, so a mistap is undoable.
            if existing.portion == portion {
                modelContext.delete(existing)
            } else {
                existing.portion = portion
                existing.loggedAt = .now
            }
        } else {
            modelContext.insert(
                MealLog(date: entry.date, slot: entry.slot, portion: portion, calendar: MealRules.calendar)
            )
        }
        try? modelContext.save()
    }
}

// MARK: - Cards

struct MealEntryCard: View {
    let entry: MenuEntry
    let foodsByID: [String: Food]
    let log: MealLog?
    let onLog: (MealPortion) -> Void

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
                    if let log {
                        MealBadge(
                            text: log.portion.label,
                            tint: log.portion == .refused ? MealTheme.bubblegum : MealTheme.lagoon,
                            soft: log.portion == .refused ? MealTheme.bubbleSoft : MealTheme.lagoonSoft
                        )
                    }
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

                Menu {
                    ForEach(MealPortion.allCases) { portion in
                        Button {
                            onLog(portion)
                        } label: {
                            if log?.portion == portion {
                                Label(portion.label, systemImage: "checkmark")
                            } else {
                                Text(portion.label)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: log == nil ? "square.and.pencil" : "checkmark.circle.fill")
                        Text(log == nil ? "Log this meal" : "Change")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(MealTheme.lagoon)
                    .padding(.vertical, 7)
                    .padding(.horizontal, 12)
                    .background(MealTheme.lagoonSoft, in: Capsule())
                }
            }
        }
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
