import SwiftUI
import SwiftData

@main
struct BabyTreatApp: App {

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [
            Medicine.self, TemperatureReading.self, SleepRecord.self, PlaytimeRecord.self, NursingRecord.self,
            Food.self, Recipe.self, MenuEntry.self, MealLog.self, ShoppingItem.self,
            FoodEntry.self, SavedFood.self, CycleEvent.self, FoodProduct.self,
            ReactionLog.self, SoupBatch.self, PeriodStart.self, BeverageEntry.self,
        ])
    }
}
