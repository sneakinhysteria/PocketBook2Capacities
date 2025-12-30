import ArgumentParser
import Foundation
import PocketBook2CapacitiesCore

struct SyncCommand: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "sync",
        abstract: "Sync highlights from PocketBook Cloud to Capacities"
    )

    @Flag(name: .long, help: "Show what would be synced without making changes")
    var dryRun: Bool = false

    @Flag(name: .long, help: "Force resync all highlights, ignoring sync state")
    var force: Bool = false

    @Option(name: .long, help: "Only sync a specific book (by title)")
    var book: String?

    @Flag(name: .long, help: "Show verbose output")
    var verbose: Bool = false

    func run() async throws {
        let credentialStore = CredentialStore()
        let syncStateStore = try SyncStateStore()

        // Check credentials
        guard credentialStore.hasPocketBookCredentials else {
            throw SyncCommandError.notConfigured("PocketBook Cloud not configured. Run 'pocketbook2capacities login' first.")
        }

        guard credentialStore.hasCapacitiesCredentials else {
            throw SyncCommandError.notConfigured("Capacities not configured. Run 'pocketbook2capacities login' first.")
        }

        let pocketBookClient = PocketBookClient(credentialStore: credentialStore)
        let capacitiesClient = CapacitiesClient(credentialStore: credentialStore)
        let formatter = MarkdownFormatter()
        let merger = HighlightMerger()

        if dryRun {
            print("🔍 Dry run mode - no changes will be made")
        }

        // Fetch books
        print("📚 Fetching books from PocketBook Cloud...")
        var books = try await pocketBookClient.getBooks()

        // Filter by book title if specified
        if let bookFilter = book {
            books = books.filter { $0.title.localizedCaseInsensitiveContains(bookFilter) }
            if books.isEmpty {
                print("No books found matching '\(bookFilter)'")
                return
            }
            print("Found \(books.count) book(s) matching '\(bookFilter)'")
        }

        var totalBooks = 0
        var totalHighlights = 0
        var skippedHighlights = 0
        var errors: [String] = []

        guard let spaceId = credentialStore.capacitiesSpaceId else {
            throw SyncCommandError.notConfigured("No Capacities space selected. Run 'pocketbook2capacities login' first.")
        }

        for bookItem in books {
            if verbose {
                print("\nProcessing: \(bookItem.displayTitle)")
            }

            // Fetch highlights for this book
            let highlights: [Highlight]
            do {
                highlights = try await pocketBookClient.getHighlights(forBook: bookItem)
            } catch {
                let msg = "Failed to fetch highlights for '\(bookItem.displayTitle)': \(error)"
                errors.append(msg)
                if verbose { print("  ⚠️ \(msg)") }
                continue
            }

            // Skip books without highlights
            guard !highlights.isEmpty else {
                if verbose { print("  Skipping - no highlights") }
                continue
            }

            // Merge split highlights
            let mergeResult = merger.mergeWithStats(highlights)
            if verbose && mergeResult.hadMerges {
                print("  Merged \(mergeResult.reductionCount) split highlights")
            }

            // Filter to unsynced highlights (unless force)
            let highlightsToSync: [Highlight]
            if force {
                highlightsToSync = mergeResult.highlights
            } else {
                highlightsToSync = syncStateStore.filterUnsyncedHighlights(mergeResult.highlights, forBook: bookItem.id)
            }

            // Skip if no new highlights
            if highlightsToSync.isEmpty {
                if verbose { print("  Skipping - all highlights already synced") }
                skippedHighlights += mergeResult.highlights.count
                continue
            }

            // Format for Capacities
            let bookMarkdown = formatter.formatBook(bookItem, highlights: mergeResult.highlights)

            if dryRun {
                print("\n\(formatter.formatSummary(book: bookItem, highlights: highlightsToSync))")
                totalBooks += 1
                totalHighlights += highlightsToSync.count
            } else {
                // Sync to Capacities
                do {
                    let bookUrl = MarkdownFormatter.bookURL(for: bookItem)

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
                        try syncStateStore.markSynced(highlightId: highlight.id, forBook: bookItem.id)
                    }
                    try syncStateStore.markBookSynced(
                        bookId: bookItem.id,
                        capacitiesId: response.id,
                        highlightCount: mergeResult.highlights.count
                    )

                    print("✓ \(bookItem.displayTitle) - \(highlightsToSync.count) new highlight(s)")
                    totalBooks += 1
                    totalHighlights += highlightsToSync.count

                } catch {
                    let msg = "Failed to sync '\(bookItem.displayTitle)': \(error)"
                    errors.append(msg)
                    print("✗ \(bookItem.displayTitle) - \(error)")
                }
            }
        }

        // Summary
        print("\n────────────────────────────")

        if dryRun {
            print("Dry run complete. Would sync \(totalHighlights) highlight(s) from \(totalBooks) book(s).")
        } else {
            print("Sync complete!")
            print("  Books synced: \(totalBooks)")
            print("  Highlights synced: \(totalHighlights)")
            if skippedHighlights > 0 {
                print("  Highlights skipped (already synced): \(skippedHighlights)")
            }

            // Update sync timestamp
            try syncStateStore.markSyncComplete()
        }

        if !errors.isEmpty {
            print("\nErrors encountered:")
            for error in errors {
                print("  • \(error)")
            }
        }
    }
}

enum SyncCommandError: Error, CustomStringConvertible {
    case notConfigured(String)

    var description: String {
        switch self {
        case .notConfigured(let message):
            return message
        }
    }
}
