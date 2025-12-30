import ArgumentParser
import Foundation
import PocketBook2CapacitiesCore

struct LoginCommand: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "login",
        abstract: "Configure PocketBook Cloud and Capacities credentials"
    )

    @Flag(name: .long, help: "Only configure PocketBook Cloud")
    var pocketbookOnly: Bool = false

    @Flag(name: .long, help: "Only configure Capacities")
    var capacitiesOnly: Bool = false

    func run() async throws {
        let credentialStore = CredentialStore()

        if !capacitiesOnly {
            try await configurePocketBook(credentialStore: credentialStore)
        }

        if !pocketbookOnly {
            try await configureCapacities(credentialStore: credentialStore)
        }

        print("\n✅ Login complete!")
    }

    private func configurePocketBook(credentialStore: CredentialStore) async throws {
        print("📚 PocketBook Cloud Configuration")
        print("─────────────────────────────────")

        // Get email first (needed for shop discovery)
        print("Enter your PocketBook email: ", terminator: "")
        guard let email = readLine(), !email.isEmpty else {
            throw LoginError.emptyEmail
        }

        let client = PocketBookClient(credentialStore: credentialStore)

        // Get available shops for this user
        print("Fetching available shops...")
        let shops = try await client.getShops(username: email)

        guard !shops.isEmpty else {
            throw LoginError.noShopsAvailable
        }

        // Show shop selection if multiple
        let selectedShop: Shop
        if shops.count == 1 {
            selectedShop = shops[0]
            print("Using shop: \(selectedShop.name)")
        } else {
            print("\nAvailable shops:")
            for (index, shop) in shops.enumerated() {
                print("  \(index + 1). \(shop.name) (\(shop.alias))")
            }

            print("\nEnter shop number (1-\(shops.count)): ", terminator: "")
            guard let input = readLine(),
                  let index = Int(input),
                  index >= 1 && index <= shops.count else {
                throw LoginError.invalidShopSelection
            }
            selectedShop = shops[index - 1]
        }

        // Get password (getpass shows its own prompt)
        guard let password = getPassword("Enter your PocketBook password: "), !password.isEmpty else {
            throw LoginError.emptyPassword
        }

        // Login
        print("\nAuthenticating...")
        _ = try await client.login(email: email, password: password, shop: selectedShop)

        print("✓ PocketBook Cloud configured successfully!")
    }

    private func configureCapacities(credentialStore: CredentialStore) async throws {
        print("\n📝 Capacities Configuration")
        print("────────────────────────────")
        print("Get your API token from: Capacities Desktop App → Settings → Capacities API")
        print("\nEnter your Capacities API token: ", terminator: "")

        guard let token = readLine(), !token.isEmpty else {
            throw LoginError.emptyToken
        }

        // Store token temporarily to test it
        credentialStore.capacitiesApiToken = token

        let client = CapacitiesClient(credentialStore: credentialStore)

        // Fetch spaces
        print("Fetching your spaces...")
        let spaces = try await client.getSpaces()

        guard !spaces.isEmpty else {
            throw LoginError.noSpacesFound
        }

        // Show space selection
        print("\nAvailable spaces:")
        for (index, space) in spaces.enumerated() {
            let icon = space.icon?.displayValue ?? "📁"
            print("  \(index + 1). \(icon) \(space.title)")
        }

        print("\nEnter space number (1-\(spaces.count)): ", terminator: "")
        guard let input = readLine(),
              let index = Int(input),
              index >= 1 && index <= spaces.count else {
            throw LoginError.invalidSpaceSelection
        }

        let selectedSpace = spaces[index - 1]
        credentialStore.capacitiesSpaceId = selectedSpace.id

        print("✓ Capacities configured successfully! Using space: \(selectedSpace.title)")
    }

    /// Read password without echoing to terminal
    private func getPassword(_ prompt: String) -> String? {
        let password = String(cString: getpass(prompt))
        return password.isEmpty ? nil : password
    }
}

enum LoginError: Error, CustomStringConvertible {
    case noShopsAvailable
    case invalidShopSelection
    case emptyEmail
    case emptyPassword
    case emptyToken
    case noSpacesFound
    case invalidSpaceSelection

    var description: String {
        switch self {
        case .noShopsAvailable:
            return "No PocketBook shops available"
        case .invalidShopSelection:
            return "Invalid shop selection"
        case .emptyEmail:
            return "Email cannot be empty"
        case .emptyPassword:
            return "Password cannot be empty"
        case .emptyToken:
            return "API token cannot be empty"
        case .noSpacesFound:
            return "No Capacities spaces found"
        case .invalidSpaceSelection:
            return "Invalid space selection"
        }
    }
}
