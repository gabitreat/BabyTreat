import SwiftUI
import SwiftData

/// Cook once, cover one or two days.
struct SoupBatchSheet: View {
    let weekStart: Date
    let ageMonths: Int
    let recipes: [Recipe]
    let foodsByID: [String: Food]
    let onCreate: (Recipe, Date, Int, Date) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var recipeID: String = ""
    @State private var startDate: Date = MealRules.startOfDay(.now)
    @State private var spanDays: Int = 2
    @State private var cookedAt: Date = .now
    @State private var acknowledgedFridge = false

    /// Soups only, and only ones old enough. This is the same filter the dinner
    /// suggestions use, so the batch list can't offer something the plan won't.
    private var soups: [Recipe] {
        DinnerRule.suggestions(from: recipes, slot: .dinner, ageMonths: ageMonths)
            .sorted { $0.title < $1.title }
    }

    private var recipe: Recipe? { soups.first { $0.id == recipeID } }

    private var risk: NitrateRisk? {
        recipe.map { $0.nitrateRisk(foodsByID: foodsByID) }
    }

    private var maxSpan: Int {
        guard let risk else { return 2 }
        return BatchSafety.maxSpanDays(risk: risk)
    }

    private var lockReason: String? {
        guard let risk else { return nil }
        return BatchSafety.spanLockReason(risk: risk)
    }

    private var containsRice: Bool {
        recipe?.ingredients.contains { $0.localizedCaseInsensitiveContains("rice") } ?? false
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Soup") {
                    if soups.isEmpty {
                        Text("No soups available yet for \(ageMonths) months.")
                            .font(.system(size: 13))
                            .foregroundStyle(MealTheme.muted)
                    }
                    Picker("Recipe", selection: $recipeID) {
                        Text("Pick one").tag("")
                        ForEach(soups) { Text($0.title).tag($0.id) }
                    }
                    if let risk {
                        HStack {
                            Text(risk.label)
                                .font(.system(size: 12.5, weight: .semibold))
                                .foregroundStyle(riskTint(risk))
                            Spacer()
                        }
                    }
                }

                Section("Days") {
                    DatePicker("First day", selection: $startDate, displayedComponents: .date)
                    Stepper("Covers \(spanDays) day\(spanDays == 1 ? "" : "s")",
                            value: $spanDays, in: 1...max(1, maxSpan))
                    if let lockReason {
                        Text(lockReason)
                            .font(.system(size: 12.5))
                            .foregroundStyle(MealTheme.sugar)
                    }
                }

                Section("Cooked") {
                    DatePicker("Finished cooking", selection: $cookedAt)
                    Text("You'll get a nudge \(Int(BatchSafety.coolingWindowMinutes)) minutes after this to portion and chill it.")
                        .font(.system(size: 12))
                        .foregroundStyle(MealTheme.muted)
                }

                if spanDays == 2 {
                    Section("Day two") {
                        Label("Goes in the freezer", systemImage: "snowflake")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(MealTheme.lagoon)
                        Text(BatchSafety.secondFridgeDayWarning)
                            .font(.system(size: 12.5))
                            .foregroundStyle(MealTheme.muted)
                        Toggle("Use the fridge instead", isOn: $acknowledgedFridge)
                            .font(.system(size: 13.5))
                        if acknowledgedFridge {
                            Text("Then it has to be eaten within 24 hours of cooking, or thrown out.")
                                .font(.system(size: 12.5, weight: .semibold))
                                .foregroundStyle(MealTheme.bubblegum)
                        }
                    }
                }

                Section("Reheating") {
                    Text(BatchSafety.reheatRule(containsRice: containsRice))
                        .font(.system(size: 12.5))
                        .foregroundStyle(MealTheme.muted)
                }
            }
            .navigationTitle("Cook a batch")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let recipe {
                            onCreate(recipe, startDate, min(spanDays, maxSpan), cookedAt)
                        }
                        dismiss()
                    }
                    .disabled(recipe == nil)
                }
            }
            .onChange(of: recipeID) {
                // A high-nitrate pick silently sitting at 2 days would be the
                // one bug this screen cannot afford.
                if spanDays > maxSpan { spanDays = maxSpan }
            }
            .onAppear {
                if recipeID.isEmpty { recipeID = soups.first?.id ?? "" }
                startDate = MealRules.startOfDay(max(weekStart, MealRules.startOfDay(.now)))
            }
        }
    }

    private func riskTint(_ risk: NitrateRisk) -> Color {
        switch risk {
        case .low:      MealTheme.lagoon
        case .moderate: MealTheme.marigold
        case .high:     MealTheme.bubblegum
        }
    }
}

