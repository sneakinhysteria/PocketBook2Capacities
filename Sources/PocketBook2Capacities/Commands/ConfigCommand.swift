import ArgumentParser
import Foundation
import PocketBook2CapacitiesCore

struct ConfigCommand: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "config",
        abstract: "Manage configuration settings"
    )

    @Flag(name: .long, help: "Reset all credentials and sync state")
    var reset: Bool = false

    @Flag(name: .long, help: "Reset only PocketBook credentials")
    var resetPocketbook: Bool = false

    @Flag(name: .long, help: "Reset only Capacities credentials")
    var resetCapacities: Bool = false

    @Flag(name: .long, help: "Reset only sync state (keeps credentials)")
    var resetSync: Bool = false

    @Option(name: .long, help: "Set the Capacities space ID directly")
    var space: String?

    func run() async throws {
        let credentialStore = CredentialStore()
        let syncStateStore = try SyncStateStore()

        var madeChanges = false

        // Handle resets
        if reset {
            print("Resetting all configuration...")
            credentialStore.clearAll()
            try syncStateStore.reset()
            print("✓ All credentials and sync state cleared")
            madeChanges = true
        } else {
            if resetPocketbook {
                print("Resetting PocketBook credentials...")
                credentialStore.clearPocketBook()
                print("✓ PocketBook credentials cleared")
                madeChanges = true
            }

            if resetCapacities {
                print("Resetting Capacities credentials...")
                credentialStore.clearCapacities()
                print("✓ Capacities credentials cleared")
                madeChanges = true
            }

            if resetSync {
                print("Resetting sync state...")
                try syncStateStore.reset()
                print("✓ Sync state cleared (credentials preserved)")
                madeChanges = true
            }
        }

        // Handle space ID setting
        if let spaceId = space {
            print("Setting Capacities space ID...")

            // Validate the space ID if we have credentials
            if credentialStore.hasCapacitiesCredentials {
                let client = CapacitiesClient(credentialStore: credentialStore)
                let spaces = try await client.getSpaces()

                if let matchingSpace = spaces.first(where: { $0.id == spaceId }) {
                    credentialStore.capacitiesSpaceId = spaceId
                    print("✓ Space set to: \(matchingSpace.title)")
                    madeChanges = true
                } else {
                    print("⚠️ Space ID '\(spaceId)' not found. Available spaces:")
                    for spaceItem in spaces {
                        print("  • \(spaceItem.id): \(spaceItem.title)")
                    }
                    throw ConfigError.invalidSpaceId
                }
            } else {
                // No credentials, just set the ID
                credentialStore.capacitiesSpaceId = spaceId
                print("✓ Space ID set to: \(spaceId)")
                print("  (Note: Could not validate - Capacities not configured)")
                madeChanges = true
            }
        }

        // Show current config if no changes made
        if !madeChanges {
            print("Current Configuration")
            print("═════════════════════\n")
            print(credentialStore.statusDescription)
            print("")
            print(syncStateStore.statusDescription)
            print("")
            print("Use --reset, --reset-pocketbook, --reset-capacities, or --reset-sync to clear settings.")
            print("Use --space <id> to change the Capacities space.")
        }
    }
}

enum ConfigError: Error, CustomStringConvertible {
    case invalidSpaceId

    var description: String {
        switch self {
        case .invalidSpaceId:
            return "Invalid space ID"
        }
    }
}
