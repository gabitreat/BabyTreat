import SwiftUI
import SwiftData

struct MealsFoodsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var foods: [Food]
    @Query private var menu: [MenuEntry]
    @Query private var logs: [MealLog]

    @State private var selected: Food?

    private var foodsByID: [String: Food] {
        Dictionary(foods.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    }

    private var loggedMeals: [LoggedMeal] { LoggedMeal.join(menu: menu, logs: logs) }

    private static let order = [
        MealSeed.categoryVegetables, MealSeed.categoryFruit, MealSeed.categoryGrains,
        MealSeed.categoryProtein, MealSeed.categoryFats, MealSeed.categoryPlanned,
    ]

    private var grouped: [(category: String, foods: [Food])] {
        Self.order.compactMap { category in
            let items = foods.filter { $0.category == category }
            return items.isEmpty ? nil : (category, items)
        }
    }

    private var acceptedCount: Int { foods.filter { $0.status == .accepted }.count }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("\(acceptedCount) of \(foods.count) foods accepted")
                    .font(.system(size: 13))
                    .foregroundStyle(MealTheme.muted)

                ToleranceFlagsView(
                    flags: ToleranceEngine.flags(in: loggedMeals),
                    foodsByID: foodsByID,
                    onClear: clear(_:)
                )

                PairInsightsView(
                    effects: PairEffectEngine.analyze(meals: loggedMeals),
                    foodsByID: foodsByID
                )

                rotationSection

                ForEach(grouped, id: \.category) { group in
                    VStack(alignment: .leading, spacing: 10) {
                        Eyebrow(text: group.category)
                        FoodGrid(foods: group.foods) { selected = $0 }
                    }
                }
            }
            .padding(.horizontal, MealTheme.pad)
            .padding(.vertical, 20)
        }
        .sheet(item: $selected) { food in
            FoodDetailSheet(food: food) { try? modelContext.save() }
        }
    }

    /// Marks every log that is still suppressing this food as cleared. The log
    /// itself is kept — a reaction that happened stays in the record even once
    /// the caregiver has decided to move past it.
    private func clear(_ flag: ToleranceEngine.FoodFlag) {
        let meals = loggedMeals
        for meal in meals where meal.hasActiveFlag && meal.foodIDs.contains(flag.foodID) {
            guard ToleranceEngine.suppressedFoodIDs(for: meal, in: meals).contains(flag.foodID) else { continue }
            for log in logs where MealRules.startOfDay(log.date) == meal.date && log.slotRaw == meal.slot.rawValue {
                log.clearedAt = .now
            }
        }
        try? modelContext.save()
    }

    /// Detection half of the rotation rule — what has already slipped.
    @ViewBuilder
    private var rotationSection: some View {
        let flags = MealRules.rotationCheck(refDate: MealRules.startOfDay(.now), foods: foods, menu: menu)
        if !flags.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Eyebrow(text: "Dropping out of rotation")
                Text("Accepted, but absent for over \(MealRules.rotationWindowDays) days")
                    .font(.system(size: 12.5))
                    .foregroundStyle(MealTheme.muted)
                ForEach(flags.prefix(8)) { flag in
                    MealCard(
                        background: flag.isRecent ? MealTheme.sugarSoft : .white,
                        border: flag.isRecent ? MealTheme.sugar.opacity(0.35) : MealTheme.line
                    ) {
                        HStack(spacing: 10) {
                            Circle().fill(flag.food.color).frame(width: 12, height: 12)
                            Text(flag.food.name)
                                .font(.system(size: 14.5, weight: .semibold))
                                .foregroundStyle(MealTheme.ink)
                            Spacer()
                            if flag.isRecent {
                                MealBadge(text: "recently accepted", tint: MealTheme.sugar, soft: MealTheme.sugarSoft)
                            }
                            if let days = flag.daysAbsent {
                                Text("\(days)d")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(MealTheme.muted)
                            }
                        }
                    }
                }
            }
        }
    }
}

struct FoodGrid: View {
    let foods: [Food]
    let onTap: (Food) -> Void

    private let columns = [GridItem(.adaptive(minimum: 104), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(foods) { food in
                Button { onTap(food) } label: {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 6) {
                            Circle().fill(food.color).frame(width: 10, height: 10)
                            Text(food.name)
                                .font(.system(size: 12.5, weight: .semibold))
                                .foregroundStyle(MealTheme.ink)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        HStack(spacing: 3) {
                            if food.status == .accepted || food.status == .weak {
                                ForEach(0..<5, id: \.self) { index in
                                    Image(systemName: index < food.rating ? "circle.fill" : "circle")
                                        .font(.system(size: 5))
                                        .foregroundStyle(MealTheme.sugar.opacity(index < food.rating ? 0.9 : 0.25))
                                }
                            } else {
                                Text("to introduce")
                                    .font(.system(size: 10))
                                    .foregroundStyle(MealTheme.muted)
                            }
                            if food.isAllergen {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 8))
                                    .foregroundStyle(MealTheme.marigold)
                            }
                        }
                    }
                    .padding(9)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(background(for: food))
                    .overlay(
                        RoundedRectangle(cornerRadius: 11)
                            .strokeBorder(
                                food.status == .planned ? MealTheme.line : .clear,
                                style: StrokeStyle(lineWidth: 1.2, dash: [4, 3])
                            )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 11))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func background(for food: Food) -> Color {
        switch food.status {
        case .accepted: food.color.opacity(0.22)
        case .weak:     food.color.opacity(0.10)
        case .planned:  .white
        }
    }
}

struct FoodDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var food: Food
    var onChange: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 10) {
                        Circle().fill(food.color).frame(width: 20, height: 20)
                        Text(food.name).font(.headline)
                        Spacer()
                        Text(food.category).foregroundStyle(.secondary)
                    }
                }

                Section("Status") {
                    Picker("Status", selection: Binding(
                        get: { food.status },
                        set: { food.status = $0; onChange() }
                    )) {
                        ForEach(FoodStatus.allCases, id: \.self) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                if food.status != .planned {
                    Section("Acceptance") {
                        Stepper(
                            "Rating: \(food.rating)/5",
                            value: Binding(get: { food.rating }, set: { food.rating = $0; onChange() }),
                            in: 0...5
                        )
                    }
                }

                if !food.groups.isEmpty {
                    Section("Nutritional groups") {
                        Text(food.groups.map(\.rawValue).joined(separator: ", "))
                            .foregroundStyle(.secondary)
                    }
                }

                if !food.season.isEmpty {
                    Section("Season") {
                        Text(food.season.map(String.init).joined(separator: ", "))
                            .foregroundStyle(.secondary)
                    }
                }

                if let hold = food.holdUntil {
                    Section("On hold") {
                        Text("Not suggested before \(hold.mealDayLabel)")
                            .foregroundStyle(MealTheme.sugar)
                    }
                }

                if let retry = food.retryOn {
                    Section("Retry") {
                        Text(retry.mealDayLabel).foregroundStyle(.secondary)
                    }
                }

                if let note = food.note, !note.isEmpty {
                    Section("Note") { Text(note) }
                }
            }
            .navigationTitle(food.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
