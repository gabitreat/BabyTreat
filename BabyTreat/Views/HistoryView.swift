import SwiftUI
import SwiftData
import Charts

enum TimePeriod: String, CaseIterable {
    case day = "Day"
    case week = "Week"
    case month = "Month"
}

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SleepRecord.startTime, order: .reverse) private var sleepRecords: [SleepRecord]
    @Query(sort: \PlaytimeRecord.startTime, order: .reverse) private var playtimeRecords: [PlaytimeRecord]
    @Query(sort: \NursingRecord.timestamp, order: .reverse) private var nursingRecords: [NursingRecord]
    @Query(sort: \TemperatureReading.timestamp, order: .reverse) private var temperatureReadings: [TemperatureReading]

    @State private var selectedPeriod: TimePeriod = .day
    @State private var mockDataLoaded = false

    private var periodStart: Date {
        let cal = Calendar.current
        let now = Date()
        switch selectedPeriod {
        case .day:
            return cal.startOfDay(for: now)
        case .week:
            let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
            return cal.date(from: comps) ?? now
        case .month:
            let comps = cal.dateComponents([.year, .month], from: now)
            return cal.date(from: comps) ?? now
        }
    }

    // MARK: - Summary totals

    private var sleepTotal: TimeInterval {
        let start = periodStart
        return sleepRecords
            .filter { $0.startTime >= start }
            .reduce(0) { $0 + $1.stopTime.timeIntervalSince($1.startTime) }
    }

    private var playtimeTotal: TimeInterval {
        let start = periodStart
        return playtimeRecords
            .filter { $0.startTime >= start }
            .reduce(0) { $0 + $1.stopTime.timeIntervalSince($1.startTime) }
    }

    private var nursingTotal: TimeInterval {
        let start = periodStart
        return nursingRecords
            .filter { $0.timestamp >= start }
            .reduce(0) { $0 + $1.leftDuration + $1.rightDuration }
    }

    private var tempCount: Int {
        temperatureReadings.filter { $0.timestamp >= periodStart }.count
    }

    // MARK: - Segment builder for a single day

    private func segmentsForDay(_ dayStart: Date) -> [TimelineSegment] {
        let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart)!
        var raw: [(start: Double, end: Double, category: ActivityCategory)] = []

        for r in sleepRecords where r.startTime >= dayStart && r.startTime < dayEnd {
            let s = r.startTime.timeIntervalSince(dayStart) / 3600
            let e = r.stopTime.timeIntervalSince(dayStart) / 3600
            raw.append((s, min(e, 24), .sleep))
        }

        for r in playtimeRecords where r.startTime >= dayStart && r.startTime < dayEnd {
            let s = r.startTime.timeIntervalSince(dayStart) / 3600
            let e = r.stopTime.timeIntervalSince(dayStart) / 3600
            raw.append((s, min(e, 24), .playtime))
        }

        for r in nursingRecords where r.timestamp >= dayStart && r.timestamp < dayEnd {
            let s = r.timestamp.timeIntervalSince(dayStart) / 3600
            let dur = (r.leftDuration + r.rightDuration) / 3600
            raw.append((s, min(s + dur, 24), .nursing))
        }

        for r in temperatureReadings where r.timestamp >= dayStart && r.timestamp < dayEnd {
            let h = r.timestamp.timeIntervalSince(dayStart) / 3600
            raw.append((h, min(h + 0.15, 24), .temperature))
        }

        raw.sort { $0.start < $1.start }

        var segments: [TimelineSegment] = []
        var cursor: Double = 0

        for item in raw {
            let start = max(item.start, cursor)
            if start > cursor {
                if let last = segments.last, last.category == nil {
                    segments[segments.count - 1] = TimelineSegment(category: nil, startHour: last.startHour, endHour: start)
                } else {
                    segments.append(TimelineSegment(category: nil, startHour: cursor, endHour: start))
                }
            }
            let end = max(item.end, start + 0.05)
            if let last = segments.last, last.category == item.category {
                segments[segments.count - 1] = TimelineSegment(category: item.category, startHour: last.startHour, endHour: end)
            } else {
                segments.append(TimelineSegment(category: item.category, startHour: start, endHour: end))
            }
            cursor = end
        }

        if cursor < 24 {
            if let last = segments.last, last.category == nil {
                segments[segments.count - 1] = TimelineSegment(category: nil, startHour: last.startHour, endHour: 24)
            } else {
                segments.append(TimelineSegment(category: nil, startHour: cursor, endHour: 24))
            }
        }

        return segments
    }

    // MARK: - Day data

    private var timelineSegments: [TimelineSegment] {
        segmentsForDay(periodStart)
    }

    private var hasDayData: Bool {
        timelineSegments.contains { $0.category != nil }
    }

    // MARK: - Week data

    private var weekDays: [(label: String, segments: [TimelineSegment])] {
        let cal = Calendar.current
        let start = periodStart
        return (0..<7).map { offset in
            let day = cal.date(byAdding: .day, value: offset, to: start)!
            let label = shortDayName(day)
            return (label, segmentsForDay(day))
        }
    }

    // MARK: - Month time-of-day data

    private var monthTimeBlocks: [MonthTimeBlock] {
        let cal = Calendar.current
        let start = periodStart
        let range = cal.range(of: .day, in: .month, for: start) ?? (1..<31)
        let daysInMonth = range.count
        var blocks: [MonthTimeBlock] = []

        for dayOffset in 0..<daysInMonth {
            guard let dayStart = cal.date(byAdding: .day, value: dayOffset, to: start),
                  let dayEnd = cal.date(byAdding: .day, value: dayOffset + 1, to: start) else { continue }
            let day = dayOffset + 1

            for r in sleepRecords where r.startTime >= dayStart && r.startTime < dayEnd {
                let s = r.startTime.timeIntervalSince(dayStart) / 3600
                let e = min(r.stopTime.timeIntervalSince(dayStart) / 3600, 24)
                blocks.append(MonthTimeBlock(day: day, category: .sleep, startHour: s, endHour: e))
            }
            for r in playtimeRecords where r.startTime >= dayStart && r.startTime < dayEnd {
                let s = r.startTime.timeIntervalSince(dayStart) / 3600
                let e = min(r.stopTime.timeIntervalSince(dayStart) / 3600, 24)
                blocks.append(MonthTimeBlock(day: day, category: .playtime, startHour: s, endHour: e))
            }
            for r in nursingRecords where r.timestamp >= dayStart && r.timestamp < dayEnd {
                let s = r.timestamp.timeIntervalSince(dayStart) / 3600
                let dur = (r.leftDuration + r.rightDuration) / 3600
                blocks.append(MonthTimeBlock(day: day, category: .nursing, startHour: s, endHour: min(s + dur, 24)))
            }
            for r in temperatureReadings where r.timestamp >= dayStart && r.timestamp < dayEnd {
                let h = r.timestamp.timeIntervalSince(dayStart) / 3600
                blocks.append(MonthTimeBlock(day: day, category: .temperature, startHour: h, endHour: min(h + 0.3, 24)))
            }
        }

        return blocks
    }

    private var daysInMonth: Int {
        let cal = Calendar.current
        return cal.range(of: .day, in: .month, for: periodStart)?.count ?? 31
    }

    private var hasMonthData: Bool {
        !monthTimeBlocks.isEmpty
    }

    // MARK: - Body

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Period Picker
                    Picker("Period", selection: $selectedPeriod) {
                        ForEach(TimePeriod.allCases, id: \.self) { period in
                            Text(period.rawValue).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    // Summary Cards
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            SummaryCard(icon: "moon.fill", color: .purple, label: "Sleep", value: formatDuration(sleepTotal))
                            SummaryCard(icon: "figure.play", color: .green, label: "Playtime", value: formatDuration(playtimeTotal))
                            SummaryCard(icon: "drop.fill", color: .blue, label: "Nursing", value: formatDuration(nursingTotal))
                            SummaryCard(icon: "thermometer", color: .red, label: "Temp", value: "\(tempCount) reading\(tempCount == 1 ? "" : "s")")
                        }
                        .padding(.horizontal)
                    }

                    // Legend
                    HStack(spacing: 20) {
                        Spacer()
                        LegendItem(color: .purple, icon: "moon.fill", label: "Sleep")
                        LegendItem(color: .green, icon: "figure.play", label: "Playtime")
                        LegendItem(color: .blue, icon: "drop.fill", label: "Nursing")
                        LegendItem(color: .red, icon: "thermometer", label: "Temp")
                        Spacer()
                    }

                    if selectedPeriod == .day {
                        if hasDayData {
                            DayTimelineView(segments: timelineSegments)
                                .padding(.horizontal)
                        } else {
                            emptyStateView
                        }
                    } else if selectedPeriod == .week {
                        WeekTimelineView(days: weekDays)
                            .padding(.horizontal)
                    } else {
                        if hasMonthData {
                            MonthChartsView(blocks: monthTimeBlocks, daysInMonth: daysInMonth)
                                .padding(.horizontal)
                        } else {
                            emptyStateView
                        }
                    }

                    // Mock data button
                    if !mockDataLoaded {
                        Button("Load Mock Data") {
                            insertMockData()
                            mockDataLoaded = true
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.top, 8)
                    }
                }
                .padding(.top)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("History")
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No data for this period")
                .font(.title3)
                .foregroundColor(.secondary)
        }
        .frame(height: 260)
    }

    // MARK: - Mock Data

    private func insertMockData() {
        let cal = Calendar.current
        let now = Date()

        // Today
        for hoursAgo in [2, 6, 10] {
            if let date = cal.date(byAdding: .hour, value: -hoursAgo, to: now) {
                let end = cal.date(byAdding: .minute, value: Int.random(in: 30...120), to: date)!
                modelContext.insert(SleepRecord(startTime: date, stopTime: end))
            }
        }

        for hoursAgo in [1, 5, 9] {
            if let date = cal.date(byAdding: .hour, value: -hoursAgo, to: now) {
                let end = cal.date(byAdding: .minute, value: Int.random(in: 15...60), to: date)!
                modelContext.insert(PlaytimeRecord(startTime: date, stopTime: end))
            }
        }

        for hoursAgo in [3, 7, 11] {
            if let date = cal.date(byAdding: .hour, value: -hoursAgo, to: now) {
                modelContext.insert(NursingRecord(
                    timestamp: date,
                    leftDuration: Double(Int.random(in: 5...20)) * 60,
                    rightDuration: Double(Int.random(in: 5...20)) * 60
                ))
            }
        }

        for hoursAgo in [4, 8] {
            if let date = cal.date(byAdding: .hour, value: -hoursAgo, to: now) {
                modelContext.insert(TemperatureReading(
                    value: Double.random(in: 36.2...37.8),
                    unit: "celsius",
                    timestamp: date
                ))
            }
        }

        // Past week (1-6 days ago)
        for daysAgo in 1...6 {
            guard let dayBase = cal.date(byAdding: .day, value: -daysAgo, to: now) else { continue }
            let dayStart = cal.startOfDay(for: dayBase)

            for hour in [1, 8, 14, 21] {
                if let date = cal.date(byAdding: .hour, value: hour, to: dayStart) {
                    let end = cal.date(byAdding: .minute, value: Int.random(in: 40...150), to: date)!
                    modelContext.insert(SleepRecord(startTime: date, stopTime: end))
                }
            }

            for hour in [10, 15] {
                if let date = cal.date(byAdding: .hour, value: hour, to: dayStart) {
                    let end = cal.date(byAdding: .minute, value: Int.random(in: 20...60), to: date)!
                    modelContext.insert(PlaytimeRecord(startTime: date, stopTime: end))
                }
            }

            for hour in [6, 12, 18] {
                if let date = cal.date(byAdding: .hour, value: hour, to: dayStart) {
                    modelContext.insert(NursingRecord(
                        timestamp: date,
                        leftDuration: Double(Int.random(in: 5...20)) * 60,
                        rightDuration: Double(Int.random(in: 5...20)) * 60
                    ))
                }
            }

            if let date = cal.date(byAdding: .hour, value: 9, to: dayStart) {
                modelContext.insert(TemperatureReading(
                    value: Double.random(in: 36.0...38.2),
                    unit: "celsius",
                    timestamp: date
                ))
            }
        }

        // Rest of month (7-29 days ago)
        for daysAgo in 7...29 {
            guard let dayBase = cal.date(byAdding: .day, value: -daysAgo, to: now) else { continue }
            let dayStart = cal.startOfDay(for: dayBase)

            for hour in [2, 13, 22] {
                if let date = cal.date(byAdding: .hour, value: hour, to: dayStart) {
                    let end = cal.date(byAdding: .minute, value: Int.random(in: 30...120), to: date)!
                    modelContext.insert(SleepRecord(startTime: date, stopTime: end))
                }
            }

            if let date = cal.date(byAdding: .hour, value: 11, to: dayStart) {
                let end = cal.date(byAdding: .minute, value: Int.random(in: 15...45), to: date)!
                modelContext.insert(PlaytimeRecord(startTime: date, stopTime: end))
            }

            for hour in [7, 16] {
                if let date = cal.date(byAdding: .hour, value: hour, to: dayStart) {
                    modelContext.insert(NursingRecord(
                        timestamp: date,
                        leftDuration: Double(Int.random(in: 5...15)) * 60,
                        rightDuration: Double(Int.random(in: 5...15)) * 60
                    ))
                }
            }

            if daysAgo % 3 == 0, let date = cal.date(byAdding: .hour, value: 8, to: dayStart) {
                modelContext.insert(TemperatureReading(
                    value: Double.random(in: 36.2...37.5),
                    unit: "celsius",
                    timestamp: date
                ))
            }
        }
    }

    // MARK: - Formatting

    private func formatDuration(_ interval: TimeInterval) -> String {
        let total = Int(interval)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    private func shortDayName(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f.string(from: date)
    }
}

