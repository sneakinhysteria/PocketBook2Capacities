import Foundation

/// Secure storage for credentials
/// Uses file-based storage to avoid Keychain prompts with unsigned apps
public final class CredentialStore {
    private let configDirectory: URL
    private let credentialsFile: URL
    private var credentials: StoredCredentials

    private struct StoredCredentials: Codable {
        var pocketBookRefreshToken: String?
        var pocketBookAccessToken: String?
        var pocketBookTokenExpiry: Date?
        var pocketBookShopAlias: String?
        var capacitiesApiToken: String?
        var capacitiesSpaceId: String?

        static let empty = StoredCredentials()
    }

    public init() {
        // Create config directory
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        configDirectory = homeDir
            .appendingPathComponent(".config")
            .appendingPathComponent("pocketbook2capacities")

        credentialsFile = configDirectory.appendingPathComponent("credentials.json")

        // Load or create credentials
        if let data = try? Data(contentsOf: credentialsFile),
           let stored = try? JSONDecoder().decode(StoredCredentials.self, from: data) {
            credentials = stored
        } else {
            credentials = StoredCredentials.empty
        }
    }

    private func save() {
        try? FileManager.default.createDirectory(at: configDirectory, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(credentials) {
            // Set file permissions to owner-only (600)
            try? data.write(to: credentialsFile)
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: credentialsFile.path)
        }
    }

    // MARK: - PocketBook Credentials

    public var pocketBookRefreshToken: String? {
        get { credentials.pocketBookRefreshToken }
        set {
            credentials.pocketBookRefreshToken = newValue
            save()
        }
    }

    public var pocketBookAccessToken: String? {
        get { credentials.pocketBookAccessToken }
        set {
            credentials.pocketBookAccessToken = newValue
            save()
        }
    }

    public var pocketBookTokenExpiry: Date? {
        get { credentials.pocketBookTokenExpiry }
        set {
            credentials.pocketBookTokenExpiry = newValue
            save()
        }
    }

    public var pocketBookShopAlias: String? {
        get { credentials.pocketBookShopAlias }
        set {
            credentials.pocketBookShopAlias = newValue
            save()
        }
    }

    /// Check if access token is still valid (with 5 minute buffer)
    public var isPocketBookTokenValid: Bool {
        guard pocketBookAccessToken != nil,
              let expiry = pocketBookTokenExpiry else {
            return false
        }
        return expiry > Date().addingTimeInterval(300) // 5 minute buffer
    }

    /// Check if we have any PocketBook credentials stored
    public var hasPocketBookCredentials: Bool {
        return pocketBookRefreshToken != nil
    }

    // MARK: - Capacities Credentials

    public var capacitiesApiToken: String? {
        get { credentials.capacitiesApiToken }
        set {
            credentials.capacitiesApiToken = newValue
            save()
        }
    }

    public var capacitiesSpaceId: String? {
        get { credentials.capacitiesSpaceId }
        set {
            credentials.capacitiesSpaceId = newValue
            save()
        }
    }

    /// Check if we have Capacities credentials stored
    public var hasCapacitiesCredentials: Bool {
        return capacitiesApiToken != nil && capacitiesSpaceId != nil
    }

    // MARK: - Token Management

    /// Store new PocketBook tokens
    public func storePocketBookTokens(accessToken: String, refreshToken: String, expiresIn: Int, shopAlias: String) {
        credentials.pocketBookAccessToken = accessToken
        credentials.pocketBookRefreshToken = refreshToken
        credentials.pocketBookTokenExpiry = Date().addingTimeInterval(TimeInterval(expiresIn))
        credentials.pocketBookShopAlias = shopAlias
        save()
    }

    /// Update access token after refresh
    public func updatePocketBookAccessToken(accessToken: String, expiresIn: Int) {
        credentials.pocketBookAccessToken = accessToken
        credentials.pocketBookTokenExpiry = Date().addingTimeInterval(TimeInterval(expiresIn))
        save()
    }

    // MARK: - Clearing Credentials

    /// Clear all stored credentials
    public func clearAll() {
        credentials = StoredCredentials.empty
        save()
    }

    /// Clear only PocketBook credentials
    public func clearPocketBook() {
        credentials.pocketBookRefreshToken = nil
        credentials.pocketBookAccessToken = nil
        credentials.pocketBookTokenExpiry = nil
        credentials.pocketBookShopAlias = nil
        save()
    }

    /// Clear only Capacities credentials
    public func clearCapacities() {
        credentials.capacitiesApiToken = nil
        credentials.capacitiesSpaceId = nil
        save()
    }
}

// MARK: - Status Display

public extension CredentialStore {
    var statusDescription: String {
        var lines: [String] = []

        lines.append("Credentials:")

        // PocketBook status
        if hasPocketBookCredentials {
            if isPocketBookTokenValid {
                lines.append("  PocketBook: ✓ Logged in (token valid)")
            } else {
                lines.append("  PocketBook: ✓ Logged in (token expired, will refresh)")
            }
            if let shop = pocketBookShopAlias {
                lines.append("    Shop: \(shop)")
            }
        } else {
            lines.append("  PocketBook: ✗ Not configured")
        }

        // Capacities status
        if hasCapacitiesCredentials {
            lines.append("  Capacities: ✓ Configured")
            if let spaceId = capacitiesSpaceId {
                lines.append("    Space ID: \(spaceId)")
            }
        } else if capacitiesApiToken != nil {
            lines.append("  Capacities: ⚠ API token set, but no space selected")
        } else {
            lines.append("  Capacities: ✗ Not configured")
        }

        return lines.joined(separator: "\n")
    }
}
