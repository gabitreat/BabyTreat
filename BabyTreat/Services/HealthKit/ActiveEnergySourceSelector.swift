import Foundation

/// Picks which sources to trust the first time the toggle is switched on.
///
/// Pure, so the rule can be tested without a Health store.
enum ActiveEnergySourceSelector {

    /// Matched case-insensitively against both the source's name and its bundle
    /// identifier, at runtime.
    ///
    /// Deliberately a substring and not a fixed bundle identifier: Garmin ships
    /// more than one iOS app and its identifiers move between releases. A
    /// hardcoded string that stops matching does not throw — it silently
    /// credits zero for ever, which is the worst failure this module has.
    static let wearableNeedle = "garmin"

    static func isWearable(_ source: EnergySource) -> Bool {
        contains(source, wearableNeedle)
    }

    static func isAppleWatch(_ source: EnergySource) -> Bool {
        // Apple's own sources all sit under `com.apple.health.<uuid>`, so the
        // identifier cannot tell a watch from a phone. The display name can.
        contains(source, "watch") || contains(source, "ceas")
    }

    static func isPhone(_ source: EnergySource) -> Bool {
        contains(source, "iphone") || contains(source, "telefon")
    }

    /// Which sources to enable by default.
    ///
    /// Order is **wearable, then Apple Watch, then iPhone** — never the one
    /// with the most samples. The phone almost always wins on sample count
    /// while being the worse estimate: phone-only active energy comes from step
    /// cadence, so it misses cycling, weights, pushing a pram and carrying a
    /// child. Density is not accuracy.
    ///
    /// Exactly one tier is returned. Enabling a second would count the same
    /// walk twice (C4).
    static func defaultSelection(from sources: [EnergySource]) -> Set<String> {
        for test in [isWearable, isAppleWatch, isPhone] {
            let matches = sources.filter(test)
            if !matches.isEmpty { return Set(matches.map(\.bundleIdentifier)) }
        }
        return []
    }

    /// The same list with `isEnabled` filled in, so the picker and the sum
    /// cannot disagree about who is on.
    static func applyingDefaults(to sources: [EnergySource]) -> [EnergySource] {
        let enabled = defaultSelection(from: sources)
        return sources.map { source in
            var copy = source
            copy.isEnabled = enabled.contains(source.bundleIdentifier)
            return copy
        }
    }

    private static func contains(_ source: EnergySource, _ needle: String) -> Bool {
        source.displayName.lowercased().contains(needle)
            || source.bundleIdentifier.lowercased().contains(needle)
    }
}
