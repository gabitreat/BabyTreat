import Foundation

/// Reading active energy out of Health.
///
/// Split from its implementation for the same reason `OFFClient` is: the rules
/// that matter — which sources to trust, whether a zero is real, how far back
/// to recompute — are testable against a fake, and waiting for a real watch to
/// misbehave is not a test strategy.
protocol ActiveEnergyProviding {
    /// False on a device with no Health store at all.
    var isHealthDataAvailable: Bool { get }

    /// Read-only. This module never writes to Health, and never asks for
    /// permission to (spec 2.1).
    func requestAuthorisation() async throws

    /// Everything that has written active energy in the window, with counts.
    func availableSources(since: Date) async throws -> [EnergySource]

    /// One day, summed across the given sources and no others.
    func activeEnergy(on day: Date, from sources: Set<String>) async throws -> ActiveEnergyDay

    func hourlyActiveEnergy(on day: Date, from sources: Set<String>) async throws -> [HourBucket]
}
