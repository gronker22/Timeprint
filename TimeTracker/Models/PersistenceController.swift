import Foundation
import SwiftData

// Owns the single ModelContainer for the app. The store lives in
// Application Support so it survives app updates and reinstalls.
struct PersistenceController {
    static let shared = PersistenceController()

    let container: ModelContainer

    private init() {
        do {
            let storeDirectory = URL.applicationSupportDirectory
                .appending(path: "TimeTracker", directoryHint: .isDirectory)
            try FileManager.default.createDirectory(
                at: storeDirectory,
                withIntermediateDirectories: true
            )
            let configuration = ModelConfiguration(
                url: storeDirectory.appending(path: "TimeTracker.store")
            )
            container = try ModelContainer(
                for: AppSessionModel.self,
                configurations: configuration
            )
        } catch {
            // Without a store the app cannot fulfill its one purpose,
            // so failing loudly at launch is the right call here.
            fatalError("Failed to set up SwiftData store: \(error)")
        }
    }
}
