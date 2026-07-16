import SwiftUI
import Charts

// Weekly chart: one bar per day for the last 7 days, hover for the
// day's per-app breakdown
struct ChartView: View {
    @EnvironmentObject var watcher: AppWatcher
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedDay: Date?
    @State private var exportMessage: String?

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

    private static let palette: [Color] = [
        .blue, .green, .orange, .purple, .pink, .teal, .yellow, .red,
    ]

    // Swift's hashValue is re-seeded every launch, so use a stable djb2
    // hash — the same app keeps the same color across days AND restarts.
    // (Used by the breakdown dots here and by the dashboard.)
    static func color(for appName: String) -> Color {
        let hash = appName.unicodeScalars.reduce(UInt64(5381)) { $0 &* 33 &+ UInt64($1.value) }
        return palette[Int(hash % UInt64(palette.count))]
    }

    private var data: [DayAppDuration] { watcher.weekData() }

    private struct DayTotal: Identifiable {
        let day: Date
        let seconds: TimeInterval
        var id: Date { day }
        var hours: Double { seconds / 3600 }
    }

    // One bar per day, zero-filled so all 7 days always render
    private var dayTotals: [DayTotal] {
        let calendar = Calendar.current
        var totals: [Date: TimeInterval] = [:]
        for item in data {
            totals[item.day, default: 0] += item.seconds
        }
        let todayStart = calendar.startOfDay(for: Date())
        return (0..<7).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: todayStart) else { return nil }
            return DayTotal(day: day, seconds: totals[day] ?? 0)
        }
        .sorted { $0.day < $1.day }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            chart
            breakdown
            exportRow
        }
        .padding(16)
    }

    private var weekDomain: ClosedRange<Date> {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let start = calendar.date(byAdding: .day, value: -6, to: todayStart) ?? todayStart
        let end = calendar.date(byAdding: .day, value: 1, to: todayStart) ?? todayStart
        return start...end
    }

    private var chart: some View {
        let today = Calendar.current.startOfDay(for: Date())
        let maxHours = dayTotals.map(\.hours).max() ?? 0

        return Chart(dayTotals) { item in
            BarMark(
                x: .value("Day", item.day, unit: .day),
                y: .value("Hours", item.hours),
                // The hovered bar bubbles wider, mirroring bubbleHover
                width: .ratio(isSelected(item.day) ? 0.75 : 0.55)
            )
            .foregroundStyle(barStyle(for: item.day, today: today))
            .cornerRadius(4)
        }
        .animation(reduceMotion ? nil : .spring(duration: 0.3, bounce: 0.45), value: selectedDay)
        .chartXScale(domain: weekDomain)
        .chartYScale(domain: 0...max(1, maxHours * 1.2))
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.weekday(.abbreviated), centered: true)
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                if let hours = value.as(Double.self) {
                    AxisValueLabel {
                        Text(hours == floor(hours)
                             ? "\(Int(hours))h"
                             : String(format: "%.1fh", hours))
                    }
                }
            }
        }
        .chartXSelection(value: snappedSelection)
        .frame(height: 170)
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

    // Per-app breakdown for the hovered day. Fixed height in every state so
    // the popover never resizes while the cursor is over the chart.
    private var breakdown: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let selectedDay {
                let day = Calendar.current.startOfDay(for: selectedDay)
                let items = data
                    .filter { $0.day == day }
                    .sorted { $0.seconds > $1.seconds }
                    .prefix(3)

                Text(day, format: .dateTime.weekday(.wide).month().day())
                    .font(.caption.weight(.semibold))
                if items.isEmpty {
                    Text("No activity")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(items)) { item in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Self.color(for: item.appName))
                                .frame(width: 6, height: 6)
                            Text(item.appName)
                                .font(.caption)
                                .lineLimit(1)
                            Spacer()
                            Text(formatDuration(item.seconds))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } else {
                Text("Hover a bar for that day's breakdown")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(height: 76, alignment: .top)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 6))
    }

    private var exportRow: some View {
        HStack(spacing: 8) {
            Button("Export CSV") {
                do {
                    let url = try watcher.exportCSV()
                    exportMessage = "Saved to \(url.path)"
                } catch {
                    exportMessage = "Export failed: \(error.localizedDescription)"
                }
            }
            .font(.caption)
            .bubbleHover(scale: 1.06)

            if let exportMessage {
                Text(exportMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
        }
    }
}
