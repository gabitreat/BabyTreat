import SwiftUI

/// The parent's profile, backed by `@AppStorage`.
///
/// A `DynamicProperty` rather than three copies of the same `@AppStorage`
/// declarations: any view can hold one, edits made in settings redraw the ring
/// on the calories screen, and there is a single place where the stored keys
/// are named.
struct EnergyProfileStore: DynamicProperty {
    @AppStorage("nutritionWeightKg")      var weightKg: Double = 65
    @AppStorage("nutritionHeightCm")      var heightCm: Double = 165
    @AppStorage("nutritionAge")           var age: Int = 32
    @AppStorage("nutritionActivity")      var activityRaw: String = EnergyEngine.ActivityLevel.light.rawValue
    @AppStorage("nutritionGoal")          var goalRaw: String = EnergyEngine.WeightGoal.maintain.rawValue

    @AppStorage("nutritionBreastfeeding") var isBreastfeeding: Bool = false
    @AppStorage("nutritionMilkShare")     var breastmilkShare: Double = 1.0
    @AppStorage("nutritionPostpartum")    var monthsPostpartum: Int = 0

    @AppStorage("nutritionTracksCycle")   var tracksCycle: Bool = false
    @AppStorage("nutritionCycleLength")   var cycleLength: Int = 28
    @AppStorage("nutritionPeriodLength")  var periodLength: Int = 5

    var activity: EnergyEngine.ActivityLevel {
        get { EnergyEngine.ActivityLevel(rawValue: activityRaw) ?? .light }
        nonmutating set { activityRaw = newValue.rawValue }
    }

    var goal: EnergyEngine.WeightGoal {
        get { EnergyEngine.WeightGoal(rawValue: goalRaw) ?? .maintain }
        nonmutating set { goalRaw = newValue.rawValue }
    }

    /// `lastPeriodStart` is not stored here — it comes from the most recent
    /// `CycleEvent`, so the log stays the single source of truth.
    func profile(lastPeriodStart: Date?) -> EnergyEngine.Profile {
        EnergyEngine.Profile(
            weightKg: weightKg,
            heightCm: heightCm,
            age: age,
            activity: activity,
            goal: goal,
            isBreastfeeding: isBreastfeeding,
            breastmilkShare: breastmilkShare,
            monthsPostpartum: monthsPostpartum,
            tracksCycle: tracksCycle,
            cycleLength: cycleLength,
            periodLength: periodLength,
            lastPeriodStart: lastPeriodStart
        )
    }
}

enum NutritionTheme {
    static let accent = Color(red: 0.96, green: 0.39, blue: 0.51)
    static let cycle = Color.indigo
    static let over = Color.orange
    static let cardRadius: CGFloat = 16
}

/// White rounded card on a grouped background — the convention the rest of the
/// non-tile screens already use.
struct NutritionCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: NutritionTheme.cardRadius))
    }
}
