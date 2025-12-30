import SwiftUI
import UserNotifications
import PocketBook2CapacitiesCore

@MainActor
class AppState: ObservableObject {
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var lastSyncResult: SyncResult?
    @Published var error: String?

    // Credentials status
    @Published var hasPocketBookCredentials = false
    @Published var hasCapacitiesCredentials = false
    @Published var capacitiesSpaceName: String?

    // Settings
    @AppStorage("autoSyncEnabled") var autoSyncEnabled = false
    @AppStorage("autoSyncInterval") var autoSyncInterval: TimeInterval = 3600  // 1 hour
    @AppStorage("showNotifications") var showNotifications = true

    private var syncService: SyncService?
    private var autoSyncTimer: Timer?

    init() {
        refreshCredentialStatus()
        setupAutoSync()
    }

    func refreshCredentialStatus() {
        // Create fresh instance to read latest from file
        let credentialStore = CredentialStore()
        hasPocketBookCredentials = credentialStore.hasPocketBookCredentials
        hasCapacitiesCredentials = credentialStore.hasCapacitiesCredentials
    }

    func setupAutoSync() {
        autoSyncTimer?.invalidate()
        guard autoSyncEnabled else { return }

        autoSyncTimer = Timer.scheduledTimer(withTimeInterval: autoSyncInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.sync()
            }
        }
    }

    func sync(force: Bool = false) async {
        guard !isSyncing else { return }
        guard hasPocketBookCredentials && hasCapacitiesCredentials else {
            error = "Please configure credentials first"
            return
        }

        isSyncing = true
        error = nil

        do {
            let credentialStore = CredentialStore()
            let service = try SyncService(credentialStore: credentialStore)
            let result = try await service.sync(force: force)
            lastSyncResult = result
            lastSyncDate = Date()

            if showNotifications && result.totalHighlights > 0 {
                sendNotification(result: result)
            }
        } catch {
            self.error = error.localizedDescription
        }

        isSyncing = false
    }

    private func sendNotification(result: SyncResult) {
        let content = UNMutableNotificationContent()
        content.title = "PocketBook Sync Complete"
        content.body = "Synced \(result.totalHighlights) highlight(s) from \(result.totalBooks) book(s)"

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    func logout(service: String) {
        let credentialStore = CredentialStore()
        if service == "pocketbook" {
            credentialStore.clearPocketBook()
        } else if service == "capacities" {
            credentialStore.clearCapacities()
        }
        refreshCredentialStatus()
    }
}
