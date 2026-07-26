import SwiftUI
import SwiftData

struct MealsRecipesView: View {
    let birthDate: Date

    @Environment(\.modelContext) private var modelContext
    @Query private var recipes: [Recipe]
    @Query private var foods: [Food]

    @State private var selected: Recipe?

    private var months: Int { MealRules.ageMonths(on: .now, birthDate: birthDate) }
    private var foodsByID: [String: Food] { Dictionary(foods.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a }) }

    private var available: [Recipe] { recipes.filter { $0.minAgeMonths <= months }.sorted { $0.title < $1.title } }
    private var upcoming: [Recipe] { recipes.filter { $0.minAgeMonths > months }.sorted { $0.minAgeMonths < $1.minAgeMonths } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    Eyebrow(text: "Recipes")
                    ForEach(available) { recipe in
                        RecipeCard(recipe: recipe, foodsByID: foodsByID) { selected = recipe }
                    }
                }

                if !upcoming.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Eyebrow(text: "Later")
                        ForEach(upcoming) { recipe in
                            RecipeCard(recipe: recipe, foodsByID: foodsByID, locked: true) { selected = recipe }
                        }
                    }
                }

                sourcesSection
            }
            .padding(.horizontal, MealTheme.pad)
            .padding(.vertical, 20)
        }
        .sheet(item: $selected) { recipe in
            RecipeDetailSheet(recipe: recipe, foodsByID: foodsByID) { try? modelContext.save() }
        }
    }

    /// External recipes are linked, never copied — the content stays at the
    /// source. This is a copyright decision (D-1).
    private var sourcesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow(text: "External sources")
            ForEach(RecipeSource.all) { source in
                MealCard(background: MealTheme.sugarSoft, border: MealTheme.sugar.opacity(0.25)) {
                    VStack(alignment: .leading, spacing: 9) {
                        HStack {
                            Text(source.name)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(MealTheme.ink)
                            Text("· \(source.author)")
                                .font(.system(size: 12))
                                .foregroundStyle(MealTheme.muted)
                        }
                        Text(source.blurb)
                            .font(.system(size: 12.5))
                            .foregroundStyle(MealTheme.muted)

                        FlowLinks(sections: source.sections.filter { ($0.minAgeMonths ?? 0) <= months })
                    }
                }
            }
        }
    }
}

struct FlowLinks: View {
    let sections: [RecipeSource.Section]

    private let columns = [GridItem(.adaptive(minimum: 130), spacing: 7)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 7) {
            ForEach(sections) { section in
                if let url = URL(string: section.url) {
                    Link(destination: url) {
                        HStack(spacing: 5) {
                            Text(section.label)
                                .font(.system(size: 12, weight: .semibold))
                                .lineLimit(1)
                            if let tag = section.tag {
                                Text(tag)
                                    .font(.system(size: 9, weight: .bold))
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(MealTheme.marigoldSoft, in: Capsule())
                                    .foregroundStyle(MealTheme.sugar)
                            }
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .foregroundStyle(MealTheme.sugar)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.white, in: RoundedRectangle(cornerRadius: 9))
                    }
                }
            }
        }
    }
}

struct RecipeCard: View {
    let recipe: Recipe
    let foodsByID: [String: Food]
    var locked: Bool = false
    let onTap: () -> Void

    private var recipeFoods: [Food] { recipe.foodIDs.compactMap { foodsByID[$0] } }

    var body: some View {
        Button(action: onTap) {
            MealCard(background: locked ? MealTheme.milk : .white, dashed: locked) {
                VStack(alignment: .leading, spacing: 9) {
                    FoodColorStrip(colors: recipeFoods.map(\.color))

                    HStack(alignment: .top) {
                        Text(recipe.title)
                            .font(.system(size: 15.5, weight: .semibold))
                            .foregroundStyle(MealTheme.ink)
                            .multilineTextAlignment(.leading)
                        Spacer()
                        if locked {
                            MealBadge(text: "\(recipe.minAgeMonths) months", tint: MealTheme.muted, soft: MealTheme.line.opacity(0.4))
                        }
                    }

                    HStack(spacing: 3) {
                        ForEach(0..<5, id: \.self) { index in
                            Image(systemName: index < recipe.rating ? "star.fill" : "star")
                                .font(.system(size: 9))
                                .foregroundStyle(MealTheme.sugar.opacity(index < recipe.rating ? 0.9 : 0.25))
                        }
                        if !recipe.allergens.isEmpty {
                            Text("· \(recipe.allergens.joined(separator: ", "))")
                                .font(.system(size: 11))
                                .foregroundStyle(MealTheme.marigold)
                        }
                    }

                    if let flag = recipe.flag {
                        Text(flag)
                            .font(.system(size: 11.5))
                            .foregroundStyle(MealTheme.sugar)
                            .multilineTextAlignment(.leading)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }
}

struct RecipeDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var recipe: Recipe
    let foodsByID: [String: Food]
    var onChange: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper(
                        "Rating: \(recipe.rating)/5",
                        value: Binding(get: { recipe.rating }, set: { recipe.rating = $0; onChange() }),
                        in: 0...5
                    )
                }

                if let flag = recipe.flag {
                    Section { Text(flag).foregroundStyle(MealTheme.sugar) }
                }

                Section("Ingredients") {
                    ForEach(recipe.ingredients, id: \.self) { Text($0) }
                }

                Section("Method") {
                    ForEach(Array(recipe.steps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(index + 1).").foregroundStyle(.secondary)
                            Text(step)
                        }
                    }
                }

                if !recipe.spoonNote.isEmpty {
                    Section("Spoon-fed") { Text(recipe.spoonNote) }
                }
                if !recipe.blwNote.isEmpty {
                    Section("BLW") { Text(recipe.blwNote) }
                }

                Section("Storage") {
                    if !recipe.freezeNote.isEmpty { LabeledContent("Freezing", value: recipe.freezeNote) }
                    if !recipe.storeNote.isEmpty { LabeledContent("Fridge", value: recipe.storeNote) }
                }

                if !recipe.nutrients.isEmpty {
                    Section("Nutrients") { Text(recipe.nutrients.joined(separator: ", ")) }
                }

                if !recipe.allergens.isEmpty {
                    Section("Allergens") {
                        Text(recipe.allergens.joined(separator: ", "))
                            .foregroundStyle(MealTheme.marigold)
                    }
                }
            }
            .navigationTitle(recipe.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
