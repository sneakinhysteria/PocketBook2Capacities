import SwiftUI
import PocketBook2CapacitiesCore

@main
struct PocketBook2CapacitiesApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(appState)
        } label: {
            Label("PocketBook Sync", systemImage: appState.isSyncing ? "arrow.triangle.2.circlepath" : "book.closed")
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
}
