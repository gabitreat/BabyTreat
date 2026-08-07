import SwiftUI

/// Everything recorded about one meal after the fact.
struct MealLogDraft {
    var portion: MealPortion = .all
    var grams: Int?
    var note: String = ""
    var tolerance: ToleranceLevel?
    var toleranceNote: String = ""
    var excludeFromTaste: Bool = false
}

/// Records what was actually eaten. Opens with the grams field focused and the
/// number pad already up — this gets used at the table, one-handed, with a baby
/// in the other arm.
struct MealLogSheet: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var gramsFocused: Bool

    let date: Date
    let slot: MealSlot
    let dish: String
    let existing: MealLog?
    /// Who would carry the flag if one were recorded, worked out from how well
    /// each food in this meal is already proven. Nil when it can't be computed.
    var attribution: ToleranceEngine.Attribution?
    /// Display names for the food IDs `attribution` returns.
    var nameForFood: (String) -> String = { $0 }
    var onSave: (MealLogDraft) -> Void
    var onClear: (() -> Void)?

    @State private var gramsText = ""
    @State private var draft = MealLogDraft()
    @State private var didLoad = false

    private var grams: Int? { Int(gramsText.filter(\.isNumber)) }

    var body: some View {
        NavigationStack {
            Form {
                Section("Amount eaten") {
                    HStack {
                        TextField("0", text: $gramsText)
                            .keyboardType(.numberPad)
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .focused($gramsFocused)
                        Text("g")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    if grams != nil {
                        Button("Clear amount") { gramsText = "" }
                            .font(.callout)
                    }
                }

                Section("How it went") {
                    // Kept alongside grams: 40 g of a 40 g portion and 40 g of a
                    // 120 g portion are the same number and different meals.
                    Picker("Portion", selection: $draft.portion) {
                        ForEach(MealPortion.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                // Only asked when the meal actually went badly. Above "a few
                // spoons" this question would appear after almost every meal and
                // be tapped past within a week.
                if draft.portion.triggersTolerance {
                    toleranceSection
                    if draft.tolerance != nil {
                        attributionSection
                    }
                    excludeSection
                }

                Section("Note") {
                    TextField("Texture, mood, anything worth remembering", text: $draft.note, axis: .vertical)
                        .lineLimit(1...4)
                }

                if let onClear, existing != nil {
                    Section {
                        Button("Remove this log", role: .destructive) {
                            onClear()
                            dismiss()
                        }
                    }
                }
            }
            .animation(.snappy(duration: 0.22), value: draft.portion.triggersTolerance)
            .animation(.snappy(duration: 0.22), value: draft.tolerance)
            .navigationTitle(dish.isEmpty ? slot.label : dish)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var out = draft
                        out.grams = grams
                        out.note = draft.note.trimmingCharacters(in: .whitespaces)
                        out.toleranceNote = draft.toleranceNote.trimmingCharacters(in: .whitespaces)
                        // A cleared portion takes its tolerance with it, rather
                        // than leaving an orphaned flag on a meal that went fine.
                        if !out.portion.triggersTolerance {
                            out.tolerance = nil
                            out.toleranceNote = ""
                            out.excludeFromTaste = false
                        }
                        onSave(out)
                        dismiss()
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { gramsFocused = false }
                }
            }
            .onAppear {
                guard !didLoad else { return }
                didLoad = true
                if let existing {
                    gramsText = existing.grams.map(String.init) ?? ""
                    draft = MealLogDraft(
                        portion: existing.portion,
                        grams: existing.grams,
                        note: existing.note,
                        tolerance: existing.tolerance,
                        toleranceNote: existing.toleranceNote ?? "",
                        excludeFromTaste: existing.isExcludedFromTaste
                    )
                }
                gramsFocused = true
            }
        }
        .presentationDetents([.large])
    }

    // MARK: - Tolerance

    private var toleranceSection: some View {
        Section {
            Picker("Reaction", selection: $draft.tolerance) {
                Text("Nothing to record").tag(ToleranceLevel?.none)
                ForEach(ToleranceLevel.allCases) { level in
                    Text(level.label).tag(ToleranceLevel?.some(level))
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()

            if let level = draft.tolerance {
                Label(level.hint, systemImage: level.hardBlock ? "exclamationmark.octagon.fill" : "info.circle")
                    .font(.callout)
                    .foregroundStyle(level.color)

                TextField("What you saw", text: $draft.toleranceNote, axis: .vertical)
                    .lineLimit(1...3)
            }
        } header: {
            Text("Was there a reaction?")
        } footer: {
            // The distinction the whole feature turns on.
            Text("\"Didn't like it\" is not a reaction. A disliked food keeps coming back — that is how acceptance happens. A food with symptoms comes off the menu.")
        }
    }

    @ViewBuilder
    private var attributionSection: some View {
        if let attribution, let level = draft.tolerance {
            Section("What this affects") {
                switch attribution {
                case .single(let id):
                    Label(consequence(for: level, food: nameForFood(id)), systemImage: "arrow.right.circle")
                        .font(.callout)

                case .ambiguous(let ids):
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Reaction can't be attributed to a single food — all were paused and will be retested separately.")
                        Text(ids.map(nameForFood).joined(separator: ", "))
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(level.color)
                    }
                    .font(.callout)

                case .unattributed:
                    Text("Every food in this meal has been eaten cleanly before, so nothing is paused. The reaction is still recorded.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                if level.needsPediatrician {
                    Label("Worth raising with the pediatrician.", systemImage: "cross.case")
                        .font(.callout)
                        .foregroundStyle(MealTheme.sugar)
                }
            }
        }
    }

    private func consequence(for level: ToleranceLevel, food: String) -> String {
        switch level {
        case .dislike:  "\(food) stays on the menu. Taste refusals need repeat exposure, not removal."
        case .mild:     "\(food) is paused for \(level.suppressDays ?? 0) days, then offered again."
        case .moderate: "\(food) is held until you clear it."
        case .severe:   "\(food) is blocked. Clearing it takes a deliberate confirmation."
        }
    }

    private var excludeSection: some View {
        Section {
            Toggle("Something else explains it", isOn: $draft.excludeFromTaste)
        } footer: {
            Text("Illness, teething, a meal two hours late. Keeps this one out of the taste comparisons.")
        }
    }
}
