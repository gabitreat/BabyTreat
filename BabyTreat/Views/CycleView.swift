import SwiftUI
import SwiftData
import Charts

struct CycleView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PeriodStart.startDate, order: .reverse) private var cycles: [PeriodStart]

    // Defaults to today, but nothing is written until Add is tapped.
    @State private var newStart: Date = Calendar.current.startOfDay(for: .now)
    @State private var newEnd: Date = Calendar.current.startOfDay(for: .now)
    @State private var hasEnd: Bool = false
    @State private var duplicateDay: Bool = false

    private var store = EnergyProfileStore()

    private var profile: EnergyEngine.Profile {
        store.profile(lastPeriodStart: countedStarts.first?.startDate)
    }

    private var day: Int? { EnergyEngine.cycleDay(on: .now, profile: profile) }
    private var phase: EnergyEngine.CyclePhase? { day.map { EnergyEngine.phase(day: $0, profile: profile) } }

    /// Observed cycle lengths, from the gaps between logged starts.
    private var countedStarts: [PeriodStart] {
        cycles.filter(\.countsForCycleLength)
    }

    private var observedLengths: [Int] {
        zip(countedStarts, countedStarts.dropFirst()).compactMap { newer, older in
            Calendar.current.dateComponents([.day], from: older.startDate, to: newer.startDate).day
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if !store.tracksCycle {
                    NutritionCard {
                        Text("Cycle tracking is off")
                            .font(.headline)
                        Text("Turn it on in your profile and the luteal-phase rise gets added to your daily budget.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        NavigationLink("Open profile", destination: EnergySettingsView())
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(NutritionTheme.cycle)
                    }
                } else {
                    current
                    curve
                }
                log
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .task { PeriodStart.migrateFromCycleEvents(in: modelContext) }
        .navigationTitle("Cycle")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Today

    @ViewBuilder
    private var current: some View {
        NutritionCard {
            if let day, let phase {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(phase.label)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(NutritionTheme.cycle)
                        Text("Day \(day) of \(store.cycleLength)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    let add = EnergyEngine.budget(profile: profile).cycleAdd
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(add > 0 ? "+\(Int(add.rounded()))" : "—")
                            .font(.title2.weight(.bold))
                        Text("kcal today")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if phase == .luteal {
                    Text("Resting metabolism runs a few percent higher in the luteal phase, peaking mid-phase and tapering to zero at both ends.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("No period logged yet")
                    .font(.headline)
                Text("Log a start date below and the phase and budget curve appear.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Curve

    private var curve: some View {
        let points = EnergyEngine.cycleCurve(profile: profile)
        return NutritionCard {
            Text("Budget across the cycle")
                .font(.headline)

            Chart {
                ForEach(points, id: \.day) { point in
                    LineMark(
                        x: .value("Day", point.day),
                        y: .value("kcal", point.total)
                    )
                    .foregroundStyle(NutritionTheme.cycle)
                    .interpolationMethod(.catmullRom)
                }
                if let day {
                    RuleMark(x: .value("Today", day))
                        .foregroundStyle(NutritionTheme.accent)
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                }
                RuleMark(x: .value("Ovulation", EnergyEngine.ovulationDay(cycleLength: store.cycleLength)))
                    .foregroundStyle(Color(.systemGray3))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 3]))
            }
            .chartYScale(domain: .automatic(includesZero: false))
            .frame(height: 180)

            HStack(spacing: 14) {
                legend("Today", NutritionTheme.accent)
                legend("Ovulation, day \(EnergyEngine.ovulationDay(cycleLength: store.cycleLength))", Color(.systemGray3))
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }

    private func legend(_ label: String, _ color: Color) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 1).fill(color).frame(width: 12, height: 2)
            Text(label)
        }
    }

    // MARK: - Log

    private var log: some View {
        NutritionCard {
            Text("Period starts")
                .font(.headline)

            // Pick the dates rather than assuming today. A period is often
            // logged a day or two late, and "Started today" made that
            // impossible to record honestly.
            DatePicker("Started", selection: $newStart,
                       in: ...Date(), displayedComponents: .date)

            Toggle("It has ended", isOn: $hasEnd.animation())
                .font(.subheadline)

            if hasEnd {
                DatePicker("Ended", selection: $newEnd,
                           in: newStart...Date(), displayedComponents: .date)
            }

            Button {
                add()
            } label: {
                Label("Add", systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(NutritionTheme.cycle)
            }

            if duplicateDay {
                Text("That day is already logged. Delete it first if you want to change it.")
                    .font(.footnote)
                    .foregroundStyle(NutritionTheme.cycle)
            }

            if !observedLengths.isEmpty {
                let average = Double(observedLengths.reduce(0, +)) / Double(observedLengths.count)
                Text("Your last \(observedLengths.count) cycle\(observedLengths.count == 1 ? "" : "s") averaged \(String(format: "%.0f", average)) days. Your profile says \(store.cycleLength).")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if cycles.isEmpty {
                Text("Nothing logged yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(cycles.prefix(12)) { event in
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(event.startDate.formatted(date: .abbreviated, time: .omitted))
                            if let length = event.periodLengthDays {
                                Text("\(length) day\(length == 1 ? "" : "s")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Text(relative(to: event.startDate))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .contextMenu {
                        Button("Delete", role: .destructive) {
                            modelContext.delete(event)
                            try? modelContext.save()
                        }
                    }
                }
            }
        }
    }

    /// One entry per day. The store enforces it too, but refusing here is what
    /// lets the screen explain itself instead of silently swallowing the tap.
    private func add() {
        let day = PeriodStart.dayKey(newStart)
        guard !cycles.contains(where: { $0.dayKey == day }) else {
            duplicateDay = true
            return
        }
        duplicateDay = false
        modelContext.insert(
            PeriodStart(startDate: newStart, endDate: hasEnd ? newEnd : nil)
        )
        try? modelContext.save()
    }

    private func relative(to date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: date, to: .now).day ?? 0
        return days == 0 ? "today" : "\(days) days ago"
    }
}
