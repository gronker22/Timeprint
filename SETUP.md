# Setup — do this once before using Claude Code

These are the manual Xcode steps. Everything else Claude Code handles.

## 1. Create the Xcode project

1. Open Xcode → File → New → Project
2. Choose **macOS** → **App** → Next
3. Fill in:
   - Product Name: `TimeTracker`
   - Bundle Identifier: `com.yourname.timetracker`
   - Language: **Swift**
   - Interface: **SwiftUI**
4. Save it inside this folder (the one containing CLAUDE.md)

## 2. Add the Swift files

In Xcode's Project Navigator (left panel):

1. Right-click the `TimeTracker` group → New Group → name it `App`
2. Right-click the `TimeTracker` group → New Group → name it `Services`
3. Right-click the `TimeTracker` group → New Group → name it `Views`
4. Right-click the `TimeTracker` group → New Group → name it `Models`
5. Delete the auto-generated `ContentView.swift`
6. Drag each `.swift` file from Finder into the matching Xcode group:
   - `TimeTracker/App/` → drag into **App** group
   - `TimeTracker/Services/` → drag into **Services** group
   - `TimeTracker/Views/` → drag into **Views** group

## 3. Configure Info.plist

1. In the Project Navigator, click your project (top of the tree)
2. Select the **TimeTracker** target → **Info** tab
3. Click **+** to add a new row
4. Key: `Application is agent (UIElement)` → Type: Boolean → Value: **YES**

This hides the app from the Dock — it only lives in the menu bar.

## 4. Set the deployment target

- Target → **General** tab → Minimum Deployments → **macOS 14.0**

## 5. Run it

Hit **⌘R**. A clock icon should appear in your menu bar.
Click it — you'll see the popover. Switch between apps and watch the list fill up.

## 6. Hand off to Claude Code

Once it's running, open this whole folder in Claude Code:

```bash
cd /path/to/TimeTracker
claude
```

Then tell Claude Code:
```
Implement Phase 3 — add SwiftData persistence as described in CLAUDE.md
```

That's it. CLAUDE.md has everything Claude Code needs to know.
