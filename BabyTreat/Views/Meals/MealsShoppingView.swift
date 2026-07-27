import SwiftUI
import SwiftData

struct MealsShoppingView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [ShoppingItem]
    @Query private var menu: [MenuEntry]
    @Query private var foods: [Food]

    private static let order = MealSeed.shoppingCategories

    private var foodsByID: [String: Food] {
        Dictionary(foods.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    }

    /// True once the shown list was built from a menu, so its lines carry food
    /// IDs and can be diffed against the plan.
    private var isMenuDerived: Bool {
        listItems.contains { $0.foodID != nil }
    }

    /// Foods this week's menu calls for that are not on the list yet. This is
    /// what catches the new introductions — they were never on last week's list,
    /// so a carried-over list is always missing exactly them.
    ///
    /// Only meaningful for a menu-derived list. A hand-written or legacy list is
    /// not diffed at all rather than guessed at.
    private var missingFoods: [Food] {
        guard isMenuDerived else { return [] }
        let onList = Set(listItems.compactMap(\.foodID))
        return MealRules.foodsUsed(weekStart: currentWeek, menu: menu)
            .filter { !onList.contains($0.id) }
            .compactMap { foodsByID[$0.id] }
    }

    /// Foods on this week's menu at all — used to tell the user what a rebuild
    /// would give them, when the current list cannot be diffed.
    private var weekFoodCount: Int {
        MealRules.foodsUsed(weekStart: currentWeek, menu: menu).count
    }

    /// The week we are shopping *for* right now.
    private var currentWeek: Date { MealRules.shoppingWeekStart(for: .now) }

    /// The list to show. Deliberately **not** an exact match on the current
    /// week: the newest list at or before this week stays on screen until a new
    /// one is started, so it remains available all week instead of vanishing the
    /// moment the week rolls over. Falls back to the earliest list if only
    /// future-dated ones exist.
    private var activeWeek: Date? {
        let weeks = Set(items.map { MealRules.startOfDay($0.weekStart) })
        guard !weeks.isEmpty else { return nil }
        return weeks.filter { $0 <= currentWeek }.max() ?? weeks.min()
    }

    private var listItems: [ShoppingItem] {
        guard let activeWeek else { return [] }
        return items.filter { MealRules.startOfDay($0.weekStart) == activeWeek }
    }

    private var isStale: Bool {
        guard let activeWeek else { return false }
        return activeWeek < currentWeek
    }

    private var grouped: [(category: String, items: [ShoppingItem])] {
        Self.order.compactMap { category in
            let entries = listItems.filter { $0.category == category }
            return entries.isEmpty ? nil : (category, entries.sorted { $0.name < $1.name })
        }
    }

    private var checkedCount: Int { listItems.filter(\.isChecked).count }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                if listItems.isEmpty {
                    MealCard(background: MealTheme.lagoonSoft, border: MealTheme.lagoon.opacity(0.3)) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("No list yet.")
                                .font(.system(size: 14))
                                .foregroundStyle(MealTheme.muted)
                            Button("Create from the base list") { startList(for: currentWeek) }
                                .font(.system(size: 13.5, weight: .semibold))
                                .foregroundStyle(MealTheme.lagoon)
                        }
                    }
                }

                if !listItems.isEmpty, !isMenuDerived, weekFoodCount > 0 {
                    MealCard(background: MealTheme.marigoldSoft, border: MealTheme.marigold.opacity(0.45)) {
                        VStack(alignment: .leading, spacing: 9) {
                            Eyebrow(text: "Not linked to the menu", color: MealTheme.sugar)
                            Text("This list was written before lists were built from the week's menu, so it can't be checked against the plan — including this week's new foods. Rebuilding covers all \(weekFoodCount) foods on the menu, but clears what you've ticked.")
                                .font(.system(size: 13))
                                .foregroundStyle(MealTheme.muted)
                            Button("Rebuild from this week's menu") { startList(for: currentWeek) }
                                .font(.system(size: 13.5, weight: .semibold))
                                .foregroundStyle(MealTheme.sugar)
                        }
                    }
                }

                if !listItems.isEmpty, !missingFoods.isEmpty {
                    MealCard(background: MealTheme.marigoldSoft, border: MealTheme.marigold.opacity(0.45)) {
                        VStack(alignment: .leading, spacing: 9) {
                            Eyebrow(text: "On the menu, not on the list", color: MealTheme.sugar)
                            ForEach(missingFoods) { food in
                                HStack(spacing: 9) {
                                    Circle().fill(food.color).frame(width: 11, height: 11)
                                    Text(food.name)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(MealTheme.ink)
                                    if food.status == .planned {
                                        MealBadge(text: "new food", tint: MealTheme.sugar, soft: .white)
                                    }
                                    Spacer()
                                }
                            }
                            Button("Add \(missingFoods.count == 1 ? "it" : "them") to the list") { addMissing() }
                                .font(.system(size: 13.5, weight: .semibold))
                                .foregroundStyle(MealTheme.sugar)
                        }
                    }
                }

                ForEach(grouped, id: \.category) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        Eyebrow(text: group.category)
                        ForEach(group.items) { item in
                            ShoppingRow(item: item) { try? modelContext.save() }
                        }
                    }
                }

                if !listItems.isEmpty {
                    Button {
                        startList(for: currentWeek)
                    } label: {
                        MealCard(background: .white, dashed: true) {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.clockwise")
                                Text(isStale ? "Start this week's list" : "Start a fresh list")
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                            .font(.system(size: 14))
                            .foregroundStyle(MealTheme.lagoon)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, MealTheme.pad)
            .padding(.vertical, 20)
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Shopping list")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(MealTheme.ink)
                if let activeWeek {
                    HStack(spacing: 6) {
                        Text("week of \(activeWeek.mealDayLabel)")
                            .font(.system(size: 12))
                            .foregroundStyle(MealTheme.muted)
                        if isStale {
                            MealBadge(text: "carried over", tint: MealTheme.sugar, soft: MealTheme.sugarSoft)
                        }
                    }
                }
            }
            Spacer()
            if !listItems.isEmpty {
                Text("\(checkedCount)/\(listItems.count)")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(MealTheme.lagoon)
            }
        }
    }

    /// Replaces the shown list with a fresh, unchecked one for `week`. The old
    /// list is removed rather than accumulating — a half-ticked list from three
    /// weeks ago is noise, not history.
    private func startList(for week: Date) {
        for item in listItems { modelContext.delete(item) }
        MealSeed.shopping(weekStart: week, menu: menu, foodsByID: foodsByID)
            .forEach { modelContext.insert($0) }
        try? modelContext.save()
    }

    /// Adds only what is missing, onto the list as it stands — so the ticks
    /// already made survive.
    private func addMissing() {
        guard let activeWeek else { return }
        let counts = Dictionary(
            MealRules.foodsUsed(weekStart: currentWeek, menu: menu).map { ($0.id, $0.meals) },
            uniquingKeysWith: { a, _ in a }
        )
        for food in missingFoods {
            let meals = counts[food.id] ?? 1
            modelContext.insert(
                ShoppingItem(
                    category: MealSeed.shoppingCategory(for: food),
                    name: food.name,
                    quantity: MealSeed.quantityHints[food.id] ?? "\(meals) meal\(meals == 1 ? "" : "s")",
                    weekStart: activeWeek,
                    foodID: food.id,
                    calendar: MealRules.calendar
                )
            )
        }
        try? modelContext.save()
    }
}

struct ShoppingRow: View {
    @Bindable var item: ShoppingItem
    var onChange: () -> Void

    var body: some View {
        Button {
            item.isChecked.toggle()
            onChange()
        } label: {
            MealCard(background: item.isChecked ? MealTheme.lagoonSoft : .white) {
                HStack(spacing: 11) {
                    Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 18))
                        .foregroundStyle(item.isChecked ? MealTheme.lagoon : MealTheme.line)
                    Text(item.name)
                        .font(.system(size: 14.5, weight: .medium))
                        .strikethrough(item.isChecked, color: MealTheme.muted)
                        .foregroundStyle(item.isChecked ? MealTheme.muted : MealTheme.ink)
                    Spacer()
                    Text(item.quantity)
                        .font(.system(size: 12.5))
                        .foregroundStyle(MealTheme.muted)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
