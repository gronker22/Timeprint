import Foundation

// Reads the active tab out of Google Chrome or Safari via Apple Events.
// First use per browser triggers the macOS Automation permission prompt.
enum BrowserTabReader {

    static let chromeBundleID = "com.google.Chrome"
    static let safariBundleID = "com.apple.Safari"
    static let browserBundleIDs: Set<String> = [chromeBundleID, safariBundleID]

    // Titles can be very long; cap them so rows and charts stay readable
    private static let maxTitleLength = 60

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

    // The exact page the user is looking at: display label (tab title, falling
    // back to the domain) plus the domain itself for categorization.
    // Nil for non-browsers, no open windows, or denied Automation access.
    static func activeTab(bundleID: String) -> (label: String, host: String?)? {
        let script: NSAppleScript?
        switch bundleID {
        case chromeBundleID: script = chromeScript
        case safariBundleID: script = safariScript
        default: return nil
        }

        var error: NSDictionary?
        let result = script?.executeAndReturnError(&error)
        if let error {
            // Most commonly -1743: Automation permission denied — visible in
            // Console.app when a browser stubbornly won't split into tabs
            NSLog("Focusprint: tab read failed for \(bundleID) — \(error)")
        }
        guard let descriptor = result, descriptor.numberOfItems >= 2 else { return nil }

        let urlString = descriptor.atIndex(1)?.stringValue ?? ""
        let title = (descriptor.atIndex(2)?.stringValue ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        var host = URL(string: urlString)?.host
        if let h = host, h.hasPrefix("www.") { host = String(h.dropFirst(4)) }

        if !title.isEmpty {
            let label = title.count > maxTitleLength
                ? String(title.prefix(maxTitleLength - 1)) + "…"
                : title
            return (label, host)
        }
        guard let host else { return nil }
        return (host, host)
    }
}
