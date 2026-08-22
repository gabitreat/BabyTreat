import SwiftUI

struct EnergySettingsView: View {
    private var store = EnergyProfileStore()

    var body: some View {
        Form {
            Section("You") {
                stepperRow("Weight", value: store.$weightKg, range: 35...200, step: 0.5, unit: "kg")
                stepperRow("Height", value: store.$heightCm, range: 120...220, step: 1, unit: "cm")
                Stepper("Age: \(store.age)", value: store.$age, in: 14...80)
            }

            Section {
                Picker("Activity", selection: Binding(get: { store.activity }, set: { store.activity = $0 })) {
                    ForEach(EnergyEngine.ActivityLevel.allCases) { level in
                        Text(level.label).tag(level)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } header: {
                Text("Activity")
            } footer: {
                Text(store.activity.detail)
            }

            Section("Goal") {
                Picker("Goal", selection: Binding(get: { store.goal }, set: { store.goal = $0 })) {
                    ForEach(EnergyEngine.WeightGoal.allCases) { goal in
                        VStack(alignment: .leading) {
                            Text(goal.label)
                            Text(goal.detail).font(.caption).foregroundStyle(.secondary)
                        }
                        .tag(goal)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }

            Section {
                Toggle("Breastfeeding", isOn: store.$isBreastfeeding)
                if store.isBreastfeeding {
                    Stepper("Months postpartum: \(store.monthsPostpartum)", value: store.$monthsPostpartum, in: 0...36)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Breastmilk share")
                            Spacer()
                            Text("\(Int((store.breastmilkShare * 100).rounded()))%")
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: store.$breastmilkShare, in: 0...1, step: 0.05)
                            .tint(NutritionTheme.accent)
                    }
                }
            } header: {
                Text("Feeding")
            } footer: {
                if store.isBreastfeeding {
                    // A slider rather than a switch, because the add-on is not
                    // all-or-nothing: formula feeds cost the mother nothing.
                    Text("The extra energy scales with how much of the milk is yours: +\(Int(EnergyEngine.lactationBase(monthsPostpartum: store.monthsPostpartum))) kcal at 100%, nothing at 0%.")
                }
            }

            Section {
                Toggle("Track cycle", isOn: store.$tracksCycle)
                if store.tracksCycle {
                    Stepper("Cycle length: \(store.cycleLength) days", value: store.$cycleLength, in: 21...40)
                    Stepper("Period length: \(store.periodLength) days", value: store.$periodLength, in: 2...10)
                }
            } header: {
                Text("Cycle")
            } footer: {
                if store.tracksCycle {
                    Text("Resting metabolism rises in the luteal phase. Ovulation is counted back from the next expected period — day \(EnergyEngine.ovulationDay(cycleLength: store.cycleLength)) of \(store.cycleLength) — because the luteal phase is the stable one.")
                }
            }
        }
        .navigationTitle("Your profile")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func stepperRow(_ label: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double, unit: String) -> some View {
        Stepper(value: value, in: range, step: step) {
            HStack {
                Text(label)
                Spacer()
                Text("\(value.wrappedValue.formatted(.number.precision(.fractionLength(0...1)))) \(unit)")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
