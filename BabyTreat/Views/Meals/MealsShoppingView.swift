import SwiftUI
import SwiftData

struct MealsShoppingView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [ShoppingItem]

    private static let order = MealSeed.shoppingCategories

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
        MealSeed.shopping(weekStart: week).forEach { modelContext.insert($0) }
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