// MARK: - Timeline Models

enum ActivityCategory: CaseIterable {
    case sleep, playtime, nursing, temperature

    var color: Color {
        switch self {
        case .sleep: return .purple
        case .playtime: return .green
        case .nursing: return .blue
        case .temperature: return .red
        }
    }

    var label: String {
        switch self {
        case .sleep: return "Sleep"
        case .playtime: return "Playtime"
        case .nursing: return "Nursing"
        case .temperature: return "Temperature"
        }
    }

    var icon: String {
        switch self {
        case .sleep: return "moon.fill"
        case .playtime: return "figure.play"
        case .nursing: return "drop.fill"
        case .temperature: return "thermometer"
        }
    }
}

struct TimelineSegment: Identifiable {
    let id = UUID()
    let category: ActivityCategory? // nil = awake window
    let startHour: Double
    let endHour: Double

    var duration: Double { endHour - startHour }
}

// MARK: - Day Timeline View

struct DayTimelineView: View {
    let segments: [TimelineSegment]

    private let timelineHeight: CGFloat = 1200 // 50pt per hour
    private let hourHeight: CGFloat = 50
    private let labelWidth: CGFloat = 54
    private let barLeftPad: CGFloat = 6

    private func formatHourLabel(_ hour: Int) -> String {
        let h = hour % 12 == 0 ? 12 : hour % 12
        let ampm = hour < 12 ? "AM" : "PM"
        return "\(h) \(ampm)"
    }

