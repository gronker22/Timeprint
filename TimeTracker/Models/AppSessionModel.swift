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
    // Web domain for browser-tab sessions ("youtube.com") — drives category
    // rules; nil for regular apps. Optional so old rows migrate cleanly.
    var host: String?
    var startTime: Date
    var endTime: Date?

    init(
        id: UUID = UUID(),
        appName: String,
        bundleIdentifier: String,
        host: String? = nil,
        startTime: Date,
        endTime: Date? = nil
    ) {
        self.id = id
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.host = host
        self.startTime = startTime
        self.endTime = endTime
    }

    // The key overrides and categorization group by: the domain for tabs,
    // the app name for everything else
    var categoryKey: String { host ?? appName }

    var category: AppCategory {
        let base: AppCategory = host.map { AppCatalog.categoryForDomain($0) }
            ?? AppCatalog.category(bundleID: bundleIdentifier, name: appName)
        return CategoryOverrides.effectiveCategory(for: categoryKey, default: base)
    }

    var duration: TimeInterval {
        (endTime ?? Date()).timeIntervalSince(startTime)
    }
}
