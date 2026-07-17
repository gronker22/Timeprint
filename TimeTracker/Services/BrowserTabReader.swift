import Foundation

// Reads the active tab out of Google Chrome via Apple Events.
// First use triggers the macOS Automation permission prompt.
enum BrowserTabReader {

    static let chromeBundleID = "com.google.Chrome"

    // Titles can be very long ("Some 90-word article headline - Medium");
    // cap them so rows and charts stay readable
    private static let maxTitleLength = 60

    // Compiled once — NSAppleScript compilation is the expensive part
    private static let script = NSAppleScript(source: """
        tell application "Google Chrome"
            if (count of windows) > 0 then
                return {URL, title} of active tab of front window
            end if
        end tell
        """)

    // The exact page the user is looking at: display label (tab title, falling
    // back to the domain) plus the domain itself for categorization.
    // Nil if Chrome has no windows or the user denied Automation access.
    static func activeChromeTab() -> (label: String, host: String?)? {
        var error: NSDictionary?
        guard let descriptor = script?.executeAndReturnError(&error),
              descriptor.numberOfItems >= 2 else { return nil }

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