    private func durationLabel(_ hours: Double) -> String {
        let totalMin = Int(hours * 60)
        let h = totalMin / 60
        let m = totalMin % 60
        if h > 0 && m > 0 { return "\(h)h \(m)m" }
        if h > 0 { return "\(h)h" }
        if m > 0 { return "\(m)m" }
        return ""
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Hour labels column — always shows all 24 hours
            VStack(spacing: 0) {
                ForEach(0..<24, id: \.self) { hour in
                    Text(formatHourLabel(hour))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(width: labelWidth, height: hourHeight, alignment: .topTrailing)
                }
            }

            // Bar column
            ZStack(alignment: .top) {
                // Background: full 24h gray bar with hour dividers
                VStack(spacing: 0) {
                    ForEach(0..<24, id: \.self) { _ in
                        Rectangle()
                            .fill(Color(.systemGray6))
                            .frame(height: hourHeight)
                            .overlay(alignment: .top) {
                                Rectangle()
                                    .fill(Color(.separator).opacity(0.2))
                                    .frame(height: 0.5)
                            }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 10))

                // Activity blocks overlaid at exact positions
                ForEach(segments) { segment in
                    if let cat = segment.category {
                        let y = CGFloat(segment.startHour) * hourHeight
                        let h = max(CGFloat(segment.duration) * hourHeight, 20)

                        HStack(spacing: 4) {
                            Image(systemName: cat.icon)
                                .font(.system(size: 10))
                                .foregroundColor(.white)
                            if segment.duration >= 0.4 {
                                Text(cat.label)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Text(durationLabel(segment.duration))
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding(.horizontal, 8)
                        .frame(height: h)
                        .background(cat.color)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .padding(.horizontal, 2)
                        .offset(y: y)
                    }
                }
            }
            .padding(.leading, barLeftPad)
        }
        .frame(height: timelineHeight)
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }
}

// MARK: - Week Timeline View

struct WeekTimelineView: View {
    let days: [(label: String, segments: [TimelineSegment])]

