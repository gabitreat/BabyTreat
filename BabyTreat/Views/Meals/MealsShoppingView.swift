import SwiftUI
import SwiftData

struct MealsShoppingView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [ShoppingItem]

    private static let order = MealSeed.shoppingCategories

    private var weekStart: Date { MealRules.mondayOf(.now) }

    private var thisWeek: [ShoppingItem] {
        items.filter { MealRules.startOfDay($0.weekStart) == weekStart }
    }

    private var grouped: [(category: String, items: [ShoppingItem])] {
        Self.order.compactMap { category in
            let entries = thisWeek.filter { $0.category == category }
            return entries.isEmpty ? nil : (category, entries.sorted { $0.name < $1.name })
        }
    }

    private var checkedCount: Int { thisWeek.filter(\.isChecked).count }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Sunday list")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(MealTheme.ink)
                        Text("week of \(weekStart.mealDayLabel)")
                            .font(.system(size: 12))
                            .foregroundStyle(MealTheme.muted)
                    }
                    Spacer()
                    Text("\(checkedCount)/\(thisWeek.count)")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(MealTheme.lagoon)
                }

                if thisWeek.isEmpty {
                    MealCard(background: MealTheme.lagoonSoft, border: MealTheme.lagoon.opacity(0.3)) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("No list for this week yet.")
                                .font(.system(size: 14))
                                .foregroundStyle(MealTheme.muted)
                            Button("Create from the base list") {
                                MealSeed.shopping(weekStart: weekStart).forEach { modelContext.insert($0) }
                                try? modelContext.save()
                            }
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
            }
            .padding(.horizontal, MealTheme.pad)
            .padding(.vertical, 20)
        }
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
