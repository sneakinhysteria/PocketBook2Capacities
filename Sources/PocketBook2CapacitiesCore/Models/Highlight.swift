import Foundation

/// Represents a highlight/annotation from PocketBook Cloud
public struct Highlight: Codable, Identifiable {
    public let id: String
    public let uuid: String
    public let bookId: String
    public let bookFastHash: String
    public let color: HighlightColor
    public let note: String?
    public let text: String
    public let quotation: Quotation
    public let mark: Mark?

    enum CodingKeys: String, CodingKey {
        case id
        case uuid
        case bookId = "book_id"
        case bookFastHash = "book_fast_hash"
        case color
        case note
        case text
        case quotation
        case mark
    }
}

public struct HighlightColor: Codable {
    public let value: String

    public init(value: String = "unknown") {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.value = try container.decodeIfPresent(String.self, forKey: .value) ?? "unknown"
    }

    enum CodingKeys: String, CodingKey {
        case value
    }
}

public struct Quotation: Codable {
    public let begin: String
    public let end: String
    public let text: String
    public let updated: Date?

    enum CodingKeys: String, CodingKey {
        case begin
        case end
        case text
        case updated
    }
}

public struct Mark: Codable {
    public let anchor: String?
    public let created: Date?
    public let updated: Date?

    /// Extract page number from anchor URL (e.g., "pbr:/page?page=36&offs=...")
    public var page: Int? {
        guard let anchor = anchor else { return nil }
        // Look for page= parameter in the anchor URL
        if let range = anchor.range(of: "page=") {
            let startIndex = range.upperBound
            var endIndex = startIndex
            while endIndex < anchor.endIndex && anchor[endIndex].isNumber {
                endIndex = anchor.index(after: endIndex)
            }
            if startIndex < endIndex {
                return Int(anchor[startIndex..<endIndex])
            }
        }
        return nil
    }
}

/// Raw API response structures
struct PocketBookNoteResponse: Codable {
    let uuid: String
    let color: PocketBookColorType?
    let type: PocketBookTypeValue?
    let note: PocketBookNoteContent?
    let quotation: PocketBookQuotationType?
    let mark: PocketBookMarkType?
}

struct PocketBookTypeValue: Codable {
    let value: String?
}

struct PocketBookColorType: Codable {
    let value: String?
}

struct PocketBookNoteContent: Codable {
    let text: String?
}

struct PocketBookQuotationType: Codable {
    let begin: String?
    let end: String?
    let text: String?
    let updated: String?
}

struct PocketBookMarkType: Codable {
    let anchor: String?
    let created: FlexibleTimestamp?
    let updated: FlexibleTimestamp?
}

/// Handles timestamps that can be either strings or numbers
struct FlexibleTimestamp: Codable {
    let value: Date?

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        // Try number first (Unix timestamp)
        if let timestamp = try? container.decode(Double.self) {
            self.value = Date(timeIntervalSince1970: timestamp)
        }
        // Try string (ISO8601)
        else if let string = try? container.decode(String.self) {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            self.value = formatter.date(from: string)
        }
        else {
            self.value = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let date = value {
            try container.encode(date.timeIntervalSince1970)
        } else {
            try container.encodeNil()
        }
    }
}

/// Extension to convert API response to our model
extension PocketBookNoteResponse {
    /// Known bookmark/annotation marker texts that should be filtered out
    private static let bookmarkMarkers: Set<String> = [
        "bookmark", "bookmarks",
        "pencil",
        "note", "notes",
        "marker"
    ]

    /// Check if text is just a bookmark marker (not actual highlighted content)
    private func isBookmarkMarker(_ text: String) -> Bool {
        let normalized = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        // Check for exact matches
        if Self.bookmarkMarkers.contains(normalized) {
            return true
        }
        // Check for repeated markers like "Bookmark Bookmark Bookmark"
        let words = Set(normalized.split(separator: " ").map { String($0) })
        if words.count == 1, let word = words.first, Self.bookmarkMarkers.contains(word) {
            return true
        }
        return false
    }

    func toHighlight(bookId: String, bookFastHash: String) -> Highlight? {
        guard let quotation = quotation,
              let text = quotation.text,
              !text.isEmpty else {
            return nil
        }

        // Filter out bookmark markers - these aren't actual text highlights
        if isBookmarkMarker(text) {
            return nil
        }

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let quotationUpdated = quotation.updated.flatMap { dateFormatter.date(from: $0) }
        let markCreated = mark?.created?.value
        let markUpdated = mark?.updated?.value

        return Highlight(
            id: uuid,
            uuid: uuid,
            bookId: bookId,
            bookFastHash: bookFastHash,
            color: HighlightColor(value: color?.value ?? "unknown"),
            note: note?.text,
            text: text,
            quotation: Quotation(
                begin: quotation.begin ?? "",
                end: quotation.end ?? "",
                text: text,
                updated: quotationUpdated
            ),
            mark: Mark(
                anchor: mark?.anchor,
                created: markCreated,
                updated: markUpdated
            )
        )
    }
}

/// Extension for sorting and merging helpers
extension Highlight {
    var hasNote: Bool {
        guard let note = note else { return false }
        return !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var endsWithSentenceTerminator: Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let lastChar = trimmed.last else { return false }
        return ".!?\"'".contains(lastChar)
    }

    var startsWithLowercase: Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let firstChar = trimmed.first else { return false }
        return firstChar.isLowercase
    }

    var createdTimestamp: Date? {
        mark?.created
    }
}