    private let hourHeight: CGFloat = 50
    private let timelineHeight: CGFloat = 1200 // 24 * 50

    private func formatHourLabel(_ hour: Int) -> String {
        let h = hour % 12 == 0 ? 12 : hour % 12
        let ampm = hour < 12 ? "a" : "p"
        return "\(h)\(ampm)"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Hour labels
            VStack(spacing: 0) {
                // Header spacer to align with day labels
                Text("")
                    .font(.system(size: 11))
                    .frame(height: 20)

                ForEach(0..<24, id: \.self) { hour in
                    Text(formatHourLabel(hour))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(width: 28, height: hourHeight, alignment: .topTrailing)
                }
            }

            // 7 day columns
            ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                VStack(spacing: 0) {
                    // Day label header
                    Text(day.label)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.primary)
                        .frame(height: 20)

                    // 24h bar
                    ZStack(alignment: .top) {
                        // Gray background with hour dividers
                        VStack(spacing: 0) {
                            ForEach(0..<24, id: \.self) { _ in
                                Rectangle()
                                    .fill(Color(.systemGray6))
                                    .frame(height: hourHeight)
                                    .overlay(alignment: .top) {
                                        Rectangle()
                                            .fill(Color(.separator).opacity(0.15))
                                            .frame(height: 0.5)
                                    }
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                        // Activity blocks
                        ForEach(day.segments) { segment in
                            if let cat = segment.category {
                                let y = CGFloat(segment.startHour) * hourHeight
                                let h = max(CGFloat(segment.duration) * hourHeight, 4)

                                RoundedRectangle(cornerRadius: 4)
                                    .fill(cat.color)
                                    .frame(height: h)
                                    .padding(.horizontal, 1)
                                    .offset(y: y)
                            }
                        }
                    }
                    .frame(height: timelineHeight)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: timelineHeight + 20) // +20 for header
        .padding(.vertical, 12)
        .padding(.horizontal, 4)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }
}

// MARK: - Month Data & Charts

struct MonthTimeBlock: Identifiable {
    let id = UUID()
    let day: Int
    let category: ActivityCategory
    let startHour: Double
    let endHour: Double
}

struct MonthChartsView: View {
    let blocks: [MonthTimeBlock]
    let daysInMonth: Int

