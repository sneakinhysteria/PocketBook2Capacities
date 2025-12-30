import Foundation

/// Tracks what has been synced to Capacities
struct SyncState: Codable {
    var lastSync: Date?
    var syncedHighlights: [String: [String]]
    var syncedBooks: [String: BookSyncInfo]
    var capacitiesSpaceId: String?

    init() {
        self.lastSync = nil
        self.syncedHighlights = [:]
        self.syncedBooks = [:]
        self.capacitiesSpaceId = nil
    }

    /// Check if a highlight has been synced
    func isSynced(highlightId: String, forBook bookId: String) -> Bool {
        return syncedHighlights[bookId]?.contains(highlightId) ?? false
    }

    /// Mark a highlight as synced
    mutating func markSynced(highlightId: String, forBook bookId: String) {
        if syncedHighlights[bookId] == nil {
            syncedHighlights[bookId] = []
        }
        if !syncedHighlights[bookId]!.contains(highlightId) {
            syncedHighlights[bookId]!.append(highlightId)
        }
    }

    /// Mark a book as synced with its Capacities weblink ID
    mutating func markBookSynced(bookId: String, capacitiesId: String, highlightCount: Int) {
        syncedBooks[bookId] = BookSyncInfo(
            capacitiesId: capacitiesId,
            lastSyncedAt: Date(),
            highlightCount: highlightCount
        )
    }

    /// Get Capacities ID for a previously synced book
    func getCapacitiesId(forBook bookId: String) -> String? {
        return syncedBooks[bookId]?.capacitiesId
    }

    /// Get count of synced highlights for a book
    func syncedHighlightCount(forBook bookId: String) -> Int {
        return syncedHighlights[bookId]?.count ?? 0
    }

    /// Get total number of synced books
    var totalSyncedBooks: Int {
        return syncedBooks.count
    }

    /// Get total number of synced highlights
    var totalSyncedHighlights: Int {
        return syncedHighlights.values.reduce(0) { $0 + $1.count }
    }

    /// Clear all sync state
    mutating func reset() {
        lastSync = nil
        syncedHighlights = [:]
        syncedBooks = [:]
    }
}

struct BookSyncInfo: Codable {
    let capacitiesId: String
    let lastSyncedAt: Date
    let highlightCount: Int
}

/// Configuration for the sync process
struct SyncConfiguration {
    let dryRun: Bool
    let force: Bool
    let bookFilter: String?

    init(dryRun: Bool = false, force: Bool = false, bookFilter: String? = nil) {
        self.dryRun = dryRun
        self.force = force
        self.bookFilter = bookFilter
    }
}

