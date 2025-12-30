import SwiftUI
import PocketBook2CapacitiesCore

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Status section
            statusSection

            Divider()

            // Sync button
            Button {
                Task {
                    await appState.sync()
                }
            } label: {
                HStack {
                    if appState.isSyncing {
                        ProgressView()
                            .scaleEffect(0.5)
                            .frame(width: 16, height: 16)
                        Text("Syncing...")
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Sync Now")
                    }
                }
            }
            .disabled(appState.isSyncing || !appState.hasPocketBookCredentials || !appState.hasCapacitiesCredentials)
            .keyboardShortcut("s", modifiers: .command)

            Divider()

            // Settings
            SettingsLink {
                HStack {
                    Image(systemName: "gear")
                    Text("Settings...")
                }
            }
            .keyboardShortcut(",", modifiers: .command)

            Divider()

            // Quit
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                HStack {
                    Image(systemName: "power")
                    Text("Quit")
                }
            }
            .keyboardShortcut("q", modifiers: .command)
        }
    }

    @ViewBuilder
    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !appState.hasPocketBookCredentials || !appState.hasCapacitiesCredentials {
                Label("Not configured", systemImage: "exclamationmark.triangle")
                    .foregroundColor(.orange)
                Text("Open Settings to connect accounts")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else if let lastSync = appState.lastSyncDate {
                Label(lastSyncText(lastSync), systemImage: "checkmark.circle")
                    .foregroundColor(.green)

                if let result = appState.lastSyncResult {
                    Text("\(result.totalBooks) books, \(result.totalHighlights) highlights")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                Label("Ready to sync", systemImage: "checkmark.circle")
                    .foregroundColor(.green)
            }

            if let error = appState.error {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func lastSyncText(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return "Last sync: \(formatter.localizedString(for: date, relativeTo: Date()))"
    }
}
