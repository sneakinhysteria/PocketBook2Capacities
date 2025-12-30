import Foundation

/// Result of a sync operation
public struct SyncResult {
    public let totalBooks: Int
    public let totalHighlights: Int
    public let skippedHighlights: Int
    public let errors: [String]

    public init(totalBooks: Int, totalHighlights: Int, skippedHighlights: Int, errors: [String]) {
        self.totalBooks = totalBooks
        self.totalHighlights = totalHighlights
        self.skippedHighlights = skippedHighlights
        self.errors = errors
    }

    public var hasErrors: Bool {
        !errors.isEmpty
    }
}

/// Service for syncing PocketBook highlights to Capacities
public final class SyncService {
    private let credentialStore: CredentialStore
    private let pocketBookClient: PocketBookClient
    private let capacitiesClient: CapacitiesClient
    private let syncStateStore: SyncStateStore
    private let formatter = MarkdownFormatter()
    private let merger = HighlightMerger()

    public init(credentialStore: CredentialStore) throws {
        self.credentialStore = credentialStore
        self.pocketBookClient = PocketBookClient(credentialStore: credentialStore)
        self.capacitiesClient = CapacitiesClient(credentialStore: credentialStore)
        self.syncStateStore = try SyncStateStore()
    }

    /// Perform sync operation
    /// - Parameter force: If true, re-sync all highlights ignoring sync state
    /// - Returns: Result of the sync operation
    public func sync(force: Bool = false) async throws -> SyncResult {
        // Check credentials
        guard credentialStore.hasPocketBookCredentials else {
            throw SyncServiceError.notConfigured("PocketBook Cloud not configured")
        }

        guard credentialStore.hasCapacitiesCredentials else {
            throw SyncServiceError.notConfigured("Capacities not configured")
        }

        guard let spaceId = credentialStore.capacitiesSpaceId else {
            throw SyncServiceError.notConfigured("No Capacities space selected")
        }

        // Fetch books
        let books = try await pocketBookClient.getBooks()

        var totalBooks = 0
        var totalHighlights = 0
        var skippedHighlights = 0
        var errors: [String] = []

        for book in books {
            // Fetch highlights for this book
            let highlights: [Highlight]
            do {
                highlights = try await pocketBookClient.getHighlights(forBook: book)
            } catch {
                errors.append("Failed to fetch highlights for '\(book.displayTitle)': \(error)")
                continue
            }

            // Skip books without highlights
            guard !highlights.isEmpty else {
                continue
            }

            // Merge split highlights
            let mergeResult = merger.mergeWithStats(highlights)

            // Filter to unsynced highlights (unless force)
            let highlightsToSync: [Highlight]
            if force {
                highlightsToSync = mergeResult.highlights
            } else {
                highlightsToSync = syncStateStore.filterUnsyncedHighlights(mergeResult.highlights, forBook: book.id)
            }

            // Skip if no new highlights
            if highlightsToSync.isEmpty {
                skippedHighlights += mergeResult.highlights.count
                continue
            }

            // Format for Capacities
            let bookMarkdown = formatter.formatBook(book, highlights: mergeResult.highlights)

            // Sync to Capacities
            do {
                let bookUrl = MarkdownFormatter.bookURL(for: book)

                let response = try await capacitiesClient.saveWeblink(
                    spaceId: spaceId,
                    url: bookUrl,
                    title: bookMarkdown.title,
                    description: bookMarkdown.description,
                    tags: bookMarkdown.tags,
                    markdown: bookMarkdown.markdown
                )

                // Update sync state
                for highlight in mergeResult.highlights {
                    try syncStateStore.markSynced(highlightId: highlight.id, forBook: book.id)
                }
                try syncStateStore.markBookSynced(
                    bookId: book.id,
                    capacitiesId: response.id,
                    highlightCount: mergeResult.highlights.count
                )

                totalBooks += 1
                totalHighlights += highlightsToSync.count

            } catch {
                errors.append("Failed to sync '\(book.displayTitle)': \(error)")
            }
        }

        // Update sync timestamp
        try syncStateStore.markSyncComplete()

        return SyncResult(
            totalBooks: totalBooks,
            totalHighlights: totalHighlights,
            skippedHighlights: skippedHighlights,
            errors: errors
        )
    }

    /// Reset sync state (for force resync)
    public func resetSyncState() throws {
        try syncStateStore.reset()
    }
}

/// Errors from sync service
public enum SyncServiceError: Error, LocalizedError {
    case notConfigured(String)
    case syncFailed(String)

    public var errorDescription: String? {
        switch self {
        case .notConfigured(let message):
            return message
        case .syncFailed(let message):
            return message
        }
    }
}
