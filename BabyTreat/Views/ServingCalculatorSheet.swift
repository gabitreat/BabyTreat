import SwiftUI
import PhotosUI

/// Photograph a nutrition label, say how much was eaten, log what it comes to.
///
/// The scan fills the fields in; it never logs anything by itself. OCR gets
/// nutrition tables wrong often enough that every value stays editable and the
/// person confirms before it reaches the diary.
struct ServingCalculatorSheet: View {
    var slot: NutritionSlot = .snack
    let onAdd: (FoodEntry) -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Field?

    enum Field: Hashable {
        case name, kcal, protein, carbs, sugars, fat, fiber, salt
        case grams, servingCount, servingSize
    }

    @State private var name: String = ""
    @State private var chosenPhoto: PhotosPickerItem?
    @State private var labelImage: Image?
    @State private var isScanning = false
    @State private var scanError: String?
    @State private var didScan = false

    // Per 100 g, as text so a field can be genuinely empty rather than zero.
    @State private var kcal = ""
    @State private var protein = ""
    @State private var carbs = ""
    @State private var fat = ""
    @State private var fiber = ""
    @State private var sugars = ""
    @State private var salt = ""

    @State private var amountMode: AmountMode = .weight
    @State private var grams = "100"
    @State private var servingCount = "1"
    @State private var servingSize = "30"
    @State private var chosenSlot: NutritionSlot = .snack

    enum AmountMode: String, CaseIterable, Identifiable {
        case weight, servings
        var id: String { rawValue }
        var label: String { self == .weight ? "Weight" : "Servings" }
    }

    // MARK: - Derived

    private var per100: NutritionFacts {
        NutritionFacts(
            kcal: number(kcal), protein: number(protein), carbs: number(carbs),
            sugars: number(sugars), fat: number(fat), fiber: number(fiber),
            salt: number(salt)
        )
    }

    private var amount: ServingCalculator.Amount {
        switch amountMode {
        case .weight:
            .measure(number(grams) ?? 0)
        case .servings:
            .servings(count: number(servingCount) ?? 0, sizeGrams: number(servingSize) ?? 0)
        }
    }

    private var eaten: NutritionFacts {
        ServingCalculator.nutrition(per100: per100, amount: amount)
    }

    private var canAdd: Bool { blockingReason == nil }

    /// What is stopping this being added, in the person's words. A disabled
    /// button that will not say why is the worst of both worlds.
    private var blockingReason: String? {
        if name.trimmingCharacters(in: .whitespaces).isEmpty {
            return "Give it a name first."
        }
        if !per100.hasAnyValue {
            return "Add at least one value from the label."
        }
        if amount.grams <= 0 {
            return "Say how much was eaten."
        }
        return nil
    }

