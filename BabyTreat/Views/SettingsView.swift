import SwiftUI

struct SettingsView: View {
    @AppStorage("temperatureUnit") private var temperatureUnit: String = "celsius"
    @AppStorage("babyName") private var babyName: String = ""
    @AppStorage("babyAgeMonths") private var babyAgeMonths: Int = 0

    var body: some View {
        Form {
            Section("Baby") {
                TextField("Name", text: $babyName)
                Stepper("Age: \(babyAgeMonths) month\(babyAgeMonths == 1 ? "" : "s")", value: $babyAgeMonths, in: 0...48)
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
