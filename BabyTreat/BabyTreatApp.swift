import SwiftUI
import SwiftData

@main
struct BabyTreatApp: App {

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Medicine.self, TemperatureReading.self, SleepRecord.self, PlaytimeRecord.self, NursingRecord.self])
    }
}
