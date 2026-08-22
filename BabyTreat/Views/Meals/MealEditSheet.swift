import SwiftUI
import SwiftData

/// Edit or create a single meal. Plans get improvised against constantly — a
/// planned menu that cannot be changed on the day is a menu that stops matching
/// what the baby actually ate, which would quietly corrupt the journal, the
/// allergen counts and the rotation checks alike.
struct MealEditSheet: View {
    @Environment(\.dismiss) private var dismiss

    let date: Date
    let slot: MealSlot
    let existing: MenuEntry?
    let foods: [Food]
    let recipes: [Recipe]
    /// Needed for the age gates below. Passed in rather than read from storage
    /// so this sheet stays previewable.
    var ageMonths: Int = 99
    var onSave: (_ dish: String, _ foodIDs: [String], _ recipeID: String?, _ isNewFood: Bool) -> Void
    var onDelete: (() -> Void)?

    @State private var dish = ""
    /// Ordered, not a Set — the order drives the colour strip.
    @State private var selectedIDs: [String] = []
    @State private var recipeID: String?
    @State private var isNewFood = false
    @State private var query = ""
    @State private var didLoad = false

    private var foodsByID: [String: Food] {
        Dictionary(foods.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    }

    private var selectedFoods: [Food] { selectedIDs.compactMap { foodsByID[$0] } }

    private var matches: [Food] {
        let pool = foods.sorted { $0.name < $1.name }
        guard !query.isEmpty else { return pool }
        return pool.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    /// Only recipes the child is old enough for, plus whatever is already set.
    private var selectableRecipes: [Recipe] {
        recipes.sorted { $0.title < $1.title }
    }

    /// A single food on the plate is being served on its own — which for a
    /// plant milk means as a drink.
    ///
    /// Coconut milk is fine in cooking from 6 months and must not be a drink
    /// before 12: plant milks are not formulated as a main drink at this age,
    /// and using one as such risks real nutritional deficiency. So the block is
    /// on serving it *alone*, not on the food.
    private var drinkBlock: String? {
        guard selectedIDs.count == 1, let food = selectedFoods.first else { return nil }
        return food.drinkBlockReason(atAgeMonths: ageMonths)
    }

    /// Foods the child is not old enough for at all.
    private var tooYoung: [Food] {
        selectedFoods.filter { !$0.isAgeAppropriate(atAgeMonths: ageMonths) }
    }

    private var gaps: [String] {
        guard slot == .lunch, !selectedIDs.isEmpty else { return [] }
        let probe = MenuEntry(date: date, slot: slot, dish: dish, foodIDs: selectedIDs, calendar: MealRules.calendar)
        return MealRules.lunchGaps(entry: probe, foodsByID: foodsByID)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Dish") {
                    TextField("e.g. Chicken + zucchini + olive oil", text: $dish, axis: .vertical)
                        .lineLimit(1...3)
                    if !selectedFoods.isEmpty {
                        Button("Name it from the foods") {
                            dish = selectedFoods.map(\.name).joined(separator: " + ")
                        }
                        .font(.callout)
                    }
                }

                if let drinkBlock {
                    Section {
                        Label(drinkBlock, systemImage: "exclamationmark.octagon.fill")
                            .font(.callout)
                            .foregroundStyle(MealTheme.bubblegum)
                    } header: {
                        Text("Not on its own yet")
                    } footer: {
                        Text("Add another food to the meal and it saves — the limit is on serving it alone, not on cooking with it.")
                    }
                }

                if !tooYoung.isEmpty {
                    Section("Too early") {
                        ForEach(tooYoung) { food in
                            Label(
                                "\(food.name) is usually introduced from \(food.minAgeMonths ?? 0) months.",
                                systemImage: "clock.badge.exclamationmark"
                            )
                            .font(.callout)
                            .foregroundStyle(MealTheme.sugar)
                        }
                    }
                }

                if slot == .lunch {
                    Section {
                        if selectedIDs.isEmpty {
                            Text("Lunch should have protein, vegetable and fat.")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        } else if gaps.isEmpty {
                            Label("Protein, vegetable and fat all covered", systemImage: "checkmark.circle.fill")
                                .font(.callout)
                                .foregroundStyle(MealTheme.lagoon)
                        } else {
                            Label("Missing: \(gaps.joined(separator: ", "))", systemImage: "exclamationmark.circle.fill")
                                .font(.callout)
                                .foregroundStyle(MealTheme.bubblegum)
                        }
                    } footer: {
                        // Worth stating, because it is genuinely surprising.
                        Text("Naming an oil in the dish counts as the fat.")
                    }
                }

                if !selectedFoods.isEmpty {
                    Section("In this meal") {
                        ForEach(selectedFoods) { food in
                            Button {
                                selectedIDs.removeAll { $0 == food.id }
                            } label: {
                                HStack(spacing: 10) {
                                    Circle().fill(food.color).frame(width: 12, height: 12)
                                    Text(food.name).foregroundStyle(.primary)
                                    Spacer()
                                    Image(systemName: "minus.circle.fill").foregroundStyle(.secondary)
                                }
                            }
                        }
                        .onMove { source, destination in
                            selectedIDs.move(fromOffsets: source, toOffset: destination)
                        }
                    }
                }

                Section("Add a food") {
                    TextField("Search", text: $query)
                        .textInputAutocapitalization(.never)
                    ForEach(matches.filter { !selectedIDs.contains($0.id) }.prefix(query.isEmpty ? 12 : 30)) { food in
                        Button {
                            selectedIDs.append(food.id)
                            query = ""
                        } label: {
                            HStack(spacing: 10) {
                                Circle().fill(food.color).frame(width: 12, height: 12)
                                Text(food.name).foregroundStyle(.primary)
                                if food.isAllergen {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.caption2)
                                        .foregroundStyle(MealTheme.marigold)
                                }
                                Spacer()
                                Text(food.status.label)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section {
                    Toggle("First time trying a food here", isOn: $isNewFood)
                } footer: {
                    Text("Marks this as an introduction. Only one new food per day.")
                }

                Section("Recipe") {
                    Picker("Recipe", selection: $recipeID) {
                        Text("None").tag(String?.none)
                        ForEach(selectableRecipes) { recipe in
                            Text(recipe.title).tag(String?.some(recipe.id))
                        }
                    }
                }

                if let onDelete {
                    Section {
                        Button("Delete this meal", role: .destructive) {
                            onDelete()
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("\(slot.label) · \(date.mealDayLabel)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(dish.trimmingCharacters(in: .whitespaces), selectedIDs, recipeID, isNewFood)
                        dismiss()
                    }
                    // A hard block, not a warning: the whole point is that it
                    // cannot be tapped past.
                    .disabled(drinkBlock != nil
                              || (dish.trimmingCharacters(in: .whitespaces).isEmpty && selectedIDs.isEmpty))
                }
                ToolbarItem(placement: .topBarLeading) {
                    if !selectedFoods.isEmpty { EditButton() }
                }
            }
            .onAppear {
                guard !didLoad else { return }
                didLoad = true
                dish = existing?.dish ?? ""
                selectedIDs = existing?.foodIDs ?? []
                recipeID = existing?.recipeID
                isNewFood = existing?.isNewFood ?? false
            }
        }
    }
}

/// Identifies which reaction the sheet is open for. `nil` means a new one —
/// and it carries no meal, deliberately.
struct ReactionEditTarget: Identifiable {
    let reaction: ReactionLog?
    var id: String { reaction.map { "\($0.observedAt.timeIntervalSince1970)" } ?? "new" }
}

/// Identifies which meal the edit sheet is open for. A slot with no entry yet is
/// a valid target — that is how an improvised meal gets added.
struct MealEditTarget: Identifiable {
    let date: Date
    let slot: MealSlot
    let entry: MenuEntry?

    var id: String { "\(date.timeIntervalSince1970):\(slot.rawValue)" }
}
