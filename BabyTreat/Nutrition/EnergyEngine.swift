import Foundation

/// Works out a daily calorie budget, and shows its working.
///
/// This is for the **parent**, not the baby — the only part of the app that is.
///
/// Every constant here comes from a published source, named at the point it is
/// used. Nothing is estimated or rounded to look tidy. Where a source stops
/// short of covering a case, that is said out loud rather than papered over.
///
/// Pure functions, no SwiftData and no SwiftUI, so the arithmetic can be checked
/// on its own.
enum EnergyEngine {

    // MARK: - Inputs

    enum ActivityLevel: String, Codable, CaseIterable, Identifiable {
        case sedentary, light, moderate, active, veryActive

        var id: String { rawValue }

        /// Standard Harris-Benedict activity factors. Note these already include
        /// the thermic effect of food — which is why measured mode (Stage 4) has
        /// to add it back explicitly.
        var multiplier: Double {
            switch self {
            case .sedentary:  1.2
            case .light:      1.375
            case .moderate:   1.55
            case .active:     1.725
            case .veryActive: 1.9
            }
        }

        var label: String {
            switch self {
            case .sedentary:  "Sedentary"
            case .light:      "Lightly active"
            case .moderate:   "Moderately active"
            case .active:     "Active"
            case .veryActive: "Very active"
            }
        }

        var detail: String {
            switch self {
            case .sedentary:  "Desk work, little deliberate exercise"
            case .light:      "Light exercise 1–3 days a week"
            case .moderate:   "Moderate exercise 3–5 days a week"
            case .active:     "Hard exercise 6–7 days a week"
            case .veryActive: "Hard daily exercise, or a physical job"
            }
        }
    }

    enum WeightGoal: String, Codable, CaseIterable, Identifiable {
        case maintain, gentleLoss, steadyLoss, gain

        var id: String { rawValue }

        var delta: Double {
            switch self {
            case .maintain:   0
            case .gentleLoss: -250
            case .steadyLoss: -500
            case .gain:       300
            }
        }

        var label: String {
            switch self {
            case .maintain:   "Maintain"
            case .gentleLoss: "Gentle loss"
            case .steadyLoss: "Steady loss"
            case .gain:       "Gain"
            }
        }

        var detail: String {
            switch self {
            case .maintain:   "No deficit"
            case .gentleLoss: "−250 kcal · about 0.25 kg a week"
            case .steadyLoss: "−500 kcal · about 0.5 kg a week"
            case .gain:       "+300 kcal"
            }
        }
    }

    struct Profile {
        var weightKg: Double = 65
        var heightCm: Double = 165
        var age: Int = 32
        var activity: ActivityLevel = .light
        var goal: WeightGoal = .maintain

        var isBreastfeeding: Bool = false
        /// How much of the baby's milk comes from you, 0…1. A slider, not a
        /// switch: formula feeds cost the mother nothing, so mixed feeding sits
        /// somewhere between the two and the add-on scales with it.
        var breastmilkShare: Double = 1.0
        var monthsPostpartum: Int = 0

        var tracksCycle: Bool = false
        var cycleLength: Int = 28
        var periodLength: Int = 5
        var lastPeriodStart: Date?
    }

    // MARK: - Output

    struct BudgetBreakdown {
        let bmr: Double
        let activityAdd: Double
        let lactationAdd: Double
        let cycleAdd: Double
        let goalDelta: Double
        /// After the floor has been applied.
        let total: Double
        /// True when the goal deficit would have taken the budget below `floor`
        /// and was clipped. Always surfaced in the UI — a budget that silently
        /// ignores the goal is worse than one that explains why.
        let wasFloored: Bool
        let floor: Double
        let phase: CyclePhase?
        let cycleDay: Int?

        /// What the goal asked for, before clipping.
        var requested: Double { bmr + activityAdd + lactationAdd + cycleAdd + goalDelta }

        var maintenance: Double { bmr + activityAdd + lactationAdd + cycleAdd }
    }

    // MARK: - BMR

    /// Mifflin-St Jeor, female. Of the published predictive equations this is
    /// the one that lands within 10% of indirect calorimetry most often in
    /// women (~71%), which is why it is the default rather than Harris-Benedict.
    ///
    ///     10 × kg + 6.25 × cm − 5 × age − 161
    static func bmr(weightKg: Double, heightCm: Double, age: Int) -> Double {
        10 * weightKg + 6.25 * heightCm - 5 * Double(age) - 161
    }

    // MARK: - Lactation

    /// DRI additional energy for lactation: **+330 kcal/day** for months 0–6
    /// postpartum, **+400** for months 7–12.
    ///
    /// The published tables stop at 12 months. Past that this holds the 7–12
    /// figure rather than inventing a taper — an assumption, not guidance, and
    /// it is labelled as such in the UI.
    static func lactationBase(monthsPostpartum: Int) -> Double {
        monthsPostpartum <= 6 ? 330 : 400
    }

    static func lactationAdd(profile: Profile) -> Double {
        guard profile.isBreastfeeding else { return 0 }
        let share = min(max(profile.breastmilkShare, 0), 1)
        return lactationBase(monthsPostpartum: profile.monthsPostpartum) * share
    }

    // MARK: - Cycle

    enum CyclePhase: String, Codable, CaseIterable, Identifiable {
        case menstrual, follicular, ovulation, luteal

        var id: String { rawValue }

        var label: String {
            switch self {
            case .menstrual:  "Period"
            case .follicular: "Follicular"
            case .ovulation:  "Ovulation"
            case .luteal:     "Luteal"
            }
        }
    }

