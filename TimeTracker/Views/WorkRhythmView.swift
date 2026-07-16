import SwiftUI

// 7×24 heatmap of when you work: rows are weekdays, columns are hours,
// intensity is minutes tracked. A calm, GitHub-graph-style rhythm map.
struct WorkRhythmView: View {
    let cells: [FingerprintCell]

    private static let dayLabels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    private var maxMinutes: Double {
        max(cells.map(\.minutes).max() ?? 0, 1)
    }

    var body: some View {
        Grid(horizontalSpacing: 3, verticalSpacing: 3) {
            ForEach(0..<7, id: \.self) { weekday in
                GridRow {
                    Text(Self.dayLabels[weekday])
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: 30, alignment: .leading)
                    ForEach(0..<24, id: \.self) { hour in
                        cellView(for: cells[weekday * 24 + hour])
                    }
                }
            }
            GridRow {
                Text("")
                    .frame(width: 30)
                ForEach(0..<24, id: \.self) { hour in
                    Text(hour % 6 == 0 ? "\(hour)" : "")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func cellView(for cell: FingerprintCell) -> some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(color(for: cell))
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            // Tiny cells get a big pop so the hovered hour is unmistakable
            .bubbleHover(scale: 1.45)
            .help(tooltip(for: cell))
    }

    private func color(for cell: FingerprintCell) -> Color {
        guard cell.minutes > 0.5 else {
            return Color.secondary.opacity(0.07)
        }
        let intensity = 0.18 + 0.82 * min(cell.minutes / maxMinutes, 1)
        return Color.accentColor.opacity(intensity)
    }

    private func tooltip(for cell: FingerprintCell) -> String {
        cell.minutes > 0.5
            ? String(format: "%@ %d:00 — %.0f min", Self.dayLabels[cell.weekday], cell.hour, cell.minutes)
            : "\(Self.dayLabels[cell.weekday]) \(cell.hour):00 — no activity"
    }
}
