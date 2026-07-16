import Foundation
import SwiftData

// Persisted record of one continuous block of time in one app.
// The live in-progress session stays in memory (see AppWatcher) and is
// converted to one of these when it closes.
@Model
final class AppSessionModel {
    var id: UUID
    var appName: String
    var bundleIdentifier: String
    var startTime: Date
    var endTime: Date?

    init(
        id: UUID = UUID(),
        appName: String,
        bundleIdentifier: String,
        startTime: Date,
        endTime: Date? = nil
    ) {
        self.id = id
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.startTime = startTime
        self.endTime = endTime
    }

    var duration: TimeInterval {
        (endTime ?? Date()).timeIntervalSince(startTime)
    }
}