/// One cook, rendered as a single card spanning the days it covers.
struct BatchCard: View {
    let batch: SoupBatch
    let recipe: Recipe?
    let onDiscard: () -> Void

    @State private var confirmingDiscard = false

    private var dayLabel: String {
        let days = batch.coveredDays
        guard let first = days.first else { return "" }
        guard days.count > 1, let last = days.last else { return first.batchDayShort }
        return "\(first.batchDayShort)–\(last.batchDayShort)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(recipe?.title ?? "Soup")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(batch.isDiscarded ? MealTheme.muted : MealTheme.ink)
                    .strikethrough(batch.isDiscarded)
                Spacer()
                Text(dayLabel)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(MealTheme.muted)
            }

            Text("Cooked \(batch.cookedAt.formatted(date: .abbreviated, time: .shortened))")
                .font(.system(size: 12))
                .foregroundStyle(MealTheme.muted)

            // One badge per covered day, so the storage decision is visible
            // without opening anything.
            HStack(spacing: 8) {
                ForEach(Array(batch.coveredDays.enumerated()), id: \.offset) { _, day in
                    let expiry = BatchSafety.expiry(for: batch, on: day)
                    StorageBadge(
                        day: day,
                        method: batch.storage(on: day),
                        isExpired: !expiry.isServable
                    )
                }
                Spacer()
            }

            if let reason = firstProblem {
                Text(reason)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(MealTheme.bubblegum)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if BatchSafety.coolingOverdue(for: batch), !batch.isDiscarded {
                Label(BatchSafety.coolingMessage, systemImage: "thermometer.snowflake")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(MealTheme.marigold)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !batch.isDiscarded {
                Button(role: .destructive) {
                    confirmingDiscard = true
                } label: {
                    Text("Threw it out")
                        .font(.system(size: 12.5, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(MealTheme.muted)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(MealTheme.line, lineWidth: 1)
        )
        .confirmationDialog("Throw this batch out?", isPresented: $confirmingDiscard, titleVisibility: .visible) {
            Button("Throw it out", role: .destructive, action: onDiscard)
            Button("Keep it", role: .cancel) {}
        } message: {
            Text("Meals you've already logged stay in the journal. Only the planned ones are removed.")
        }
    }

    private var firstProblem: String? {
        batch.coveredDays
            .lazy
            .compactMap { BatchSafety.expiry(for: batch, on: $0).reason }
            .first
    }
}

struct StorageBadge: View {
    let day: Date
    let method: StorageMethod?
    let isExpired: Bool

    private var icon: String {
        switch method {
        case .fresh:        "flame"
        case .refrigerated: "refrigerator"
        case .frozen:       "snowflake"
        case nil:           "questionmark"
        }
    }

    private var tint: Color {
        if isExpired { return MealTheme.bubblegum }
        switch method {
        case .fresh:        return MealTheme.marigold
        case .refrigerated: return MealTheme.sugar
        case .frozen:       return MealTheme.lagoon
        case nil:           return MealTheme.muted
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(day.batchDayShort)
        }
        .font(.system(size: 11.5, weight: .semibold))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(tint.opacity(0.16), in: Capsule())
        .foregroundStyle(tint)
    }
}

extension Date {
    /// "Mon" — just the weekday, for the batch badges. The full day label is
    /// `mealDayLabel`; two of those side by side would not fit a badge.
    var batchDayShort: String {
        let formatter = DateFormatter()
        formatter.calendar = MealRules.calendar
        formatter.locale = Locale(identifier: "en_GB")
        formatter.dateFormat = "EEE"
        return formatter.string(from: self)
    }
}
