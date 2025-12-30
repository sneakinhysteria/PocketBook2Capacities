import Foundation

/// Represents a book from PocketBook Cloud
public struct Book: Codable, Identifiable {
    public let id: String
    public let path: String?
    public let title: String
    public let mimeType: String?
    public let createdAt: String?
    public let purchased: Bool?
    public let resourceId: String?
    public let bytes: Int?
    public let clientMtime: String?
    public let collections: String?
    public let fastHash: String
    public let favorite: Bool?
    public let readStatus: String?
    public let link: String?

    enum CodingKeys: String, CodingKey {
        case id
        case path
        case title
        case mimeType = "mime_type"
        case createdAt = "created_at"
        case purchased
        case resourceId = "resource_id"
        case bytes
        case clientMtime = "client_mtime"
        case collections
        case fastHash = "fast_hash"
        case favorite
        case readStatus = "read_status"
        case link
    }

    // Use id as uuid for compatibility
    public var uuid: String { id }
}

/// Extension for display formatting
public extension Book {
    var displayTitle: String {
        title.isEmpty ? "Untitled" : title
    }

    var displayAuthors: String {
        // Try to extract author from path
        if let author = extractAuthorFromPath() {
            return author
        }
        return "Unknown Author"
    }

    var displayYear: String? {
        nil
    }

    var isEpub: Bool {
        mimeType == "application/epub+zip"
    }

    /// Extract author from file path using common naming patterns
    private func extractAuthorFromPath() -> String? {
        guard let path = path else { return nil }

        // Get filename without extension
        let filename = (path as NSString).lastPathComponent
        let nameWithoutExt = (filename as NSString).deletingPathExtension

        // Pattern 1: "Title by Author" - most reliable
        if let byRange = nameWithoutExt.range(of: " by ", options: .caseInsensitive) {
            let author = String(nameWithoutExt[byRange.upperBound...])
                .trimmingCharacters(in: .whitespaces)
            if !author.isEmpty && !looksLikeTitle(author) {
                return author
            }
        }

        // Pattern 2: "Author - Title" or "Author _ Title" (author names are typically short, 2-4 words)
        let separators = [" - ", " _ ", " – ", " — "]  // dash, underscore, en-dash, em-dash
        for separator in separators {
            if let sepRange = nameWithoutExt.range(of: separator) {
                let potentialAuthor = String(nameWithoutExt[..<sepRange.lowerBound])
                    .trimmingCharacters(in: .whitespaces)
                let wordCount = potentialAuthor.split(separator: " ").count
                // Author names typically have 2-4 words (first last, or first middle last)
                // Single word is rarely an author name, more likely a title word
                if !potentialAuthor.isEmpty && wordCount >= 2 && wordCount <= 4
                    && potentialAuthor.count < 40 && !looksLikeTitle(potentialAuthor) {
                    return potentialAuthor
                }
            }
        }

        // Pattern 3: "Title (Author)"
        if let openParen = nameWithoutExt.lastIndex(of: "("),
           let closeParen = nameWithoutExt.lastIndex(of: ")"),
           openParen < closeParen {
            let startIndex = nameWithoutExt.index(after: openParen)
            let author = String(nameWithoutExt[startIndex..<closeParen])
                .trimmingCharacters(in: .whitespaces)
            if !author.isEmpty && !looksLikeTitle(author) {
                return author
            }
        }

        return nil
    }

    /// Check if text looks like a book title rather than an author name
    private func looksLikeTitle(_ text: String) -> Bool {
        // Normalize: lowercase and replace underscores/special chars with spaces
        let normalized = text.lowercased()
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespaces)
        let titleLower = title.lowercased()

        // If it matches or is contained in the book title, it's probably not the author
        if titleLower.contains(normalized) || normalized.contains(titleLower) {
            return true
        }

        // Check word overlap - if most words appear in title, it's probably a title fragment
        let textWords = Set(normalized.split(separator: " ").map { String($0) })
        let titleWords = Set(titleLower.split(separator: " ").map { String($0) })
        let overlap = textWords.intersection(titleWords)
        if textWords.count > 0 && Double(overlap.count) / Double(textWords.count) >= 0.5 {
            return true
        }

        // Common title words that aren't author names
        let commonTitleWords = ["the", "a", "an", "of", "and", "in", "to", "for", "with", "on"]
        if let first = textWords.first, commonTitleWords.contains(first) {
            return true
        }
        return false
    }
}
