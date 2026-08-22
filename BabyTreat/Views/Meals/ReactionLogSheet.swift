import SwiftUI

/// Records something observed, at a time.
///
/// The timestamp is its own field and defaults to **now**, never to a meal.
/// Nothing on this sheet references the meal you last logged: prefilling it
/// would smuggle back the auto-attachment the model was built to avoid, and
/// the picker would quietly become "which meal caused this".
struct ReactionLogSheet: View {
    @Environment(\.dismiss) private var dismiss

    let existing: ReactionLog?
    var onSave: (_ observedAt: Date, _ severity: ToleranceLevel, _ symptoms: [String], _ notes: String) -> Void
    var onDelete: (() -> Void)?

    @State private var observedAt = Date()
    @State private var severity: ToleranceLevel = .mild
    @State private var symptoms: Set<String> = []
    @State private var notes = ""
    @State private var didLoad = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Noticed at", selection: $observedAt, in: ...Date())
                    HStack(spacing: 8) {
                        ForEach([15, 30, 60, 120], id: \.self) { minutes in
                            Button("−\(minutes < 60 ? "\(minutes)m" : "\(minutes / 60)h")") {
                                observedAt = Date().addingTimeInterval(-Double(minutes) * 60)
                            }
                            .buttonStyle(.bordered)
                            .font(.footnote)
                        }
                    }
                } header: {
                    Text("When")
                } footer: {
                    Text("When you saw it, not when a meal was. The two are worked out separately.")
                }

                Section {
                    Picker("Severity", selection: $severity) {
                        ForEach(ToleranceLevel.allCases) { level in
                            Text(level.label).tag(level)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()

                    Label(severity.hint, systemImage: severity.hardBlock ? "exclamationmark.octagon.fill" : "info.circle")
                        .font(.callout)
                        .foregroundStyle(severity.color)
                } header: {
                    Text("How bad")
                } footer: {
                    if severity == .dislike {
                        Text("A dislike is a taste signal, so it produces no candidates — nothing gets blamed for it.")
                    }
                }

                Section("What you saw") {
                    ForEach(ReactionLog.commonSymptoms, id: \.self) { symptom in
                        Button {
                            if symptoms.contains(symptom) { symptoms.remove(symptom) } else { symptoms.insert(symptom) }
                        } label: {
                            HStack {
                                Text(symptom).foregroundStyle(.primary)
                                Spacer()
                                if symptoms.contains(symptom) {
                                    Image(systemName: "checkmark").foregroundStyle(severity.color)
                                }
                            }
                        }
                    }
                }

                Section("Note") {
                    TextField("Anything else worth remembering", text: $notes, axis: .vertical)
                        .lineLimit(1...4)
                }

                if let onDelete, existing != nil {
                    Section {
                        Button("Delete this record", role: .destructive) {
                            onDelete()
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("Log a reaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(observedAt, severity, symptoms.sorted(),
                               notes.trimmingCharacters(in: .whitespaces))
                        dismiss()
                    }
                }
            }
            .onAppear {
                guard !didLoad else { return }
                didLoad = true
                if let existing {
                    observedAt = existing.observedAt
                    severity = existing.severity
                    symptoms = Set(existing.symptoms)
                    notes = existing.notes
                }
            }
        }
    }
}

/// Recorded reactions, each with the foods that could explain it.
struct ReactionCandidatesView: View {
    let reactions: [ReactionLog]
    let meals: [LoggedMeal]
    let foodsByID: [String: Food]
    var onEdit: (ReactionLog) -> Void

    var body: some View {
        if !reactions.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Eyebrow(text: "Reactions logged")
                ForEach(reactions.sorted { $0.observedAt > $1.observedAt }.prefix(6), id: \.observedAt) { reaction in
                    ReactionCard(
                        reaction: reaction,
                        candidates: ReactionAttribution.candidates(for: reaction, meals: meals),
                        foodsByID: foodsByID,
                        onEdit: { onEdit(reaction) }
                    )
                }
            }
        }
    }
}

struct ReactionCard: View {
    let reaction: ReactionLog
    let candidates: [ReactionAttribution.Candidate]
    let foodsByID: [String: Food]
    var onEdit: () -> Void

    /// Enough to be worth showing. Below this the food was one of several in a
    /// day-old meal and listing it adds noise, not information.
    private var shown: [ReactionAttribution.Candidate] {
        Array(candidates.filter { $0.score >= 0.05 }.prefix(5))
    }

    private var topScore: Double { candidates.first?.score ?? 1 }

    var body: some View {
        MealCard(background: reaction.severity.softColor, border: reaction.severity.color.opacity(0.4)) {
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Text(reaction.severity.label)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(MealTheme.ink)
                    Spacer()
                    Text(reaction.observedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 12))
                        .foregroundStyle(MealTheme.muted)
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(MealTheme.muted)
                    }
                    .buttonStyle(.plain)
                }

                if !reaction.symptoms.isEmpty {
                    Text(reaction.symptoms.joined(separator: " · "))
                        .font(.system(size: 12.5))
                        .foregroundStyle(MealTheme.muted)
                }

                if reaction.severity.needsPediatrician {
                    Label("Worth raising with the pediatrician", systemImage: "cross.case")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(reaction.severity.color)
                }

                if shown.isEmpty {
                    Text(reaction.countsForAttribution
                         ? "No meals logged in the 48 hours before this."
                         : "A dislike is a taste signal — nothing is blamed for it.")
                        .font(.system(size: 12.5))
                        .foregroundStyle(MealTheme.muted)
                } else {
                    Text("Possible, most likely first")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(MealTheme.muted)

                    ForEach(shown) { candidate in
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(foodsByID[candidate.foodID]?.color ?? MealTheme.line)
                                    .frame(width: 10, height: 10)
                                Text(foodsByID[candidate.foodID]?.name ?? candidate.foodID)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(MealTheme.ink)
                                Spacer()
                                Text(String(format: "%.2f", candidate.score))
                                    .font(.system(size: 12, weight: .bold).monospacedDigit())
                                    .foregroundStyle(MealTheme.muted)
                            }
                            // A bar, not a percentage: these are relative
                            // plausibility, not a probability of causation.
                            GeometryReader { geo in
                                Capsule()
                                    .fill(reaction.severity.color.opacity(0.55))
                                    .frame(width: geo.size.width * (candidate.score / max(topScore, 0.01)))
                            }
                            .frame(height: 3)
                            if let mechanism = candidate.leadingMechanism {
                                Text(mechanism)
                                    .font(.system(size: 10.5))
                                    .foregroundStyle(MealTheme.muted)
                            }
                        }
                    }

                    Text("Candidates, not a diagnosis. A food can appear here without being the cause.")
                        .font(.system(size: 11))
                        .foregroundStyle(MealTheme.muted)
                }
            }
        }
    }
}
