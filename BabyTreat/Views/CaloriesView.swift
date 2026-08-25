import SwiftUI
import SwiftData

struct CaloriesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FoodEntry.timestamp) private var allEntries: [FoodEntry]
    @Query(sort: \CycleEvent.startDate, order: .reverse) private var cycles: [CycleEvent]

    private var store = EnergyProfileStore()

    @State private var addTarget: NutritionSlot?
    @State private var showServingCalculator = false
    @State private var showingBreakdown = true

    private var today: Date { Calendar.current.startOfDay(for: .now) }

    private var entries: [FoodEntry] {
        allEntries.filter { Calendar.current.isDate($0.timestamp, inSameDayAs: today) }
    }

    private var profile: EnergyEngine.Profile {
        store.profile(lastPeriodStart: cycles.first?.startDate)
    }

    private var breakdown: EnergyEngine.BudgetBreakdown { EnergyEngine.budget(profile: profile) }

    private var consumed: Double { entries.reduce(0) { $0 + $1.kcal } }
    private var remaining: Double { breakdown.total - consumed }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ring
                macros
                meals
                budgetSource
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Calories")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showServingCalculator = true
                } label: {
                    Image(systemName: "text.viewfinder")
                }
                .accessibilityLabel("Work out a serving from a label")
            }
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(destination: EnergySettingsView()) {
                    Image(systemName: "slider.horizontal.3")
                }
            }
        }
        .sheet(isPresented: $showServingCalculator) {
            ServingCalculatorSheet { entry in
                modelContext.insert(entry)
                try? modelContext.save()
            }
        }
        .sheet(item: $addTarget) { slot in
            AddFoodSheet(slot: slot) { entry in
                modelContext.insert(entry)
                try? modelContext.save()
            }
        }
    }

    // MARK: - Ring

    private var isOver: Bool { remaining < 0 }

    private var ring: some View {
        NutritionCard {
            ZStack {
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 18)
                Circle()
                    .trim(from: 0, to: min(max(consumed / max(breakdown.total, 1), 0), 1))
                    .stroke(
                        isOver ? NutritionTheme.over : NutritionTheme.accent,
                        style: StrokeStyle(lineWidth: 18, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.snappy, value: consumed)

                VStack(spacing: 2) {
                    Text("\(Int(abs(remaining).rounded()))")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(isOver ? NutritionTheme.over : .primary)
                    Text(isOver ? "kcal over" : "kcal remaining")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: 200)
            .frame(maxWidth: .infinity)

            HStack {
                Label("\(Int(consumed.rounded())) eaten", systemImage: "fork.knife")
                Spacer()
                Label("\(Int(breakdown.total.rounded())) budget", systemImage: "target")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)

            if breakdown.wasFloored {
                // Never silent. A budget that quietly ignores the goal is worse
                // than one that says why it did.
                Label(
                    "Your goal would put this at \(Int(breakdown.requested.rounded())) kcal. It is held at \(Int(breakdown.floor.rounded())) — the lowest safe intake\(profile.isBreastfeeding ? " while breastfeeding" : "").",
                    systemImage: "shield.lefthalf.filled"
                )
                .font(.footnote)
                .foregroundStyle(NutritionTheme.over)
            }
        }
    }

    // MARK: - Macros

    private var macros: some View {
        let protein = entries.reduce(0) { $0 + $1.protein }
        let carbs = entries.reduce(0) { $0 + $1.carbs }
        let fat = entries.reduce(0) { $0 + $1.fat }
        let target = EnergyEngine.proteinTarget(profile: profile)

        return NutritionCard {
            Text("Macros")
                .font(.headline)
            HStack(spacing: 12) {
                macro("Protein", protein, target: target, color: NutritionTheme.accent)
                macro("Carbs", carbs, target: nil, color: .teal)
                macro("Fat", fat, target: nil, color: .yellow)
            }
        }
    }

    private func macro(_ label: String, _ grams: Double, target: Double?, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(Int(grams.rounded())) g")
                .font(.title3.weight(.bold))
                .foregroundStyle(color)
            if let target {
                Text("of \(Int(target.rounded())) g")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Meals

    private var meals: some View {
        ForEach(NutritionSlot.allCases.sorted { $0.order < $1.order }) { slot in
            let slotEntries = entries.filter { $0.slot == slot }
            NutritionCard {
                HStack {
                    Label(slot.label, systemImage: slot.icon)
                        .font(.headline)
                    Spacer()
                    if !slotEntries.isEmpty {
                        Text("\(Int(slotEntries.reduce(0) { $0 + $1.kcal }.rounded())) kcal")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }

                ForEach(slotEntries) { entry in
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(entry.name)
                            if !entry.amountLabel.isEmpty {
                                Text(entry.amountLabel)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Text("\(Int(entry.kcal.rounded()))")
                            .font(.body.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    .swipeActions {
                        Button("Delete", role: .destructive) {
                            modelContext.delete(entry)
                            try? modelContext.save()
                        }
                    }
                    .contextMenu {
                        Button("Delete", role: .destructive) {
                            modelContext.delete(entry)
                            try? modelContext.save()
                        }
                    }
                }

                Button {
                    addTarget = slot
                } label: {
                    Label("Add food", systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(NutritionTheme.accent)
                }
            }
        }
    }

    // MARK: - Where the budget comes from

    private var budgetSource: some View {
        NutritionCard {
            DisclosureGroup(isExpanded: $showingBreakdown) {
                VStack(spacing: 7) {
                    row("Resting metabolism", breakdown.bmr)
                    row("Daily movement", breakdown.activityAdd)
                    if breakdown.lactationAdd > 0 {
                        row("Breastfeeding", breakdown.lactationAdd)
                    }
                    if breakdown.cycleAdd > 0, let phase = breakdown.phase {
                        row("\(phase.label) phase", breakdown.cycleAdd)
                    }
                    if breakdown.goalDelta != 0 {
                        row(store.goal.label, breakdown.goalDelta)
                    }
                    Divider()
                    row("Budget", breakdown.total, bold: true)
                }
                .padding(.top, 6)

                if breakdown.lactationAdd > 0, store.monthsPostpartum > 12 {
                    Text("The published lactation figures stop at 12 months. Past that this holds the 7–12 month value — an assumption, not guidance.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.top, 6)
                }
            } label: {
                Text("Where today's budget comes from")
                    .font(.headline)
            }
        }
    }

    private func row(_ label: String, _ value: Double, bold: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(bold ? .body.weight(.semibold) : .body)
            Spacer()
            Text("\(value > 0 && !bold ? "+" : "")\(Int(value.rounded()))")
                .font(bold ? .body.weight(.bold) : .body)
                .foregroundStyle(value < 0 ? NutritionTheme.over : .primary)
        }
    }
}

/// Manual entry. Stage 3 adds scanning and the saved-product picker on top of
/// this same sheet — a screen with no way to add anything cannot be reviewed.
struct AddFoodSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \SavedFood.lastUsed, order: .reverse) private var saved: [SavedFood]

    let slot: NutritionSlot
    var onAdd: (FoodEntry) -> Void

    @State private var name = ""
    @State private var kcal = ""
    @State private var protein = ""
    @State private var carbs = ""
    @State private var fat = ""
    @State private var grams = ""

    private var kcalValue: Double? { Double(kcal.replacingOccurrences(of: ",", with: ".")) }

    var body: some View {
        NavigationStack {
            Form {
                Section("What") {
                    TextField("Name", text: $name)
                }

                Section("Calories") {
                    HStack {
                        TextField("0", text: $kcal)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                        Text("kcal").foregroundStyle(.secondary)
                    }
                }

                Section("Amount, if you weighed it") {
                    HStack {
                        TextField("Optional", text: $grams)
                            .keyboardType(.decimalPad)
                        Text("g").foregroundStyle(.secondary)
                    }
                }

                Section("Macros, if you know them") {
                    macroField("Protein", $protein)
                    macroField("Carbs", $carbs)
                    macroField("Fat", $fat)
                }

                if !saved.isEmpty {
                    Section("Recently used") {
                        ForEach(saved.prefix(8)) { food in
                            Button {
                                name = food.brand.isEmpty ? food.name : "\(food.name) · \(food.brand)"
                                let portion = food.servingGrams ?? 100
                                grams = String(Int(portion))
                                let factor = portion / 100
                                kcal = String(Int((food.kcalPer100g * factor).rounded()))
                                protein = String(Int((food.proteinPer100g * factor).rounded()))
                                carbs = String(Int((food.carbsPer100g * factor).rounded()))
                                fat = String(Int((food.fatPer100g * factor).rounded()))
                            } label: {
                                HStack {
                                    Text(food.name)
                                    Spacer()
                                    Text("\(Int(food.kcalPer100g))/100g")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(slot.label)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        guard let kcalValue else { return }
                        onAdd(FoodEntry(
                            name: name.isEmpty ? "Food" : name,
                            kcal: kcalValue,
                            grams: Double(grams.replacingOccurrences(of: ",", with: ".")),
                            protein: Double(protein.replacingOccurrences(of: ",", with: ".")) ?? 0,
                            carbs: Double(carbs.replacingOccurrences(of: ",", with: ".")) ?? 0,
                            fat: Double(fat.replacingOccurrences(of: ",", with: ".")) ?? 0,
                            slot: slot
                        ))
                        dismiss()
                    }
                    .disabled(kcalValue == nil)
                }
            }
        }
    }

    private func macroField(_ label: String, _ text: Binding<String>) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("0", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 70)
            Text("g").foregroundStyle(.secondary)
        }
    }
}
