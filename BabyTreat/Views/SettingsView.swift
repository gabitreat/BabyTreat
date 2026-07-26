import SwiftUI

struct SettingsView: View {
    @AppStorage("temperatureUnit") private var temperatureUnit: String = "celsius"
    @AppStorage("babyName") private var babyName: String = ""
    @AppStorage("babyBirthDate") private var birthDateStamp: Double = MealSeed.birthDate.timeIntervalSince1970

    private var birthDate: Binding<Date> {
        Binding(
            get: { Date(timeIntervalSince1970: birthDateStamp) },
            set: { birthDateStamp = $0.timeIntervalSince1970 }
        )
    }

    /// Meal-planning age gates are computed from this, so it has to be a date.
    /// A stored month count goes stale the day after it is entered.
    private var ageMonths: Int {
        MealRules.ageMonths(on: .now, birthDate: birthDate.wrappedValue)
    }

    var body: some View {
        Form {
            Section("Baby") {
                TextField("Name", text: $babyName)
                DatePicker("Born", selection: birthDate, displayedComponents: .date)
                LabeledContent("Age", value: "\(ageMonths) month\(ageMonths == 1 ? "" : "s")")
            }

            Section("Units") {
                Picker("Temperature", selection: $temperatureUnit) {
                    Text("°C").tag("celsius")
                    Text("°F").tag("fahrenheit")
                }
                .pickerStyle(.segmented)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}
