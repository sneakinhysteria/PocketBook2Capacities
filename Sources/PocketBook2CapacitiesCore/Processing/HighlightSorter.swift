import Foundation

/// Sorts highlights by their position in the book
public struct HighlightSorter {
    /// Sort highlights by position in book, using multiple fallback strategies
    /// Priority: CFI position → anchor → timestamp
    static func sort(_ highlights: [Highlight]) -> [Highlight] {
        return highlights.sorted { a, b in
            compareHighlights(a, b)
        }
    }

    /// Compare two highlights for sorting
    /// Returns true if `a` should come before `b`
    static func compareHighlights(_ a: Highlight, _ b: Highlight) -> Bool {
        // Strategy 1: Compare by CFI position (most accurate)
        if let aPos = a.beginPosition, let bPos = b.beginPosition {
            if aPos != bPos {
                return aPos < bPos
            }
        }

        // Strategy 2: Compare by anchor if available
        if let aAnchor = a.mark?.anchor, let bAnchor = b.mark?.anchor {
            // Try to extract numeric position from anchor
            if let aNum = extractNumber(from: aAnchor),
               let bNum = extractNumber(from: bAnchor) {
                if aNum != bNum {
                    return aNum < bNum
                }
            }
        }

        // Strategy 3: Compare by creation timestamp
        if let aCreated = a.mark?.created, let bCreated = b.mark?.created {
            return aCreated < bCreated
        }

        // Strategy 4: Compare by update timestamp
        if let aUpdated = a.quotation.updated, let bUpdated = b.quotation.updated {
            return aUpdated < bUpdated
        }

        // Fallback: Compare by UUID for stable sorting
        return a.uuid < b.uuid
    }

    /// Extract the first number found in a string
    private static func extractNumber(from string: String) -> Int? {
        let numbers = string.components(separatedBy: CharacterSet.decimalDigits.inverted)
            .joined()
        return Int(numbers)
    }
}

/// Group highlights by book for processing
struct HighlightGrouper {
    /// Group highlights by their book ID
    static func groupByBook(_ highlights: [Highlight]) -> [String: [Highlight]] {
        var groups: [String: [Highlight]] = [:]

        for highlight in highlights {
            if groups[highlight.bookId] == nil {
                groups[highlight.bookId] = []
            }
            groups[highlight.bookId]!.append(highlight)
        }

        // Sort highlights within each group
        for (bookId, bookHighlights) in groups {
            groups[bookId] = HighlightSorter.sort(bookHighlights)
        }

        return groups
    }

    /// Group highlights by color (for merging candidates)
    static func groupByColor(_ highlights: [Highlight]) -> [String: [Highlight]] {
        var groups: [String: [Highlight]] = [:]

        for highlight in highlights {
            let color = highlight.color.value
            if groups[color] == nil {
                groups[color] = []
            }
            groups[color]!.append(highlight)
        }

        return groups
    }
}
