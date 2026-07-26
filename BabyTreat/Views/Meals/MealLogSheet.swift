import SwiftUI

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
    var onSave: (_ portion: MealPortion, _ grams: Int?, _ note: String) -> Void
    var onClear: (() -> Void)?

    @State private var gramsText = ""
    @State private var portion: MealPortion = .all
    @State private var note = ""
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
                    Picker("Portion", selection: $portion) {
                        ForEach(MealPortion.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section("Note") {
                    TextField("Reaction, texture, anything worth remembering", text: $note, axis: .vertical)
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
            .navigationTitle(dish.isEmpty ? slot.label : dish)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(portion, grams, note.trimmingCharacters(in: .whitespaces))
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
                    portion = existing.portion
                    note = existing.note
                }
                gramsFocused = true
            }
        }
        .presentationDetents([.large])
    }
}
