import Foundation

/// Represents a parsed EPUB Canonical Fragment Identifier (CFI) position
/// Format example: epubcfi(/6/14!/4/2[chapter1]/1:42)
/// Components:
/// - /6/14 - spine position (which document in the EPUB)
/// - !/4/2[chapter1]/1 - DOM path within the document
/// - :42 - character offset within the text node
struct CFIPosition: Comparable, CustomStringConvertible {
    let spineComponents: [CFIComponent]
    let documentPath: [CFIComponent]
    let characterOffset: Int?
    let rawCFI: String

    var description: String {
        let spine = spineComponents.map { $0.description }.joined()
        let path = documentPath.map { $0.description }.joined()
        let offset = characterOffset.map { ":\($0)" } ?? ""
        return "CFI(spine: \(spine), path: \(path)\(offset))"
    }

    static func < (lhs: CFIPosition, rhs: CFIPosition) -> Bool {
        // First compare spine (document position in EPUB)
        for (l, r) in zip(lhs.spineComponents, rhs.spineComponents) {
            if l.index != r.index {
                return l.index < r.index
            }
        }

        // If one has more spine components, the shorter one comes first
        if lhs.spineComponents.count != rhs.spineComponents.count {
            return lhs.spineComponents.count < rhs.spineComponents.count
        }

        // Then compare document path
        for (l, r) in zip(lhs.documentPath, rhs.documentPath) {
            if l.index != r.index {
                return l.index < r.index
            }
        }

        // If one has more path components, the shorter one comes first
        if lhs.documentPath.count != rhs.documentPath.count {
            return lhs.documentPath.count < rhs.documentPath.count
        }

        // Finally compare character offset
        let lOffset = lhs.characterOffset ?? 0
        let rOffset = rhs.characterOffset ?? 0
        return lOffset < rOffset
    }

    static func == (lhs: CFIPosition, rhs: CFIPosition) -> Bool {
        return lhs.spineComponents == rhs.spineComponents &&
               lhs.documentPath == rhs.documentPath &&
               lhs.characterOffset == rhs.characterOffset
    }
}

/// A single component in a CFI path (e.g., /6 or /4[chapter1])
struct CFIComponent: Equatable, CustomStringConvertible {
    let index: Int
    let id: String?

    var description: String {
        if let id = id {
            return "/\(index)[\(id)]"
        }
        return "/\(index)"
    }
}

/// Parser for EPUB CFI strings
struct CFIParser {
    /// Parse a CFI string into a position object
    /// - Parameter cfi: The CFI string to parse (e.g., "epubcfi(/6/14!/4/2/1:0)")
    /// - Returns: A parsed CFIPosition, or nil if parsing fails
    static func parse(_ cfi: String) -> CFIPosition? {
        var cfiContent = cfi

        // Extract the CFI content from epubcfi() wrapper if present
        if let range = cfi.range(of: "epubcfi("),
           let endRange = cfi.range(of: ")", options: .backwards) {
            cfiContent = String(cfi[range.upperBound..<endRange.lowerBound])
        }

        // Split on ! which separates spine from document path
        let parts = cfiContent.split(separator: "!", maxSplits: 1, omittingEmptySubsequences: false)

        guard !parts.isEmpty else { return nil }

        let spineString = String(parts[0])
        let documentString = parts.count > 1 ? String(parts[1]) : nil

        // Parse spine components
        let spineComponents = parseComponents(spineString)
        guard !spineComponents.isEmpty else { return nil }

        // Parse document path and character offset
        var documentPath: [CFIComponent] = []
        var characterOffset: Int? = nil

        if var docString = documentString {
            // Extract character offset if present
            if let colonIndex = docString.lastIndex(of: ":") {
                let offsetString = String(docString[docString.index(after: colonIndex)...])
                // Remove any trailing characters like )
                let cleanOffset = offsetString.filter { $0.isNumber }
                characterOffset = Int(cleanOffset)
                docString = String(docString[..<colonIndex])
            }

            documentPath = parseComponents(docString)
        }

        return CFIPosition(
            spineComponents: spineComponents,
            documentPath: documentPath,
            characterOffset: characterOffset,
            rawCFI: cfi
        )
    }

    /// Parse path components from a CFI path string
    private static func parseComponents(_ path: String) -> [CFIComponent] {
        var components: [CFIComponent] = []
        var remaining = path

        while !remaining.isEmpty {
            // Find next /
            guard let slashIndex = remaining.firstIndex(of: "/") else {
                break
            }

            remaining = String(remaining[remaining.index(after: slashIndex)...])

            // Find the number
            var numberString = ""
            var index = remaining.startIndex

            while index < remaining.endIndex && remaining[index].isNumber {
                numberString.append(remaining[index])
                index = remaining.index(after: index)
            }

            guard let number = Int(numberString) else { continue }

            // Check for ID in brackets
            var componentId: String? = nil
            if index < remaining.endIndex && remaining[index] == "[" {
                if let closeBracket = remaining[index...].firstIndex(of: "]") {
                    componentId = String(remaining[remaining.index(after: index)..<closeBracket])
                    index = remaining.index(after: closeBracket)
                }
            }

            components.append(CFIComponent(index: number, id: componentId))
            remaining = String(remaining[index...])
        }

        return components
    }

    /// Calculate a numeric distance between two CFI positions
    /// Returns a value that can be used to determine if positions are adjacent
    static func distance(from start: CFIPosition, to end: CFIPosition) -> Double {
        // Compare spine first
        for (i, (s, e)) in zip(start.spineComponents, end.spineComponents).enumerated() {
            if s.index != e.index {
                // Different spine position means large distance
                return Double(e.index - s.index) * 1_000_000.0 + Double(i)
            }
        }

        // Compare document path
        for (i, (s, e)) in zip(start.documentPath, end.documentPath).enumerated() {
            if s.index != e.index {
                // Different path position
                return Double(e.index - s.index) * 1000.0 + Double(i)
            }
        }

        // Same path, compare character offsets
        let startOffset = start.characterOffset ?? 0
        let endOffset = end.characterOffset ?? 0

        return Double(endOffset - startOffset)
    }

    /// Check if two CFI positions are adjacent (close enough to be part of the same highlight)
    static func areAdjacent(_ first: CFIPosition, _ second: CFIPosition, threshold: Double = 10.0) -> Bool {
        let dist = distance(from: first, to: second)
        return abs(dist) <= threshold
    }
}

// MARK: - Highlight Extension

extension Highlight {
    /// Parse the begin CFI position
    var beginPosition: CFIPosition? {
        CFIParser.parse(quotation.begin)
    }

    /// Parse the end CFI position
    var endPosition: CFIPosition? {
        CFIParser.parse(quotation.end)
    }

    /// Check if this highlight's end is adjacent to another's begin
    func isAdjacentTo(_ other: Highlight, threshold: Double = 50.0) -> Bool {
        guard let myEnd = endPosition,
              let otherBegin = other.beginPosition else {
            return false
        }

        return CFIParser.areAdjacent(myEnd, otherBegin, threshold: threshold)
    }
}
