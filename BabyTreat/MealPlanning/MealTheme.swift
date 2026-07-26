import SwiftUI

/// Palette lifted from `design/baby-meal-planner.html` (`:root`).
/// Keep these in sync with that file — it is the design reference of record.
enum MealTheme {
    // Palette
    static let malachite = Color(hex: "#15484C")   // structure + type
    static let lagoon    = Color(hex: "#30B8B2")   // active / on track
    static let bubblegum = Color(hex: "#F66483")   // needs attention
    static let sugar     = Color(hex: "#A6480A")   // ratings + cookbook
    static let marigold  = Color(hex: "#EAA221")   // allergen rotation

    // Tints
    static let lagoonSoft   = Color(hex: "#E3F4F3")
    static let bubbleSoft   = Color(hex: "#FDEAEF")
    static let sugarSoft    = Color(hex: "#F8EEE6")
    static let marigoldSoft = Color(hex: "#FCF2DE")

    // Surfaces
    static let milk  = Color(hex: "#F9FCFB")
    static let ink   = Color(hex: "#15484C")
    static let muted = Color(hex: "#3E6B6F")
    static let line  = Color(hex: "#D5E4E2")

    static let cornerRadius: CGFloat = 14
    static let pad: CGFloat = 18

    /// The header gradient — `linear-gradient(158deg, …)` in the prototype.
    static let headerGradient = LinearGradient(
        colors: [Color(hex: "#1B6165"), Color(hex: "#15484C"), Color(hex: "#103A3E")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let headerText     = Color(hex: "#EAF6F5")
    static let headerAccent   = Color(hex: "#8FE7E1")
    static let headerSubtle   = Color(hex: "#BCE4E1")
}

extension Color {
    /// `#RRGGBB` / `RRGGBB`. Falls back to clear on malformed input rather than
    /// trapping — seed data is hand-written and a typo shouldn't crash the app.
    init(hex: String) {
        let cleaned = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard cleaned.count == 6, let value = UInt32(cleaned, radix: 16) else {
            self = .clear
            return
        }
        self.init(
            .sRGB,
            red:   Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8)  & 0xFF) / 255,
            blue:  Double( value        & 0xFF) / 255,
            opacity: 1
        )
    }
}

// MARK: - Shared chrome

/// Card surface used throughout the meal-planning tabs.
struct MealCard<Content: View>: View {
    var background: Color = .white
    var border: Color = MealTheme.line
    var dashed: Bool = false
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background)
            .overlay(
                RoundedRectangle(cornerRadius: MealTheme.cornerRadius)
                    .strokeBorder(
                        border,
                        style: StrokeStyle(lineWidth: 1, dash: dashed ? [5, 4] : [])
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: MealTheme.cornerRadius))
    }
}

/// Small uppercase label above a section, matching `.eyebrow`.
struct Eyebrow: View {
    let text: String
    var color: Color = MealTheme.muted

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .tracking(1.6)
            .foregroundStyle(color)
    }
}

/// The colour strip that shows a meal's variety at a glance.
struct FoodColorStrip: View {
    let colors: [Color]
    var height: CGFloat = 5

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(colors.enumerated()), id: \.offset) { _, color in
                Rectangle().fill(color)
            }
        }
        .frame(height: height)
        .clipShape(Capsule())
    }
}
