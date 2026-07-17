import SwiftUI
import Charts

// The full analytics window, opened from the popover
struct DashboardView: View {
    @EnvironmentObject var watcher: AppWatcher
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var rangeDays = 7
    @State private var selectedDay: Date?

    // Snap the hover selection to whole days: the bubble pop then fires once
    // per bar instead of re-triggering on every pixel of cursor movement
    private var snappedSelection: Binding<Date?> {
        Binding(
            get: { selectedDay },
            set: { selectedDay = $0.map { Calendar.current.startOfDay(for: $0) } }
        )
    }

    private func isSelected(_ day: Date) -> Bool {
        selectedDay.map { Calendar.current.startOfDay(for: $0) == day } ?? false
    }

    private var periodStart: Date {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        return calendar.date(byAdding: .day, value: -(rangeDays - 1), to: todayStart) ?? todayStart
    }

    private var sessions: [AppSessionModel] {
        watcher.fetchSessions(since: periodStart)
    }

    // The equal-length window immediately before this one, for trends
    private var previousSessions: [AppSessionModel] {
        let calendar = Calendar.current
        guard let previousStart = calendar.date(byAdding: .day, value: -rangeDays, to: periodStart) else {
            return []
        }
        return watcher.fetchSessions(since: previousStart)
            .filter { $0.startTime < periodStart }
    }

