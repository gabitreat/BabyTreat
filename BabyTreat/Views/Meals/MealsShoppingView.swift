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

    /// The list is scoped strictly to the current shopping week. It is not
    /// carried over: when the week turns, `ensureCurrentWeekList` builds a new
    /// one from the new week's menu. Within the week it persists untouched, so
    /// ticks survive.
    private var listItems: [ShoppingItem] {
        items.filter { MealRules.startOfDay($0.weekStart) == currentWeek }
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
                        Text("Nothing planned for this week yet. Plan the week in the Week tab and the list builds itself.")
                            .font(.system(size: 14))
                            .foregroundStyle(MealTheme.muted)
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
                                Text("Rebuild from this week's menu")
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
        .task { ensureCurrentWeekList() }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Shopping list")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(MealTheme.ink)
                Text("week of \(currentWeek.mealDayLabel)")
                    .font(.system(size: 12))
                    .foregroundStyle(MealTheme.muted)
            }
            Spacer()
            if !listItems.isEmpty {
                Text("\(checkedCount)/\(listItems.count)")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(MealTheme.lagoon)
            }
        }
    }

    /// Runs whenever the tab is opened. Builds this week's list if there isn't
    /// one, and clears out lists from weeks already gone — a shopping list is
    /// for shopping, not a record, and a stack of half-ticked old ones is noise.
    ///
    /// Note this flips on **Sunday**, not Monday: `shoppingWeekStart` treats
    /// Sunday as belonging to the week ahead, so the new list is ready on the
    /// planning day rather than appearing after the shopping is done.
    private func ensureCurrentWeekList() {
        var changed = false

        for item in items where MealRules.startOfDay(item.weekStart) < currentWeek {
            modelContext.delete(item)
            changed = true
        }

        // Only build once the week actually has a menu — otherwise the list
        // would be two pantry staples and nothing else, which reads as broken.
        if listItems.isEmpty, weekFoodCount > 0 {
            MealSeed.shopping(weekStart: currentWeek, menu: menu, foodsByID: foodsByID)
                .forEach { modelContext.insert($0) }
            changed = true
        }

        if changed { try? modelContext.save() }
    }

    /// Replaces this week's list with a fresh, unchecked one — for when the
    /// menu changed enough that patching in the missing lines isn't worth it.
    private func startList(for week: Date) {
        for item in listItems { modelContext.delete(item) }
        MealSeed.shopping(weekStart: week, menu: menu, foodsByID: foodsByID)
            .forEach { modelContext.insert($0) }
        try? modelContext.save()
    }

    /// Adds only what is missing, onto the list as it stands — so the ticks
    /// already made survive.
    private func addMissing() {
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
                    weekStart: currentWeek,
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