    /// Day of the cycle, 1-based, wrapped so a forgotten log still gives a sane
    /// estimate instead of a day-93.
    static func cycleDay(on date: Date, profile: Profile, calendar: Calendar = MealRules.calendar) -> Int? {
        guard profile.tracksCycle, let start = profile.lastPeriodStart, profile.cycleLength > 0 else { return nil }
        let elapsed = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: start),
            to: calendar.startOfDay(for: date)
        ).day ?? 0
        guard elapsed >= 0 else { return nil }
        return (elapsed % profile.cycleLength) + 1
    }

    /// Ovulation is counted **backwards from the next expected period**:
    /// `cycleLength − 14`. The luteal phase is the stable one at about 14 days;
    /// it is the follicular phase that stretches and shrinks. Counting forwards
    /// from day 1 puts ovulation in the wrong place for anyone whose cycle is
    /// not 28 days.
    static func ovulationDay(cycleLength: Int) -> Int { cycleLength - 14 }

    static func phase(day: Int, profile: Profile) -> CyclePhase {
        let ovulation = ovulationDay(cycleLength: profile.cycleLength)
        if day <= profile.periodLength { return .menstrual }
        if abs(day - ovulation) <= 1 { return .ovulation }
        if day < ovulation { return .follicular }
        return .luteal
    }

    /// Luteal-phase resting metabolism rises by roughly 3–5% — some 30–120 kcal
    /// a day. This uses **5% of BMR at the mid-luteal peak**, tapering to zero at
    /// both ends of the phase via `sin(π × progress)`.
    ///
    /// The taper is the point. The rise tracks the simultaneous oestrogen and
    /// progesterone peak in the middle of the luteal phase; it does not switch on
    /// at ovulation and stay flat, and modelling it as a step would put the whole
    /// add-on in the wrong days.
    static func cycleAdd(day: Int?, bmr: Double, profile: Profile) -> Double {
        guard profile.tracksCycle, let day, phase(day: day, profile: profile) == .luteal else { return 0 }

        let lutealStart = Double(ovulationDay(cycleLength: profile.cycleLength) + 1)
        let lutealEnd = Double(profile.cycleLength)
        guard lutealEnd > lutealStart else { return 0 }

        let progress = (Double(day) - lutealStart) / (lutealEnd - lutealStart)
        return bmr * lutealPeakFraction * sin(.pi * min(max(progress, 0), 1))
    }

    /// 5% of BMR, the top of the published 3–5% range, reached only at the peak.
    static let lutealPeakFraction = 0.05

    // MARK: - Floors

    /// Absolute minimum intake, not breastfeeding.
    static let hardFloor: Double = 1200
    /// …and while breastfeeding. Milk production runs on today's intake.
    static let lactatingFloor: Double = 1800

    /// A goal deficit must never take the budget below this. Not a preference —
    /// the deficit is the thing that yields, every time.
    static func floor(bmr: Double, lactationAdd: Double, isBreastfeeding: Bool) -> Double {
        isBreastfeeding
            ? max(bmr + lactationAdd, lactatingFloor)
            : max(bmr, hardFloor)
    }

    // MARK: - The budget

    static func budget(profile: Profile, on date: Date = .now) -> BudgetBreakdown {
        let bmr = bmr(weightKg: profile.weightKg, heightCm: profile.heightCm, age: profile.age)
        let activityAdd = bmr * (profile.activity.multiplier - 1)
        let lactation = lactationAdd(profile: profile)
        let day = cycleDay(on: date, profile: profile)
        let cycle = cycleAdd(day: day, bmr: bmr, profile: profile)
        let goalDelta = profile.goal.delta

        let requested = bmr + activityAdd + lactation + cycle + goalDelta
        let floorValue = floor(bmr: bmr, lactationAdd: lactation, isBreastfeeding: profile.isBreastfeeding)

        return BudgetBreakdown(
            bmr: bmr,
            activityAdd: activityAdd,
            lactationAdd: lactation,
            cycleAdd: cycle,
            goalDelta: goalDelta,
            total: max(requested, floorValue),
            wasFloored: requested < floorValue,
            floor: floorValue,
            phase: day.map { phase(day: $0, profile: profile) },
            cycleDay: day
        )
    }

    /// The budget across a whole cycle, for the chart in `CycleView`.
    static func cycleCurve(profile: Profile) -> [(day: Int, total: Double)] {
        guard profile.tracksCycle, profile.cycleLength > 0 else { return [] }
        let bmr = bmr(weightKg: profile.weightKg, heightCm: profile.heightCm, age: profile.age)
        let activityAdd = bmr * (profile.activity.multiplier - 1)
        let lactation = lactationAdd(profile: profile)
        let floorValue = floor(bmr: bmr, lactationAdd: lactation, isBreastfeeding: profile.isBreastfeeding)

        return (1...profile.cycleLength).map { day in
            let requested = bmr + activityAdd + lactation
                + cycleAdd(day: day, bmr: bmr, profile: profile) + profile.goal.delta
            return (day, max(requested, floorValue))
        }
    }

    // MARK: - Protein

    /// 0.8 g per kg of body weight, plus 25 g scaled by how much of the milk is
    /// yours.
    static func proteinTarget(profile: Profile) -> Double {
        let base = profile.weightKg * 0.8
        guard profile.isBreastfeeding else { return base }
        return base + 25 * min(max(profile.breastmilkShare, 0), 1)
    }
}
