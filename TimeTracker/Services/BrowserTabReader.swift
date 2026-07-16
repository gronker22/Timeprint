import Foundation

// Reads the active tab out of Google Chrome via Apple Events.
// First use triggers the macOS Automation permission prompt.
enum BrowserTabReader {

    static let chromeBundleID = "com.google.Chrome"

    // Compiled once — NSAppleScript compilation is the expensive part
    private static let script = NSAppleScript(source: """
        tell application "Google Chrome"
            if (count of windows) > 0 then
                return URL of active tab of front window
            end if
        end tell
        """)

    // Returns the active tab's domain ("youtube.com"), or nil if Chrome has
    // no windows or the user denied Automation access
    static func activeChromeDomain() -> String? {
        var error: NSDictionary?
        guard
            let urlString = script?.executeAndReturnError(&error).stringValue,
            let host = URL(string: urlString)?.host
        else { return nil }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }
}
