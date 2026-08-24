import SwiftUI
import SwiftData

enum MealTab: String, CaseIterable, Identifiable {
    case today, week, foods, recipes, shopping
    var id: String { rawValue }

    var label: String {
        switch self {
        // Kept short — five segments have to fit a phone width.
        case .today:    "Today"
        case .week:     "Week"
        case .foods:    "Foods"
        case .recipes:  "Recipes"
        case .shopping: "List"
        }
    }
}

struct MealsView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("babyName") private var babyName: String = ""
    @AppStorage("babyBirthDate") private var birthDateStamp: Double = MealSeed.birthDate.timeIntervalSince1970

    @State private var tab: MealTab = .today

    private var birthDate: Date { Date(timeIntervalSince1970: birthDateStamp) }

    var body: some View {
        VStack(spacing: 0) {
            MealsHeader(babyName: babyName, birthDate: birthDate)

            Picker("", selection: $tab) {
                ForEach(MealTab.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, MealTheme.pad)
            .padding(.vertical, 10)

            Group {
                switch tab {
                case .today:    MealsTodayView(birthDate: birthDate)
                case .week:     MealsWeekView(birthDate: birthDate)
                case .foods:    MealsFoodsView()
                case .recipes:  MealsRecipesView(birthDate: birthDate)
                case .shopping: MealsShoppingView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(MealTheme.milk)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            MealSeed.installIfNeeded(in: modelContext)
            MealSeed.installMissingFoods(in: modelContext)
            MealSeed.installMissingRecipes(in: modelContext)
            MealSeed.backfillClassification(in: modelContext)
            MealSeed.backfillRecipeForms(in: modelContext)
            // The week ahead is planned before the shopping list is built from
            // it — the list tab's own task runs later, and reads the menu this
            // leaves behind. From Sunday, "the week ahead" is next week.
            MealPlanner.autoPlanIfNeeded(birthDate: birthDate, in: modelContext)
        }
    }
}

/// Gradient header with the age pill and the milestone bar. Stages turn over on
/// the birth day of each month — for a 23 December birth date, the 23rd.
struct MealsHeader: View {
    let babyName: String
    let birthDate: Date

    private var today: Date { MealRules.startOfDay(.now) }
    private var months: Int { MealRules.ageMonths(on: today, birthDate: birthDate) }
    private var nextStage: Date { MealRules.nextStageDate(after: today, birthDate: birthDate) }
    private var daysToNextStage: Int { MealRules.daysBetween(today, nextStage) }

    /// Progress through the current month-stage.
    private var stageProgress: Double {
        let start = MealRules.calendar.date(byAdding: .month, value: months, to: MealRules.startOfDay(birthDate)) ?? today
        let total = max(1, MealRules.daysBetween(start, nextStage))
        return min(1, max(0, Double(MealRules.daysBetween(start, today)) / Double(total)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline) {
                Text(babyName.isEmpty ? "Bebe" : babyName)
                    .font(.system(size: 27, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                Eyebrow(text: "Solids", color: MealTheme.headerAccent)
            }

            HStack(spacing: 7) {
                Text("\(months) months")
                    .fontWeight(.semibold)
                Text("· \(MealSeed.formula)")
                    .fontWeight(.regular)
                    .foregroundStyle(MealTheme.headerSubtle)
            }
            .font(.system(size: 14))
            .foregroundStyle(MealTheme.headerAccent)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(MealTheme.lagoon.opacity(0.24), in: Capsule())

            VStack(spacing: 7) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.18))
                        Capsule().fill(MealTheme.lagoon)
                            .frame(width: geo.size.width * stageProgress)
                    }
                }
                .frame(height: 6)

                HStack {
                    Text("\(months) month stage")
                    Spacer()
                    Text("\(months + 1) months in \(daysToNextStage) days")
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(MealTheme.headerSubtle)
            }
        }
        .padding(.horizontal, MealTheme.pad)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MealTheme.headerGradient)
        .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 20, bottomTrailingRadius: 20))
    }
}

// MARK: - Shared pieces

/// A food rendered as its own colour. Accepted foods are solid, weakly-accepted
/// fade out, planned ones are dashed outlines — the Foods tab literally grows
/// more colourful as acceptance grows.
struct FoodChip: View {
    let food: Food
    var compact: Bool = false

    private var isLight: Bool {
        // Rough luminance test so pale foods (cartof alb, usturoi) keep dark text.
        let hex = food.colorHex.hasPrefix("#") ? String(food.colorHex.dropFirst()) : food.colorHex
        guard let value = UInt32(hex, radix: 16) else { return true }
        let r = Double((value >> 16) & 0xFF), g = Double((value >> 8) & 0xFF), b = Double(value & 0xFF)
        return (0.299 * r + 0.587 * g + 0.114 * b) > 150
    }

    var body: some View {
        Text(food.name)
            .font(.system(size: compact ? 12 : 13, weight: .semibold))
            .padding(.horizontal, compact ? 8 : 10)
            .padding(.vertical, compact ? 4 : 6)
            .background(background)
            .foregroundStyle(foreground)
            .overlay(
                Capsule().strokeBorder(
                    food.status == .planned ? food.color.opacity(0.9) : .clear,
                    style: StrokeStyle(lineWidth: 1.4, dash: [4, 3])
                )
            )
            .clipShape(Capsule())
    }

    private var background: Color {
        switch food.status {
        case .accepted: food.color
        case .weak:     food.color.opacity(0.35)
        case .planned:  .clear
        }
    }

    private var foreground: Color {
        switch food.status {
        case .accepted: isLight ? MealTheme.ink : .white
        case .weak:     MealTheme.ink
        case .planned:  MealTheme.muted
        }
    }
}

/// Small pill used for warnings and status notes.
struct MealBadge: View {
    let text: String
    var tint: Color = MealTheme.lagoon
    var soft: Color = MealTheme.lagoonSoft

    var body: some View {
        Text(text)
            .font(.system(size: 11.5, weight: .semibold))
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(soft, in: Capsule())
            .foregroundStyle(tint)
    }
}

extension Date {
    /// "Mon 27 Jul" — the prototype's day label, in English.
    var mealDayLabel: String {
        let formatter = DateFormatter()
        formatter.calendar = MealRules.calendar
        formatter.locale = Locale(identifier: "en_GB")
        formatter.dateFormat = "EEE d MMM"
        return formatter.string(from: self)
    }
}
