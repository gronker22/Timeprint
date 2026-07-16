import Foundation

struct DashboardStats {
    let totalTime: TimeInterval
    let dailyAverage: TimeInterval      // across days that had any activity
    let typicalStart: TimeInterval?     // seconds since midnight, averaged
    let typicalEnd: TimeInterval?
    let activeDayCount: Int
    let topApps: [(app: String, duration: TimeInterval)]
}

// How one app's time changed vs. the previous period of equal length
struct AppTrend: Identifiable {
    let app: String
    let current: TimeInterval
    let previous: TimeInterval
    var delta: TimeInterval { current - previous }
    var id: String { app }
}

struct PersonalRecords {
    let longestBlock: (app: String, duration: TimeInterval, day: Date)?
    let biggestDay: (day: Date, duration: TimeInterval)?
}

// One cell of the Work Rhythm heatmap: minutes tracked in one (weekday, hour)
struct FingerprintCell: Identifiable {
    let weekday: Int  // 0 = Monday … 6 = Sunday
    let hour: Int
    var minutes: Double = 0

    var id: Int { weekday * 24 + hour }
}

enum AnalyticsEngine {

    // Max gap bridged when merging same-app sessions: a quick pause stays one
    // block, but idle time never counts as usage
    static let mergeMaxGapSeconds = 120.0

    struct Block {
        let appName: String
        let start: Date
        let end: Date
        var duration: TimeInterval { end.timeIntervalSince(start) }
    }

    static func mergedBlocks(from sessions: [AppSessionModel]) -> [Block] {
        var blocks: [Block] = []
        for session in sessions {
            let end = session.endTime ?? Date()
            if let last = blocks.last,
               last.appName == session.appName,
               session.startTime.timeIntervalSince(last.end) <= mergeMaxGapSeconds {
                blocks[blocks.count - 1] = Block(appName: last.appName, start: last.start, end: end)
            } else {
                blocks.append(Block(appName: session.appName, start: session.startTime, end: end))
            }
        }
        return blocks
    }

    static func stats(for sessions: [AppSessionModel]) -> DashboardStats {
        let calendar = Calendar.current

        var totals: [String: TimeInterval] = [:]
        var firstStart: [Date: Date] = [:]
        var lastEnd: [Date: Date] = [:]
        var total: TimeInterval = 0

        for session in sessions {
            totals[session.appName, default: 0] += session.duration
            total += session.duration

            let day = calendar.startOfDay(for: session.startTime)
            let end = session.endTime ?? Date()
            firstStart[day] = min(firstStart[day] ?? session.startTime, session.startTime)
            lastEnd[day] = max(lastEnd[day] ?? end, end)
        }

        let activeDays = firstStart.count
        let startOffsets = firstStart.map { day, start in start.timeIntervalSince(day) }
        let endOffsets = lastEnd.map { day, end in end.timeIntervalSince(calendar.startOfDay(for: day)) }

        return DashboardStats(
            totalTime: total,
            dailyAverage: activeDays > 0 ? total / Double(activeDays) : 0,
            typicalStart: startOffsets.isEmpty
                ? nil : startOffsets.reduce(0, +) / Double(startOffsets.count),
            typicalEnd: endOffsets.isEmpty
                ? nil : endOffsets.reduce(0, +) / Double(endOffsets.count),
            activeDayCount: activeDays,
            topApps: totals
                .map { (app: $0.key, duration: $0.value) }
                .sorted { $0.duration > $1.duration }
        )
    }

    // Risers and fallers vs. the previous period; apps with under 5 minutes
    // in both periods are noise and skipped
    static func trends(
        current: [AppSessionModel],
        previous: [AppSessionModel],
        limit: Int = 4
    ) -> (risers: [AppTrend], fallers: [AppTrend]) {
        var currentTotals: [String: TimeInterval] = [:]
        var previousTotals: [String: TimeInterval] = [:]
        for session in current { currentTotals[session.appName, default: 0] += session.duration }
        for session in previous { previousTotals[session.appName, default: 0] += session.duration }

        let apps = Set(currentTotals.keys).union(previousTotals.keys)
        let all = apps.compactMap { app -> AppTrend? in
            let trend = AppTrend(
                app: app,
                current: currentTotals[app] ?? 0,
                previous: previousTotals[app] ?? 0
            )
            guard max(trend.current, trend.previous) >= 300, abs(trend.delta) >= 120 else { return nil }
            return trend
        }

        return (
            risers: all.filter { $0.delta > 0 }.sorted { $0.delta > $1.delta }.prefix(limit).map { $0 },
            fallers: all.filter { $0.delta < 0 }.sorted { $0.delta < $1.delta }.prefix(limit).map { $0 }
        )
    }

    // All-time personal bests, computed over full history
    static func records(allSessions: [AppSessionModel]) -> PersonalRecords {
        let calendar = Calendar.current
        let blocks = mergedBlocks(from: allSessions)

        let longest = blocks.max { $0.duration < $1.duration }

        var dayTotals: [Date: TimeInterval] = [:]
        for session in allSessions {
            dayTotals[calendar.startOfDay(for: session.startTime), default: 0] += session.duration
        }
        let biggest = dayTotals.max { $0.value < $1.value }

        return PersonalRecords(
            longestBlock: longest.map {
                ($0.appName, $0.duration, calendar.startOfDay(for: $0.start))
            },
            biggestDay: biggest.map { ($0.key, $0.value) }
        )
    }

    // 7×24 grid: each session is sliced at hour boundaries and its minutes
    // credited to the (weekday, hour) it fell in
    static func fingerprint(for sessions: [AppSessionModel]) -> [FingerprintCell] {
        let calendar = Calendar.current
        var cells: [Int: FingerprintCell] = [:]

        for session in sessions {
            var sliceStart = session.startTime
            let end = session.endTime ?? Date()

            while sliceStart < end {
                guard let hourInterval = calendar.dateInterval(of: .hour, for: sliceStart) else { break }
                let sliceEnd = min(hourInterval.end, end)

                // Monday-first index regardless of locale
                let weekday = (calendar.component(.weekday, from: sliceStart) + 5) % 7
                let hour = calendar.component(.hour, from: sliceStart)
                let key = weekday * 24 + hour

                var cell = cells[key] ?? FingerprintCell(weekday: weekday, hour: hour)
                cell.minutes += sliceEnd.timeIntervalSince(sliceStart) / 60
                cells[key] = cell

                sliceStart = sliceEnd
            }
        }

        return (0..<7).flatMap { weekday in
            (0..<24).map { hour in
                cells[weekday * 24 + hour] ?? FingerprintCell(weekday: weekday, hour: hour)
            }
        }
    }
}
