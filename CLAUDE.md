# TimeTracker — Native Apple Silicon Mac Menu Bar App

## What this is

A lightweight, native macOS time tracking app that lives in the menu bar.
It automatically tracks which app the user is in, aggregates time by app,
and shows a clean popover summary. Built for Apple Silicon (M1+), targeting
the Mac App Store.

This is a replacement for **Desklog**, which was never updated for Apple Silicon
and is now abandoned. There is no strong native alternative in this space.

---

## Tech stack

- **Language**: Swift 5.9+
- **UI**: SwiftUI + AppKit (for menu bar and popover plumbing)
- **Persistence**: SwiftData (macOS 14+)
- **Charts**: Swift Charts (built-in, macOS 13+)
- **Minimum deployment target**: macOS 14.0 (Sonoma)
- **Architecture**: MVVM — ObservableObject view models, SwiftUI views

---

## Current state (what is already built)

All files in `/TimeTracker/` are working starter code. Here's what each does:

### App/
- `TimeTrackerApp.swift` — `@main` entry point. Uses `@NSApplicationDelegateAdaptor`
  to hand off menu bar setup to AppDelegate. Provides a `Settings {}` scene for Cmd+,.
- `AppDelegate.swift` — Creates the `NSStatusItem` (menu bar icon), creates the
  `NSPopover`, and injects the shared `AppWatcher` via `.environmentObject()`.

### Services/
- `AppWatcher.swift` — The core engine. An `ObservableObject` that:
  - Observes `NSWorkspace.didActivateApplicationNotification` to detect app switches
  - Maintains an in-memory array of `AppSession` structs
  - Publishes `todaySummary` (aggregated time per app, sorted by duration)
  - Has a 5-second tick timer so live durations refresh in the UI
  - Has `toggleTracking()` to pause/resume

### Views/
- `MenuBarPopoverView.swift` — Root view shown in the popover. Header with total
  time, scrollable app list, footer with live indicator and pause/quit buttons.
- `AppRowView.swift` — One row per tracked app: icon, name, formatted duration,
  proportional progress bar, green dot if currently active.
- `SettingsView.swift` — Placeholder settings with idle timeout picker and
  launch-at-login toggle (not yet wired to real APIs).
- `Helpers.swift` — `formatDuration(_ duration: TimeInterval) -> String` utility.

---

## What needs to be built (in priority order)

### Phase 3 — SwiftData persistence ⬅ START HERE
**Goal**: sessions survive app restarts.

Currently `AppWatcher` stores sessions in a plain Swift array that is lost on quit.
We need to replace this with SwiftData.

Tasks:
1. Create `Models/AppSessionModel.swift` — a `@Model` class with:
   - `id: UUID`
   - `appName: String`
   - `bundleIdentifier: String`
   - `startTime: Date`
   - `endTime: Date?`
2. Create `Models/PersistenceController.swift` — a singleton that sets up
   `ModelContainer` for `AppSessionModel`, stored in Application Support.
3. Modify `AppWatcher.swift`:
   - Inject `ModelContext` via init
   - On app switch: save the closed session to SwiftData
   - On `todaySummary`: query SwiftData for today's sessions instead of
     filtering the in-memory array (keep the in-memory array only for the
     current live session)
4. Update `AppDelegate.swift` to create the `ModelContainer` and pass the
   `ModelContext` into `AppWatcher`.
5. Update `TimeTrackerApp.swift` to attach the `modelContainer` to the
   Settings scene.

### Phase 4 — Weekly chart view
**Goal**: show a bar chart of the top 5 apps over the last 7 days.

Tasks:
1. Add a `ChartView.swift` in Views/:
   - Use `Swift Charts` `BarMark`
   - X axis: last 7 days (show day abbreviation)
   - Y axis: hours tracked
   - Color by app name (use a fixed palette — see note below)
   - Tap/hover on a bar to show a tooltip breakdown
2. Add a tab bar or segmented control to `MenuBarPopoverView` to switch
   between "Today" (existing) and "Week" (new chart).
3. Add a "Export CSV" button that writes a CSV of all sessions to
   `~/Downloads/timetracker-export.csv`. Each row: date, appName, duration(s).

Note on chart colors: assign a fixed color per app name by hashing the name
to an index into a 8-color palette. This way the same app always gets the
same color across days.

### Phase 5 — Polish and App Store prep
**Goal**: ship-ready.

Tasks:
1. **Idle detection**: every 30s, check `CGEventSource.secondsSinceLastEventType()`
   for both keyboard and mouse. If idle > `idleThresholdMinutes * 60`, call
   `watcher.handleIdle()` which ends the current session and sets `isIdle = true`.
   Resume on next app-switch event.
