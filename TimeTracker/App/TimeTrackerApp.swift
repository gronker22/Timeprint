import SwiftUI
import SwiftData

@main
struct TimeTrackerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Pure menu bar app — no dock window
        // Settings scene gives us a Cmd+, preferences window for free
        Settings {
            SettingsView()
        }
        .modelContainer(PersistenceController.shared.container)
    }
}
