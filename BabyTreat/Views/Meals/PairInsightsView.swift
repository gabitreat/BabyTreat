import SwiftUI
import SwiftData

/// Foods currently held back by something recorded in the journal, and what it
/// would take to release them.
struct ToleranceFlagsView: View {
    let flags: [ToleranceEngine.FoodFlag]
    let foodsByID: [String: Food]
    var onClear: (ToleranceEngine.FoodFlag) -> Void

    @State private var confirming: ToleranceEngine.FoodFlag?

    var body: some View {
        if !flags.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Eyebrow(text: "Reactions")
                ForEach(flags) { flag in
                    MealCard(background: flag.level.softColor, border: flag.level.color.opacity(0.4)) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 9) {
                                Circle().fill(foodsByID[flag.foodID]?.color ?? flag.level.color)
                                    .frame(width: 12, height: 12)
                                Text(foodsByID[flag.foodID]?.name ?? flag.foodID)
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(MealTheme.ink)
                                Spacer()
                                MealBadge(text: statusLabel(flag.status), tint: flag.level.color, soft: .white)
                            }

                            Text(detail(for: flag))
                                .font(.system(size: 12.5))
                                .foregroundStyle(MealTheme.muted)

                            if flag.isShared {
                                Text("Shared a meal with other unproven foods — all of them were paused, to be retested separately.")
                                    .font(.system(size: 12))
                                    .foregroundStyle(MealTheme.muted)
                            }

                            if flag.needsPediatrician {
                                Label("Worth raising with the pediatrician", systemImage: "cross.case")
                                    .font(.system(size: 12.5, weight: .semibold))
                                    .foregroundStyle(flag.level.color)
                            }

                            if flag.status != .retry {
                                Button(flag.level.hardBlock ? "Clear this block…" : "Clear this flag") {
                                    if flag.level.hardBlock {
                                        confirming = flag
                                    } else {
                                        onClear(flag)
                                    }
                                }
                                .font(.system(size: 13.5, weight: .semibold))
                                .foregroundStyle(flag.level.color)
                            }
                        }
                    }
                }
            }
            .alert(
                "Unblock \(confirming.map { foodsByID[$0.foodID]?.name ?? $0.foodID } ?? "")?",
                isPresented: Binding(get: { confirming != nil }, set: { if !$0 { confirming = nil } }),
                presenting: confirming
            ) { flag in
                Button("Cancel", role: .cancel) { confirming = nil }
                Button("Unblock", role: .destructive) {
                    onClear(flag)
                    confirming = nil
                }
            } message: { _ in
                Text("This food was blocked after a severe reaction — hives, swelling or difficulty breathing. Only unblock it if a doctor has said so.")
            }
        }
    }

    private func statusLabel(_ status: ToleranceEngine.ToleranceStatus) -> String {
        switch status {
        case .clear:                       "clear"
        case .paused(_, let days):         "\(days)d left"
        case .retry:                       "try again"
        case .held:                        "held"
        case .blocked:                     "blocked"
        }
    }

    private func detail(for flag: ToleranceEngine.FoodFlag) -> String {
        let recorded = "\(flag.level.label.lowercased()) on \(flag.recordedOn.mealDayLabel)"
        return switch flag.status {
        case .clear:               recorded
        case .paused(let until, _): "\(recorded) · back on the menu \(until.mealDayLabel)"
        case .retry:               "\(recorded) · the pause is over, worth offering again"
        case .held:                "\(recorded) · held until you clear it"
        case .blocked:             "\(recorded) · blocked"
        }
    }
}

/// One card per detected combination effect.
struct PairInsightsView: View {
    let effects: [PairEffectEngine.PairEffect]
    let foodsByID: [String: Food]

    private var actionable: [PairEffectEngine.PairEffect] { effects.filter(\.isActionable) }
    private var waiting: [PairEffectEngine.PairEffect] {
        effects.filter { if case .insufficient = $0.verdict { true } else { false } }
    }

