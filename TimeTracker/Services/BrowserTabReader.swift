import Foundation

// Reads the active tab out of Google Chrome or Safari via Apple Events.
// First use per browser triggers the macOS Automation permission prompt.
//
// IMPORTANT: Apple Events are synchronous IPC and can block for a long time.
// Everything here must be called off the main thread, from one serial queue
// (NSAppleScript instances are not safe to share across threads).
enum BrowserTabReader {

    static let chromeBundleID = "com.google.Chrome"
    static let safariBundleID = "com.apple.Safari"
    static let browserBundleIDs: Set<String> = [chromeBundleID, safariBundleID]

    // Titles can be very long; cap them so rows and charts stay readable
    private static let maxTitleLength = 60

    enum Result {
        case tab(label: String, host: String?)
        case unavailable        // no windows, blank tab — normal, keep polling
        case permissionDenied   // Automation refused — back off hard
    }

    // Compiled once — NSAppleScript compilation is the expensive part.
    // Chrome calls a tab's title "title"; Safari calls it "name".
    private static let chromeScript = NSAppleScript(source: """
        tell application "Google Chrome"
            if (count of windows) > 0 then
                return {URL, title} of active tab of front window
            end if
        end tell
        """)

    private static let safariScript = NSAppleScript(source: """
        tell application "Safari"
            if (count of windows) > 0 then
                return {URL of current tab of front window, name of current tab of front window}
            end if
        end tell
        """)

    static func activeTab(bundleID: String) -> Result {
        let script: NSAppleScript?
        switch bundleID {
        case chromeBundleID: script = chromeScript
        case safariBundleID: script = safariScript
        default: return .unavailable
        }

        var error: NSDictionary?
        let descriptor = script?.executeAndReturnError(&error)

        if let error {
            let code = (error[NSAppleScript.errorNumber] as? Int) ?? 0
            // -1743 errAEEventNotPermitted, -1744 needs user consent,
            // -600 the app isn't running yet
            if code == -1743 || code == -1744 {
                return .permissionDenied
            }
            return .unavailable
        }

        guard let descriptor, descriptor.numberOfItems >= 2 else { return .unavailable }

        let urlString = descriptor.atIndex(1)?.stringValue ?? ""
        let title = (descriptor.atIndex(2)?.stringValue ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        var host = URL(string: urlString)?.host
        if let h = host, h.hasPrefix("www.") { host = String(h.dropFirst(4)) }

        if !title.isEmpty {
            let label = title.count > maxTitleLength
                ? String(title.prefix(maxTitleLength - 1)) + "…"
                : title
            return .tab(label: label, host: host)
        }
        guard let host else { return .unavailable }
        return .tab(label: host, host: host)
    }
}
