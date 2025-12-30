import SwiftUI
import AppKit
import PocketBook2CapacitiesCore

struct SettingsView: View {
    var body: some View {
        TabView {
            AccountsTab()
                .tabItem {
                    Label("Accounts", systemImage: "person.2")
                }

            SyncOptionsTab()
                .tabItem {
                    Label("Sync", systemImage: "arrow.triangle.2.circlepath")
                }

            AboutTab()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 450, height: 300)
    }
}

struct AccountsTab: View {
    @EnvironmentObject var appState: AppState
    @State private var showingPocketBookLogin = false
    @State private var showingCapacitiesSetup = false

    var body: some View {
        Form {
            Section("PocketBook Cloud") {
                HStack {
                    if appState.hasPocketBookCredentials {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Connected")
                        Spacer()
                        Button("Logout") {
                            appState.logout(service: "pocketbook")
                        }
                    } else {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                        Text("Not connected")
                        Spacer()
                        Button("Login...") {
                            showingPocketBookLogin = true
                        }
                    }
                }
            }

            Section("Capacities") {
                HStack {
                    if appState.hasCapacitiesCredentials {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        VStack(alignment: .leading) {
                            Text("Connected")
                            if let spaceName = appState.capacitiesSpaceName {
                                Text("Space: \(spaceName)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        Button("Disconnect") {
                            appState.logout(service: "capacities")
                        }
                    } else {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                        Text("Not connected")
                        Spacer()
                        Button("Configure...") {
                            showingCapacitiesSetup = true
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .sheet(isPresented: $showingPocketBookLogin) {
            PocketBookLoginSheet()
                .environmentObject(appState)
        }
        .sheet(isPresented: $showingCapacitiesSetup) {
            CapacitiesSetupSheet()
                .environmentObject(appState)
        }
    }
}

struct SyncOptionsTab: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Form {
            Section("Automatic Sync") {
                Toggle("Enable auto-sync", isOn: $appState.autoSyncEnabled)
                    .onChange(of: appState.autoSyncEnabled) { _, _ in
                        appState.setupAutoSync()
                    }

                Picker("Sync interval", selection: $appState.autoSyncInterval) {
                    Text("15 minutes").tag(TimeInterval(900))
                    Text("30 minutes").tag(TimeInterval(1800))
                    Text("1 hour").tag(TimeInterval(3600))
                    Text("2 hours").tag(TimeInterval(7200))
                }
                .disabled(!appState.autoSyncEnabled)
            }

            Section("Notifications") {
                Toggle("Show sync notifications", isOn: $appState.showNotifications)
            }

            Section("Manual Sync") {
                Button("Force Full Resync") {
                    Task {
                        await appState.sync(force: true)
                    }
                }
                .disabled(appState.isSyncing)

                Text("This will re-sync all highlights, ignoring what was previously synced.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

struct AboutTab: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("PocketBook2Capacities")
                .font(.title)

            Text("Version 1.0.1")
                .foregroundColor(.secondary)

            Text("Sync your PocketBook Cloud highlights to Capacities")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            Link("View on GitHub", destination: URL(string: "https://github.com/sneakinhysteria/PocketBook2Capacities")!)

            Spacer()

            VStack(spacing: 8) {
                Text("Brought to you by")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Link(destination: URL(string: "https://from-scratch.net")!) {
                    if let url = Bundle.module.url(forResource: "from-scratch-logo", withExtension: "png"),
                       let nsImage = NSImage(contentsOf: url) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 40)
                    } else {
                        Text("From Scratch")
                            .font(.headline)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState())
}
