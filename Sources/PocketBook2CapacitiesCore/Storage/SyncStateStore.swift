import Foundation

/// Persists sync state to disk
public final class SyncStateStore {
    private let configDirectory: URL
    private let stateFile: URL

    private var state: SyncState

    public init() throws {
        // Create config directory in ~/.config/pocketbook2capacities/
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        configDirectory = homeDir
            .appendingPathComponent(".config")
            .appendingPathComponent("pocketbook2capacities")

        stateFile = configDirectory.appendingPathComponent("sync-state.json")

        // Ensure directory exists
        try FileManager.default.createDirectory(
            at: configDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )

        // Load existing state or create new
        state = try Self.load(from: stateFile)
    }

    // MARK: - State Access

    public var lastSync: Date? {
        state.lastSync
    }

    public var totalSyncedBooks: Int {
        state.totalSyncedBooks
    }

    public var totalSyncedHighlights: Int {
        state.totalSyncedHighlights
    }

    public var capacitiesSpaceId: String? {
        get { state.capacitiesSpaceId }
        set {
            state.capacitiesSpaceId = newValue
            try? save()
        }
    }

    // MARK: - Sync State Management

    /// Check if a highlight has been synced
    public func isSynced(highlightId: String, forBook bookId: String) -> Bool {
        return state.isSynced(highlightId: highlightId, forBook: bookId)
    }

    /// Mark a highlight as synced
    public func markSynced(highlightId: String, forBook bookId: String) throws {
        state.markSynced(highlightId: highlightId, forBook: bookId)
        try save()
    }

    /// Mark a book as synced with its Capacities ID
    public func markBookSynced(bookId: String, capacitiesId: String, highlightCount: Int) throws {
        state.markBookSynced(bookId: bookId, capacitiesId: capacitiesId, highlightCount: highlightCount)
        try save()
    }

    /// Get the Capacities ID for a previously synced book
    public func getCapacitiesId(forBook bookId: String) -> String? {
        return state.getCapacitiesId(forBook: bookId)
    }

    /// Mark sync complete and update timestamp
    public func markSyncComplete() throws {
        state.lastSync = Date()
        try save()
    }

    /// Filter highlights to only those not yet synced
    public func filterUnsyncedHighlights(_ highlights: [Highlight], forBook bookId: String) -> [Highlight] {
        return highlights.filter { !isSynced(highlightId: $0.id, forBook: bookId) }
    }

    /// Get count of synced highlights for a book
    public func syncedHighlightCount(forBook bookId: String) -> Int {
        return state.syncedHighlightCount(forBook: bookId)
    }

    /// Reset all sync state
    public func reset() throws {
        state.reset()
        try save()
    }

    // MARK: - Persistence

    private func save() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(state)
        try data.write(to: stateFile, options: .atomic)
    }

    private static func load(from url: URL) throws -> SyncState {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return SyncState()
        }

        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return try decoder.decode(SyncState.self, from: data)
    }
}

// MARK: - Status Display

public extension SyncStateStore {
    var statusDescription: String {
        var lines: [String] = []

        lines.append("Sync State:")

        if let lastSync = lastSync {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .full
            let relative = formatter.localizedString(for: lastSync, relativeTo: Date())
            lines.append("  Last sync: \(relative)")
        } else {
            lines.append("  Last sync: Never")
        }

        lines.append("  Books synced: \(totalSyncedBooks)")
        lines.append("  Highlights synced: \(totalSyncedHighlights)")

        if let spaceId = capacitiesSpaceId {
            lines.append("  Capacities space: \(spaceId)")
        }

        return lines.joined(separator: "\n")
    }

    /// Get detailed sync information for a specific book
    func bookSyncInfo(bookId: String) -> String? {
        guard let info = state.syncedBooks[bookId] else {
            return nil
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        return "Last synced: \(formatter.string(from: info.lastSyncedAt)), \(info.highlightCount) highlights"
    }
}