2. **App exclusions**: add a `Set<String>` of excluded bundle IDs to `AppWatcher`
   (default: `["com.apple.finder"]`). Skip creating sessions for excluded apps.
   Let user add/remove exclusions in SettingsView.
3. **Launch at login**: wire the `launchAtLogin` toggle in SettingsView to
   `SMAppService.mainApp.register()` / `.unregister()`. Import ServiceManagement.
4. **Menu bar label**: optionally show today's total time next to the clock icon,
   updating every minute. Controlled by a Settings toggle.
5. **App icon**: create a clock-themed icon in Assets.xcassets. Provide all
   required sizes (16, 32, 64, 128, 256, 512 @1x and @2x).
6. **Entitlements**: the app needs no special entitlements for basic tracking.
   For App Store: enable Sandbox, add `com.apple.security.files.user-selected.read-write`
   only if we add file export.

---

## Xcode project setup (human does this once)

The developer creates a blank Xcode project and drops these files in.
Do NOT try to create the `.xcodeproj` yourself — Xcode generates it.

Manual steps the human must do:
1. Xcode → File → New → Project → macOS → App
2. Product Name: `TimeTracker`, Team: their Apple ID, Bundle ID: `com.yourname.timetracker`
3. Language: Swift, Interface: SwiftUI
4. Delete auto-generated `ContentView.swift`
5. Create Groups matching the folder structure: App/, Services/, Views/, Models/
6. Drag all `.swift` files into the matching groups
7. In the target's Info tab, add key `Application is agent (UIElement)` = YES
8. Set Deployment Target to macOS 14.0
9. In Signing & Capabilities, add the App Sandbox capability (required for App Store)

---

## Coding conventions

- **Naming**: Swift standard — PascalCase types, camelCase vars/funcs, verb phrases for functions
- **SwiftUI**: Prefer `@EnvironmentObject` for shared state (`AppWatcher`), `@State` for local UI state
- **No third-party dependencies** — use only Apple frameworks
- **Comments**: explain *why*, not *what*. Code should be self-documenting
- **Error handling**: use `guard let` early returns, never force-unwrap `!` in production paths
- **Formatting**: 4-space indent, trailing comma in multi-line collections
- **File length**: keep files under ~150 lines; extract to new files when they grow

---

## Key APIs quick reference

```swift
// Detect app switches
NSWorkspace.shared.notificationCenter
    .publisher(for: NSWorkspace.didActivateApplicationNotification)

// Get current frontmost app
NSWorkspace.shared.frontmostApplication?.localizedName
NSWorkspace.shared.frontmostApplication?.bundleIdentifier

// Get app icon (for running apps)
NSRunningApplication.icon  // NSImage?

// Idle time detection (Phase 5)
CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .mouseMoved)
CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .keyDown)

// Launch at login (Phase 5)
import ServiceManagement
try SMAppService.mainApp.register()
try SMAppService.mainApp.unregister()

// SwiftData (Phase 3)
@Model class AppSessionModel { ... }
ModelContainer(for: AppSessionModel.self)
context.insert(model)
let descriptor = FetchDescriptor<AppSessionModel>(predicate: ..., sortBy: ...)
try context.fetch(descriptor)

// Swift Charts (Phase 4)
import Charts
Chart(data, id: \.app) { item in
    BarMark(x: .value("Day", item.date), y: .value("Hours", item.hours))
        .foregroundStyle(by: .value("App", item.app))
}
```

---

## File tree (target state after all phases)

```
TimeTracker/
├── CLAUDE.md                          ← this file
├── TimeTracker/
│   ├── App/
│   │   ├── TimeTrackerApp.swift       ✅ done
│   │   └── AppDelegate.swift          ✅ done (update in Phase 3)
│   ├── Services/
│   │   └── AppWatcher.swift           ✅ done (update in Phase 3)
│   ├── Models/
│   │   ├── AppSessionModel.swift      ⬜ Phase 3
│   │   └── PersistenceController.swift ⬜ Phase 3
│   └── Views/
│       ├── MenuBarPopoverView.swift   ✅ done (update in Phase 4)
│       ├── AppRowView.swift           ✅ done
│       ├── ChartView.swift            ⬜ Phase 4
│       ├── SettingsView.swift         ✅ done (update in Phase 5)
│       └── Helpers.swift              ✅ done
```

---

## How to ask Claude Code to continue

Good prompts:
- "Implement Phase 3 — add SwiftData persistence as described in CLAUDE.md"
- "Build ChartView.swift for Phase 4 using Swift Charts"
- "Add idle detection to AppWatcher as described in Phase 5"
- "Write the CSV export button for the week view"
- "Review AppWatcher.swift for any memory leaks or threading issues"
