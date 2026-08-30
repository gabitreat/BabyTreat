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

    /// When on, movement comes from Health and the activity picker stops
    /// applying. See `activity` below — this is C1, and it is worth 600 kcal a
    /// day if it ever stops holding.
    @AppStorage("nutritionUseHealthEnergy")    var useHealthKitActiveEnergy: Bool = false
    /// The fraction of the wearable's figure that reaches the budget.
    @AppStorage("nutritionActiveEnergyCredit") var activeEnergyCreditFactor: Double = ActiveEnergyWindow.defaultCreditFactor
    /// Comma-joined bundle identifiers of the sources the user trusts.
    @AppStorage("nutritionActiveEnergySources") var enabledSourceIDsRaw: String = ""
    /// When a previously trusted source first went missing from Health, so a
    /// week of silence can raise a notice instead of quietly crediting zero.
    /// Zero means "not missing".
    @AppStorage("nutritionActiveEnergyMissingSince") var missingSourceSinceStamp: Double = 0

    @AppStorage("nutritionTracksCycle")   var tracksCycle: Bool = false
    @AppStorage("nutritionCycleLength")   var cycleLength: Int = 28
    @AppStorage("nutritionPeriodLength")  var periodLength: Int = 5

    /// What the picker shows, and what comes back if Health is switched off.
    /// Stored even while Health is on, so turning the toggle off restores the
    /// choice rather than resetting it.
    var selectedActivity: EnergyEngine.ActivityLevel {
        get { EnergyEngine.ActivityLevel(rawValue: activityRaw) ?? .light }
        nonmutating set {
            // Ignored while Health is supplying the movement. The picker is
            // disabled in that state, so this is the belt to the UI's braces.
            guard !useHealthKitActiveEnergy else { return }
            activityRaw = newValue.rawValue
        }
    }

    /// The multiplier the budget actually uses.
    ///
    /// Mifflin-St Jeor times 1.375 or 1.55 **already contains** a day's walking
    /// and exercise. Adding a watch's active energy on top counts the same
    /// movement twice — 300 to 700 kcal a day for someone who moves. So when
    /// Health is on, the multiplier is pinned to sedentary and every calorie of
    /// movement arrives as a measurement instead (C1).
    var activity: EnergyEngine.ActivityLevel {
        get { useHealthKitActiveEnergy ? .sedentary : selectedActivity }
        nonmutating set { selectedActivity = newValue }
    }

    /// The sources the user ticked. Empty means nothing is credited.
    var enabledSourceIDs: Set<String> {
        get {
            Set(enabledSourceIDsRaw
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty })
        }
        nonmutating set { enabledSourceIDsRaw = newValue.sorted().joined(separator: ",") }
    }

    var creditFactor: Double {
        get { ActiveEnergyWindow.clampFactor(activeEnergyCreditFactor) }
        nonmutating set { activeEnergyCreditFactor = ActiveEnergyWindow.clampFactor(newValue) }
    }

    var missingSourceSince: Date? {
        get { missingSourceSinceStamp > 0 ? Date(timeIntervalSince1970: missingSourceSinceStamp) : nil }
        nonmutating set { missingSourceSinceStamp = newValue?.timeIntervalSince1970 ?? 0 }
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
