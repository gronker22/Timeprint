import SwiftUI
import ServiceManagement

// Opened with Cmd+,
struct SettingsView: View {
    @AppStorage("idleThresholdMinutes") private var idleThresholdMinutes: Int = 2
    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = false
    @AppStorage("showMenuBarTotal") private var showMenuBarTotal: Bool = false

    @State private var excludedBundleIDs: [String] = []
    @State private var newExclusion: String = ""
    @State private var loginItemError: String?
    // Prevents the error-revert of the toggle from re-triggering onChange
    @State private var isSyncingLoginItem = false

    var body: some View {
        Form {
            trackingSection
            exclusionsSection
            systemSection
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 440)
        .navigationTitle("Settings")
        .onAppear(perform: load)
    }

    // MARK: — Sections

    private var trackingSection: some View {
        Section("Tracking") {
            Picker("Idle timeout", selection: $idleThresholdMinutes) {
                Text("1 minute").tag(1)
                Text("2 minutes").tag(2)
                Text("5 minutes").tag(5)
                Text("10 minutes").tag(10)
            }
            .pickerStyle(.menu)
            Text("Stop counting time after this many minutes of no input.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var exclusionsSection: some View {
        Section("Excluded apps") {
            ForEach(excludedBundleIDs, id: \.self) { bundleID in
                HStack {
                    Text(bundleID)
                        .font(.callout.monospaced())
                    Spacer()
                    Button {
                        excludedBundleIDs.removeAll { $0 == bundleID }
                        saveExclusions()
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                }
            }
            HStack {
                TextField("Bundle ID, e.g. com.apple.Safari", text: $newExclusion)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(addExclusion)
                Button("Add", action: addExclusion)
                    .disabled(newExclusion.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            Text("Time in these apps is not tracked.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var systemSection: some View {
        Section("System") {
            Toggle("Launch at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, enabled in
                    applyLaunchAtLogin(enabled)
                }
            if let loginItemError {
                Text(loginItemError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            Toggle("Show today's total in the menu bar", isOn: $showMenuBarTotal)
        }
    }

    // MARK: — Actions

    private func load() {
        excludedBundleIDs = UserDefaults.standard
            .stringArray(forKey: "excludedBundleIDs") ?? ["com.apple.finder"]

        // The OS is the source of truth for login-item state (the user can
        // change it in System Settings behind our back)
        isSyncingLoginItem = true
        launchAtLogin = SMAppService.mainApp.status == .enabled
        isSyncingLoginItem = false
    }

    private func saveExclusions() {
        UserDefaults.standard.set(excludedBundleIDs, forKey: "excludedBundleIDs")
    }

    private func addExclusion() {
        let bundleID = newExclusion.trimmingCharacters(in: .whitespaces)
        guard !bundleID.isEmpty, !excludedBundleIDs.contains(bundleID) else { return }
        excludedBundleIDs.append(bundleID)
        saveExclusions()
        newExclusion = ""
    }

    private func applyLaunchAtLogin(_ enabled: Bool) {
        guard !isSyncingLoginItem else { return }
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            loginItemError = nil
        } catch {
            loginItemError = "Couldn't update login item: \(error.localizedDescription)"
            isSyncingLoginItem = true
            launchAtLogin = !enabled
            isSyncingLoginItem = false
        }
    }
}