    private func hourLabel(_ hour: Int) -> String {
        let h = hour % 12 == 0 ? 12 : hour % 12
        let ampm = hour < 12 ? "AM" : "PM"
        return "\(h) \(ampm)"
    }

    var body: some View {
        VStack(spacing: 20) {
            // All activities combined
            activityChart(
                title: "All Activities",
                icon: "clock.fill",
                iconColor: .primary,
                data: blocks
            )

            // Per-category charts
            activityChart(
                title: "Sleep",
                icon: "moon.fill",
                iconColor: .purple,
                data: blocks.filter { $0.category == .sleep }
            )

            activityChart(
                title: "Playtime",
                icon: "figure.play",
                iconColor: .green,
                data: blocks.filter { $0.category == .playtime }
            )

            activityChart(
                title: "Nursing",
                icon: "drop.fill",
                iconColor: .blue,
                data: blocks.filter { $0.category == .nursing }
            )

            let tempBlocks = blocks.filter { $0.category == .temperature }
            if !tempBlocks.isEmpty {
                activityChart(
                    title: "Temperature",
                    icon: "thermometer",
                    iconColor: .red,
                    data: tempBlocks
                )
            }
        }
    }

    private func activityChart(title: String, icon: String, iconColor: Color, data: [MonthTimeBlock]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                Text(title)
                    .font(.headline)
            }

            Chart {
                ForEach(data) { block in
                    RectangleMark(
                        xStart: .value("Day Start", Double(block.day) - 0.4),
                        xEnd: .value("Day End", Double(block.day) + 0.4),
                        yStart: .value("Start", block.startHour),
                        yEnd: .value("End", block.endHour)
                    )
                    .foregroundStyle(block.category.color.opacity(0.85))
                }
            }
            .chartXScale(domain: 1...Double(daysInMonth))
            .chartYScale(domain: 0...24)
            .chartYAxis {
                AxisMarks(values: [0, 3, 6, 9, 12, 15, 18, 21, 24]) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let h = value.as(Int.self) {
                            Text(hourLabel(h % 24))
                                .font(.system(size: 9))
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: Array(stride(from: 1, through: daysInMonth, by: 1))) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let day = value.as(Int.self) {
                            Text("\(day)")
                                .font(.system(size: 7))
                        }
                    }
                }
            }
            .frame(height: 220)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }
}

// MARK: - Subviews

struct SummaryCard: View {
    let icon: String
    let color: Color
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            Text(value)
                .font(.headline)
                .foregroundColor(.primary)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(width: 80, height: 80)
        .padding(8)
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

struct LegendItem: View {
    let color: Color
    let icon: String
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}
