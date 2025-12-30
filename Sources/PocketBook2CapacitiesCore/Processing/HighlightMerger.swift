import Foundation

/// Merges split multi-page highlights back together
public struct HighlightMerger {
    /// Configuration for merge detection
    public struct Config {
        /// Maximum CFI distance to consider as adjacent
        let cfiThreshold: Double

        /// Maximum time difference between creations (seconds)
        let timeThreshold: TimeInterval

        public static let `default` = Config(
            cfiThreshold: 100.0,
            timeThreshold: 60.0
        )
    }

    public let config: Config

    public init(config: Config = .default) {
        self.config = config
    }

    /// Merge consecutive highlights that appear to be split across pages
    public func merge(_ highlights: [Highlight]) -> [Highlight] {
        guard highlights.count > 1 else { return highlights }

        // First sort by position
        let sorted = HighlightSorter.sort(highlights)

        // Group by color and process each group
        let colorGroups = HighlightGrouper.groupByColor(sorted)

        var allMerged: [Highlight] = []

        for (_, colorHighlights) in colorGroups {
            let merged = mergeColorGroup(colorHighlights)
            allMerged.append(contentsOf: merged)
        }

        // Re-sort the merged results
        return HighlightSorter.sort(allMerged)
    }

    /// Merge highlights within a single color group
    private func mergeColorGroup(_ highlights: [Highlight]) -> [Highlight] {
        guard highlights.count > 1 else { return highlights }

        var result: [Highlight] = []
        var current = highlights[0]

        for i in 1..<highlights.count {
            let next = highlights[i]

            if shouldMerge(current, with: next) {
                current = mergeHighlights(current, next)
            } else {
                result.append(current)
                current = next
            }
        }

        result.append(current)
        return result
    }

    /// Determine if two highlights should be merged
    func shouldMerge(_ first: Highlight, with second: Highlight) -> Bool {
        // Must have same color
        guard first.color.value == second.color.value else {
            return false
        }

        // Check CFI adjacency
        if !checkCFIAdjacency(first, second) {
            return false
        }

        // Check text continuity
        if !checkTextContinuity(first, second) {
            return false
        }

        // Check time proximity (if timestamps available)
        if !checkTimeProximity(first, second) {
            return false
        }

        return true
    }

    /// Check if CFI positions indicate adjacency
    private func checkCFIAdjacency(_ first: Highlight, _ second: Highlight) -> Bool {
        guard let firstEnd = first.endPosition,
              let secondBegin = second.beginPosition else {
            // If we can't parse CFI, check if they might still be adjacent
            // by looking at timestamp proximity
            return true
        }

        return CFIParser.areAdjacent(firstEnd, secondBegin, threshold: config.cfiThreshold)
    }

    /// Check if text indicates the highlights are a continuous passage
    private func checkTextContinuity(_ first: Highlight, _ second: Highlight) -> Bool {
        // First should not end with sentence terminator
        // Second should start with lowercase or continuation

        // If first ends with sentence terminator, they're probably separate
        if first.endsWithSentenceTerminator {
            return false
        }

        // If second starts with capital (and first doesn't end with punctuation),
        // it might still be a continuation (e.g., proper noun)
        // We're lenient here - if first doesn't end properly, assume continuation

        return true
    }

    /// Check if timestamps indicate proximity (created around same time)
    private func checkTimeProximity(_ first: Highlight, _ second: Highlight) -> Bool {
        guard let firstTime = first.createdTimestamp,
              let secondTime = second.createdTimestamp else {
            // If no timestamps, assume they could be adjacent
            return true
        }

        let timeDiff = abs(secondTime.timeIntervalSince(firstTime))
        return timeDiff <= config.timeThreshold
    }

    /// Merge two highlights into one
    private func mergeHighlights(_ first: Highlight, _ second: Highlight) -> Highlight {
        // Combine text with a space
        let combinedText = [first.text, second.text]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .joined(separator: " ")

        // Combine notes if both have them
        let combinedNote: String?
        switch (first.note, second.note) {
        case (nil, nil):
            combinedNote = nil
        case (let note, nil):
            combinedNote = note
        case (nil, let note):
            combinedNote = note
        case (let note1?, let note2?):
            combinedNote = "\(note1)\n\(note2)"
        }

        // Use first's begin and second's end
        let mergedQuotation = Quotation(
            begin: first.quotation.begin,
            end: second.quotation.end,
            text: combinedText,
            updated: second.quotation.updated ?? first.quotation.updated
        )

        // Create merged highlight using first's ID (for tracking)
        // Include second's ID in a composite ID
        let mergedId = "\(first.id)+\(second.id)"

        return Highlight(
            id: mergedId,
            uuid: first.uuid,
            bookId: first.bookId,
            bookFastHash: first.bookFastHash,
            color: first.color,
            note: combinedNote,
            text: combinedText,
            quotation: mergedQuotation,
            mark: first.mark
        )
    }
}

// MARK: - Statistics

public extension HighlightMerger {
    /// Result of a merge operation with statistics
    struct MergeResult {
        public let highlights: [Highlight]
        public let originalCount: Int
        public let mergedCount: Int

        public var reductionCount: Int {
            originalCount - mergedCount
        }

        public var hadMerges: Bool {
            reductionCount > 0
        }
    }

    /// Merge highlights and return statistics
    func mergeWithStats(_ highlights: [Highlight]) -> MergeResult {
        let merged = merge(highlights)
        return MergeResult(
            highlights: merged,
            originalCount: highlights.count,
            mergedCount: merged.count
        )
    }
}