    var body: some View {
        if !actionable.isEmpty || !waiting.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Eyebrow(text: "Food combinations")
                Text("How foods score together versus how they score apart.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(MealTheme.muted)

                ForEach(actionable) { effect in
                    PairEffectCard(effect: effect, foodsByID: foodsByID)
                }

                if !waiting.isEmpty {
                    ForEach(waiting.prefix(3)) { effect in
                        MealCard(background: .white, dashed: true) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(title(for: effect))
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(MealTheme.ink)
                                Text(needsText(for: effect))
                                    .font(.system(size: 12.5))
                                    .foregroundStyle(MealTheme.muted)
                            }
                        }
                    }
                }
            }
        }
    }

    private func title(for effect: PairEffectEngine.PairEffect) -> String {
        "\(name(effect.a)) + \(name(effect.b))"
    }

    private func name(_ id: String) -> String { foodsByID[id]?.name ?? id }

    /// Says which food needs to be served *apart*, because that is the only
    /// thing that will make the comparison possible.
    private func needsText(for effect: PairEffectEngine.PairEffect) -> String {
        guard case .insufficient(let needs) = effect.verdict else { return "" }
        var parts: [String] = []
        if needs.contains("both together") {
            parts.append("\(PairEffectEngine.minSharedMeals - effect.sharedMeals) more meals with both")
        }
        let apart = needs.filter { $0 != "both together" }.map(name)
        if !apart.isEmpty {
            parts.append("\(apart.joined(separator: " and ")) served without the other")
        }
        return "Not enough to compare yet — needs \(parts.joined(separator: ", "))."
    }
}

struct PairEffectCard: View {
    let effect: PairEffectEngine.PairEffect
    let foodsByID: [String: Food]

    private var isNegative: Bool { if case .negative = effect.verdict { true } else { false } }
    private var isConfirmed: Bool { effect.confidence == .confirmed }
    private var tint: Color { isNegative ? MealTheme.bubblegum : MealTheme.lagoon }

    var body: some View {
        MealCard(
            background: isConfirmed ? (isNegative ? MealTheme.bubbleSoft : MealTheme.lagoonSoft) : .white,
            border: tint.opacity(isConfirmed ? 0.45 : 0.25),
            dashed: !isConfirmed
        ) {
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 8) {
                    FoodColorStrip(colors: [effect.a, effect.b].compactMap { foodsByID[$0]?.color }, height: 5)
                        .frame(width: 34)
                    Text("\(name(effect.a)) + \(name(effect.b))")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(MealTheme.ink)
                    Spacer()
                    MealBadge(
                        text: isConfirmed ? "confirmed" : "suspected",
                        tint: tint,
                        soft: isConfirmed ? .white : MealTheme.line.opacity(0.4)
                    )
                }

                Text(verdictText)
                    .font(.system(size: 13.5))
                    .foregroundStyle(MealTheme.ink)

                HStack(spacing: 16) {
                    stat("apart", percent(effect.expected))
                    stat("together", percent(effect.observed))
                    stat("shared meals", "\(effect.sharedMeals)")
                }

                Text(actionText)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(tint)

                if !isConfirmed {
                    Text("\(effect.mealsToConfirm) more meals together to confirm.")
                        .font(.system(size: 12))
                        .foregroundStyle(MealTheme.muted)
                }
            }
        }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(MealTheme.ink)
            Text(label)
                .font(.system(size: 10.5))
                .foregroundStyle(MealTheme.muted)
        }
    }

    private func name(_ id: String) -> String { foodsByID[id]?.name ?? id }

    private func percent(_ value: Double) -> String { "\(Int((value * 100).rounded()))%" }

    private var verdictText: String {
        let delta = Int((abs(effect.delta) * 100).rounded())
        if isNegative {
            return "Eaten \(delta)% less well together than either is on its own. Both are fine separately."
        }
        let carried = effect.rateA <= effect.rateB ? name(effect.a) : name(effect.b)
        let carrier = effect.rateA <= effect.rateB ? name(effect.b) : name(effect.a)
        return "\(carried) goes down \(delta)% better with \(carrier) than without it."
    }

    private var actionText: String {
        if isNegative {
            return isConfirmed
                ? "This pair is kept out of generated menus. Both foods stay available separately."
                : "Watching. Nothing is blocked yet."
        }
        let carried = effect.rateA <= effect.rateB ? name(effect.a) : name(effect.b)
        return "\(carried) is not proven on its own yet — worth offering it without the carrier."
    }
}
