import Foundation

/// Formats books and highlights as markdown for Capacities
public struct MarkdownFormatter {
    public init() {}

    /// Format all highlights for a book as markdown
    public func formatBook(_ book: Book, highlights: [Highlight]) -> BookMarkdown {
        let sortedHighlights = HighlightSorter.sort(highlights)

        var lines: [String] = []

        // Header with book metadata
        lines.append("## Book Highlights")
        lines.append("")

        // Author if known
        if book.displayAuthors != "Unknown Author" {
            lines.append("**Author**: \(book.displayAuthors)")
            lines.append("")
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        lines.append("**Synced**: \(dateFormatter.string(from: Date()))")

        lines.append("")
        lines.append("---")
        lines.append("")

        // Format each highlight
        for (index, highlight) in sortedHighlights.enumerated() {
            let formattedHighlight = formatHighlight(highlight, number: index + 1)
            lines.append(formattedHighlight)
            lines.append("")
            lines.append("---")
            lines.append("")
        }

        let markdown = lines.joined(separator: "\n")

        // Create description for the weblink (extracted from path if available)
        let description: String? = book.path.map { path in
            // Extract author from path like "/Author - Title.epub"
            let filename = (path as NSString).lastPathComponent
            if filename.contains(" - ") {
                return String(filename.split(separator: "-").first ?? "").trimmingCharacters(in: .whitespaces)
            }
            return nil
        } ?? nil

        // Tags
        var tags = ["pocketbook-import"]
        if let collections = book.collections, !collections.isEmpty {
            // Add collections as tags (split by comma if multiple)
            let collectionTags = collections.split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
                .filter { !$0.isEmpty }
            tags.append(contentsOf: collectionTags.prefix(29)) // Leave room for the import tag
        }

        return BookMarkdown(
            title: book.displayTitle,
            description: description,
            markdown: markdown,
            tags: tags,
            highlightCount: sortedHighlights.count
        )
    }

    /// Format a single highlight
    func formatHighlight(_ highlight: Highlight, number: Int) -> String {
        var lines: [String] = []

        // Highlight header with color and page number if available
        let colorEmoji = colorToEmoji(highlight.color.value)
        var header = "### \(colorEmoji) Highlight \(number)"
        if let page = highlight.mark?.page {
            header += " (p. \(page))"
        }
        lines.append(header)
        lines.append("")

        // Quote the text
        let quotedText = highlight.text
            .split(separator: "\n")
            .map { "> \($0)" }
            .joined(separator: "\n")
        lines.append(quotedText)

        // Add note if present
        if highlight.hasNote {
            lines.append("")
            lines.append("*Note: \(highlight.note!)*")
        }

        return lines.joined(separator: "\n")
    }

    /// Convert highlight color to emoji
    private func colorToEmoji(_ color: String) -> String {
        switch color.lowercased() {
        case "yellow":
            return "🟡"
        case "red":
            return "🔴"
        case "green":
            return "🟢"
        case "blue":
            return "🔵"
        case "purple":
            return "🟣"
        case "orange":
            return "🟠"
        default:
            return "📝"
        }
    }
}

/// Result of formatting a book
public struct BookMarkdown {
    public let title: String
    public let description: String?
    public let markdown: String
    public let tags: [String]
    public let highlightCount: Int
}

// MARK: - URL Generation

public extension MarkdownFormatter {
    /// Generate a URL for a PocketBook book
    /// Uses the cloud link if available, otherwise a constructed identifier URL
    static func bookURL(for book: Book) -> String {
        // Use the PocketBook Cloud link if available
        if let link = book.link, !link.isEmpty {
            return link
        }
        // Fallback to a constructed URL using the book's fast_hash as identifier
        return "https://cloud.pocketbook.digital/library#book-\(book.fastHash)"
    }

    /// Generate a URL for a specific highlight
    static func highlightURL(for highlight: Highlight) -> String {
        return "https://cloud.pocketbook.digital/library#highlight-\(highlight.uuid)"
    }
}

// MARK: - Preview/Dry Run Output

public extension MarkdownFormatter {
    /// Format a summary for dry-run output
    func formatSummary(book: Book, highlights: [Highlight]) -> String {
        var lines: [String] = []

        lines.append("📖 \(book.displayTitle)")
        lines.append("   Author: \(book.displayAuthors)")
        lines.append("   Highlights: \(highlights.count)")

        if highlights.count > 0 {
            lines.append("   Preview:")
            for (index, highlight) in highlights.prefix(3).enumerated() {
                let preview = String(highlight.text.prefix(50))
                let suffix = highlight.text.count > 50 ? "..." : ""
                let pageInfo = highlight.mark?.page.map { " (p. \($0))" } ?? ""
                lines.append("     \(index + 1).\(pageInfo) \"\(preview)\(suffix)\"")
            }
            if highlights.count > 3 {
                lines.append("     ... and \(highlights.count - 3) more")
            }
        }

        return lines.joined(separator: "\n")
    }
}
