import ArgumentParser
import Foundation
import PocketBook2CapacitiesCore

struct StatusCommand: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "status",
        abstract: "Show current configuration and sync status"
    )

    @Flag(name: .long, help: "Show detailed information about synced books")
    var detailed: Bool = false

    func run() async throws {
        let credentialStore = CredentialStore()
        let syncStateStore = try SyncStateStore()

        print("PocketBook2Capacities Status")
        print("════════════════════════════\n")

        // Credential status
        print(credentialStore.statusDescription)

        print("")

        // Sync state
        print(syncStateStore.statusDescription)

        // Test connections if configured
        if credentialStore.hasPocketBookCredentials {
            print("\n")
            print("Testing PocketBook Cloud connection...")

            let pocketBookClient = PocketBookClient(credentialStore: credentialStore)
            do {
                let books = try await pocketBookClient.getBooks()
                print("  ✓ Connected - \(books.count) book(s) in library")

                if detailed {
                    print("\n  Books with highlights:")
                    for bookItem in books.prefix(10) {
                        let highlights = try await pocketBookClient.getHighlights(forBook: bookItem)
                        if !highlights.isEmpty {
                            let syncInfo = syncStateStore.bookSyncInfo(bookId: bookItem.id)
                            let syncStatus = syncInfo ?? "Not synced"
                            print("    • \(bookItem.displayTitle)")
                            print("      \(highlights.count) highlight(s) - \(syncStatus)")
                        }
                    }
                    if books.count > 10 {
                        print("    ... and \(books.count - 10) more")
                    }
                }
            } catch {
                print("  ✗ Connection failed: \(error)")
            }
        }

        if credentialStore.hasCapacitiesCredentials {
            print("\n")
            print("Testing Capacities connection...")

            let capacitiesClient = CapacitiesClient(credentialStore: credentialStore)
            do {
                let spaces = try await capacitiesClient.getSpaces()

                if let selectedSpaceId = credentialStore.capacitiesSpaceId,
                   let selectedSpace = spaces.first(where: { $0.id == selectedSpaceId }) {
                    print("  ✓ Connected - Using space: \(selectedSpace.title)")
                } else {
                    print("  ✓ Connected - \(spaces.count) space(s) available")
                    print("  ⚠️ No space selected. Run 'pocketbook2capacities login --capacities-only' to select one.")
                }
            } catch {
                print("  ✗ Connection failed: \(error)")
            }
        }

        print("")
    }
}