    var body: some View {
        let stats = AnalyticsEngine.stats(for: sessions)

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                statTiles(stats)
                FocusCardsView()
                card(
                    "Daily breakdown",
                    subtitle: averageHours > 0
                        ? "dashed line marks your average: \(formatDuration(averageHours * 3600)) per active day"
                        : nil,
                    pops: false
                ) { dailyChart }
                HStack(alignment: .top, spacing: 16) {
                    card("Trends", subtitle: "vs. the previous \(rangeDays) days") {
                        trendsContent
                    }
                    card("Records", subtitle: "personal bests, all time") {
                        recordsContent
                    }
                }
                card("Work rhythm", subtitle: "when your tracked time happens") {
                    WorkRhythmView(cells: AnalyticsEngine.fingerprint(for: sessions))
                }
                card("Top apps & sites") { topAppsList(stats) }
            }
            .padding(24)
        }
        .frame(minWidth: 860, minHeight: 620)
        .background(.background)
    }

    // MARK: — Layout helpers

    // `pops: false` for cards with their own cursor tracking (the chart's
    // hover selection) — scaling the card under the cursor makes the
    // selection band jitter against its own hit-testing
    private func card<Content: View>(
        _ title: String,
        subtitle: String? = nil,
        pops: Bool = true,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.headline)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 12))
        .bubbleHover(scale: pops ? 1.01 : 1.0)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Analytics")
                    .font(.largeTitle.weight(.semibold))
                Text("Where your time went")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Picker("Range", selection: $rangeDays) {
                Text("7 days").tag(7)
                Text("14 days").tag(14)
                Text("30 days").tag(30)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 240)
        }
    }

    // MARK: — Stat tiles

    private func statTiles(_ stats: DashboardStats) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 4), spacing: 14) {
            statTile(symbol: "clock.fill", tint: .blue,
                     value: formatDuration(stats.totalTime), label: "Total tracked")
            statTile(symbol: "calendar", tint: .purple,
                     value: formatDuration(stats.dailyAverage), label: "Daily average")
            statTile(symbol: "sunrise.fill", tint: .orange,
                     value: clockLabel(stats.typicalStart), label: "Typical day start")
            statTile(symbol: "sunset.fill", tint: .indigo,
                     value: clockLabel(stats.typicalEnd), label: "Typical day end")
        }
    }

    private func statTile(symbol: String, tint: Color, value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))
            Text(value)
                .font(.title2.monospacedDigit().weight(.semibold))
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 12))
        .bubbleHover(scale: 1.04)
    }

    private func clockLabel(_ secondsSinceMidnight: TimeInterval?) -> String {
        guard let secondsSinceMidnight else { return "—" }
        let date = Calendar.current.startOfDay(for: Date()).addingTimeInterval(secondsSinceMidnight)
        return date.formatted(date: .omitted, time: .shortened)
    }

    // MARK: — Trends

    @ViewBuilder
    private var trendsContent: some View {
        let trends = AnalyticsEngine.trends(current: sessions, previous: previousSessions)
        if trends.risers.isEmpty && trends.fallers.isEmpty {
            Text("Not enough history yet — check back after a few days.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(trends.risers) { trendRow($0, rising: true) }
                ForEach(trends.fallers) { trendRow($0, rising: false) }
            }
        }
    }

    private func trendRow(_ trend: AppTrend, rising: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: rising ? "arrow.up.right" : "arrow.down.right")
                .font(.caption2.weight(.bold))
                .foregroundStyle(rising ? .orange : .green)
                .frame(width: 16)
            Text(trend.app)
                .font(.callout)
                .lineLimit(1)
            Spacer()
            Text((rising ? "+" : "−") + formatDuration(abs(trend.delta)))
                .font(.callout.monospacedDigit())
                .foregroundStyle(rising ? .orange : .green)
        }
        .bubbleHover(scale: 1.03)
    }

    // MARK: — Records

    @ViewBuilder
    private var recordsContent: some View {
        let records = AnalyticsEngine.records(allSessions: watcher.fetchSessions(since: .distantPast))
        VStack(alignment: .leading, spacing: 10) {
            if let longest = records.longestBlock {
                recordRow(symbol: "flame.fill", tint: .orange,
                          title: "Longest session — \(formatDuration(longest.duration))",
                          detail: "\(longest.app), \(longest.day.formatted(date: .abbreviated, time: .omitted))")
            }
            if let biggest = records.biggestDay {
                recordRow(symbol: "trophy.fill", tint: .yellow,
                          title: "Biggest day — \(formatDuration(biggest.duration))",
                          detail: biggest.day.formatted(date: .complete, time: .omitted))
            }
            if records.longestBlock == nil && records.biggestDay == nil {
                Text("Records appear once you've tracked some time.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func recordRow(symbol: String, tint: Color, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 24, height: 24)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.callout.weight(.medium))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .bubbleHover(scale: 1.03)
    }

    // MARK: — Daily breakdown (Screen Time-style)

    private struct DayTotal: Identifiable {
        let day: Date
        let seconds: TimeInterval
        var id: Date { day }
        var hours: Double { seconds / 3600 }
    }

    private var dayTotals: [DayTotal] {
        let calendar = Calendar.current
        var totals: [Date: TimeInterval] = [:]
        for session in sessions {
            totals[calendar.startOfDay(for: session.startTime), default: 0] += session.duration
        }
        let todayStart = calendar.startOfDay(for: Date())
        return (0..<rangeDays).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: todayStart) else { return nil }
            return DayTotal(day: day, seconds: totals[day] ?? 0)
        }
        .sorted { $0.day < $1.day }
    }

    private var averageHours: Double {
        let tracked = dayTotals.filter { $0.seconds > 0 }
        guard !tracked.isEmpty else { return 0 }
        return tracked.reduce(0) { $0 + $1.hours } / Double(tracked.count)
    }

    private var dailyChart: some View {
        let totals = dayTotals
        let today = Calendar.current.startOfDay(for: Date())

        return VStack(alignment: .leading, spacing: 8) {
            Chart {
                ForEach(totals) { item in
                    BarMark(
                        x: .value("Day", item.day, unit: .day),
                        y: .value("Hours", item.hours),
                        // The hovered bar bubbles wider, mirroring bubbleHover
                        width: .ratio(isSelected(item.day) ? 0.75 : 0.55)
                    )
                    .foregroundStyle(barStyle(for: item.day, today: today))
                    .cornerRadius(5)
                    .annotation(position: .top, spacing: 4) {
                        if rangeDays == 7, item.seconds >= 60 {
                            Text(formatDuration(item.seconds))
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                // Labeled in the card subtitle — an annotation here crowds
                // the y-axis labels
                if averageHours > 0 {
                    RuleMark(y: .value("Average", averageHours))
                        .foregroundStyle(.secondary.opacity(0.45))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                }
            }
            .chartYScale(domain: 0...max(1, (totals.map(\.hours).max() ?? 0) * 1.25))
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: rangeDays > 14 ? 3 : 1)) { _ in
                    AxisValueLabel(
                        format: rangeDays > 7
                            ? .dateTime.day().month(.abbreviated)
                            : .dateTime.weekday(.abbreviated),
                        centered: true
                    )
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine().foregroundStyle(.quaternary)
                    if let hours = value.as(Double.self) {
                        AxisValueLabel { Text("\(Int(hours))h") }
                    }
                }
            }
            .chartXSelection(value: snappedSelection)
            .animation(reduceMotion ? nil : .spring(duration: 0.3, bounce: 0.45), value: selectedDay)
            .frame(height: 180)

            daySummary
        }
    }

    private func barStyle(for day: Date, today: Date) -> AnyShapeStyle {
        let isSelected = selectedDay.map { Calendar.current.startOfDay(for: $0) == day } ?? false
        if day == today || isSelected {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [.accentColor, .accentColor.opacity(0.55)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        return AnyShapeStyle(Color.accentColor.opacity(0.30))
    }

    // Constant height in both states so appearing/disappearing selection
    // doesn't resize the card while the cursor is over the chart
    private var daySummary: some View {
        Group {
            if let selectedDay {
                let calendar = Calendar.current
                let day = calendar.startOfDay(for: selectedDay)
                let dayStats = AnalyticsEngine.stats(
                    for: sessions.filter { calendar.startOfDay(for: $0.startTime) == day }
                )
                HStack(spacing: 14) {
                    Text(day, format: .dateTime.weekday(.wide).month().day())
                        .font(.caption.weight(.semibold))
                    if dayStats.topApps.isEmpty {
                        Text("No activity")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(dayStats.topApps.prefix(3), id: \.app) { item in
                            HStack(spacing: 5) {
                                Circle()
                                    .fill(ChartView.color(for: item.app))
                                    .frame(width: 6, height: 6)
                                Text("\(item.app)  \(formatDuration(item.duration))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 10)
                .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 7))
            } else {
                HStack {
                    Text("Hover a bar for that day's top apps")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .padding(.horizontal, 10)
            }
        }
        .frame(height: 30)
    }

    // MARK: — Top apps

    private func topAppsList(_ stats: DashboardStats) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            ForEach(stats.topApps.prefix(8), id: \.app) { item in
                HStack(spacing: 10) {
                    Text(item.app)
                        .font(.callout)
                        .lineLimit(1)
                        .frame(width: 220, alignment: .leading)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(.quaternary.opacity(0.4))
                            RoundedRectangle(cornerRadius: 3)
                                .fill(ChartView.color(for: item.app).gradient)
                                .frame(width: geo.size.width * ratio(item.duration, stats))
                        }
                    }
                    .frame(height: 14)
                    Text(formatDuration(item.duration))
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 70, alignment: .trailing)
                }
                .bubbleHover(scale: 1.02)
            }
        }
    }

    private func ratio(_ duration: TimeInterval, _ stats: DashboardStats) -> Double {
        guard let top = stats.topApps.first?.duration, top > 0 else { return 0 }
        return duration / top
    }
}