    var body: some View {
        NavigationStack {
            Form {
                photoSection
                labelSection
                amountSection
                resultSection
            }
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focused = nil }
                        .font(.body.weight(.semibold))
                }
            }
            .onChange(of: chosenPhoto) { _, item in
                Task { await load(item) }
            }
            .navigationTitle("Per serving")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onAdd(ServingCalculator.entry(
                            name: name.trimmingCharacters(in: .whitespaces),
                            per100: per100, amount: amount, slot: chosenSlot))
                        dismiss()
                    }
                    .disabled(!canAdd)
                }
            }
            .onAppear { chosenSlot = slot }
        }
    }

    // MARK: - Sections

    private var photoSection: some View {
        Section("Label photo") {
            PhotosPicker(selection: $chosenPhoto, matching: .images) {
                Label(didScan ? "Choose a different photo" : "Choose a photo",
                      systemImage: "text.viewfinder")
            }

            if let labelImage {
                labelImage
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            if isScanning {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Reading the label…")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if let scanError {
                Text(scanError)
                    .font(.footnote)
                    .foregroundStyle(NutritionTheme.accent)
            }

            if didScan {
                Text("Check every number against the packet before you add it — label scanning gets things wrong.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var labelSection: some View {
        Section("Per 100 g") {
            TextField("Name", text: $name)
                .focused($focused, equals: .name)
                .submitLabel(.done)
            nutrientField("Calories (kcal)", $kcal, .kcal)
            nutrientField("Protein (g)", $protein, .protein)
            nutrientField("Carbs (g)", $carbs, .carbs)
            nutrientField("of which sugars (g)", $sugars, .sugars)
            nutrientField("Fat (g)", $fat, .fat)
            nutrientField("Fibre (g)", $fiber, .fiber)
            nutrientField("Salt (g)", $salt, .salt)
        }
    }

    private var amountSection: some View {
        Section("How much was eaten") {
            Picker("Measured by", selection: $amountMode) {
                ForEach(AmountMode.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)

            switch amountMode {
            case .weight:
                LabeledContent("Grams") {
                    TextField("0", text: $grams)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .focused($focused, equals: .grams)
                }
            case .servings:
                LabeledContent("Servings") {
                    TextField("0", text: $servingCount)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .focused($focused, equals: .servingCount)
                }
                LabeledContent("One serving is (g)") {
                    TextField("0", text: $servingSize)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .focused($focused, equals: .servingSize)
                }
            }

            Picker("Meal", selection: $chosenSlot) {
                ForEach(NutritionSlot.allCases) { Text($0.label).tag($0) }
            }
        }
    }

    private var resultSection: some View {
        Section("That works out as") {
            resultRow("Calories", eaten.kcal, "kcal")
            resultRow("Protein", eaten.protein, "g")
            resultRow("Carbs", eaten.carbs, "g")
            resultRow("Fat", eaten.fat, "g")
            if eaten.fiber != nil { resultRow("Fibre", eaten.fiber, "g") }
            if eaten.salt != nil  { resultRow("Salt", eaten.salt, "g") }

            if per100.energyWasDerived {
                Text("Calories worked out from the kJ figure.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let blockingReason {
                Text(blockingReason)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(NutritionTheme.accent)
            }

            let missing = ServingCalculator.missingMacros(per100)
            if !missing.isEmpty {
                Text("No \(missing.joined(separator: ", ")) on the label — those will be logged as zero.")
                    .font(.footnote)
                    .foregroundStyle(NutritionTheme.accent)
            }
        }
    }

    // MARK: - Pieces

    private func nutrientField(_ label: String, _ text: Binding<String>, _ field: Field) -> some View {
        LabeledContent(label) {
            TextField("—", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .focused($focused, equals: field)
        }
    }

    private func resultRow(_ label: String, _ value: Double?, _ unit: String) -> some View {
        LabeledContent(label) {
            Text(value.map { "\(rounded($0)) \(unit)" } ?? "—")
                .monospacedDigit()
                .foregroundStyle(value == nil ? .secondary : .primary)
        }
    }

    private func rounded(_ value: Double) -> String {
        String(format: value < 10 ? "%.1f" : "%.0f", value)
    }

    /// Accepts a comma as the decimal point — the keypad offers whichever the
    /// device locale uses, and typing "1,5" should not silently become nothing.
    private func number(_ text: String) -> Double? {
        let cleaned = text.replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespaces)
        guard !cleaned.isEmpty else { return nil }
        return Double(cleaned)
    }

    /// Fills a field without throwing away what the label said.
    ///
    /// `rounded` is for the result readout, where a decimal place is noise. Here
    /// it would silently turn 14,9 g of protein into 15 and 28,3 g of fat into
    /// 28 — editing the person's data on the way in.
    private func fill(_ value: Double?) -> String {
        guard let value else { return "" }
        if value == value.rounded() { return String(format: "%.0f", value) }
        return String(format: "%g", (value * 100).rounded() / 100)
    }

    // MARK: - Scanning

    @MainActor
    private func load(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        scanError = nil
        isScanning = true
        defer { isScanning = false }

        guard let data = try? await item.loadTransferable(type: Data.self),
              let uiImage = UIImage(data: data) else {
            scanError = LabelScanner.ScanError.noImageData.localizedDescription
            return
        }
        labelImage = Image(uiImage: uiImage)

        do {
            let lines = try await LabelScanner.lines(in: uiImage)
            let facts = NutritionLabelParser.parse(lines: lines)
            apply(facts)
            didScan = true
        } catch {
            scanError = error.localizedDescription
        }
    }

    /// Only fills a field the scan actually found, and never overwrites
    /// something already typed by hand.
    private func apply(_ facts: NutritionFacts) {
        if kcal.isEmpty,    facts.kcal != nil    { kcal = fill(facts.kcal) }
        if protein.isEmpty, facts.protein != nil { protein = fill(facts.protein) }
        if carbs.isEmpty,   facts.carbs != nil   { carbs = fill(facts.carbs) }
        if sugars.isEmpty,  facts.sugars != nil  { sugars = fill(facts.sugars) }
        if fat.isEmpty,     facts.fat != nil     { fat = fill(facts.fat) }
        if fiber.isEmpty,   facts.fiber != nil   { fiber = fill(facts.fiber) }
        if salt.isEmpty,    facts.salt != nil    { salt = fill(facts.salt) }
    }
}
