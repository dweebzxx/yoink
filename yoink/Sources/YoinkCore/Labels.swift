import Foundation

/// Label rules (Decision #27): one or two user-perceived characters (extended grapheme
/// clusters), not empty, not only spaces. Duplicates are allowed. A label never implies behavior.
public enum LabelError: Error, Equatable, Sendable {
    case empty
    case onlySpaces
    case tooLong

    public var message: String {
        switch self {
        case .empty: "Enter a label of one or two characters."
        case .onlySpaces: "A label can't be only spaces."
        case .tooLong: "A label can have at most two characters."
        }
    }
}

public enum LabelRules {
    public static func validate(_ label: String) -> LabelError? {
        if label.isEmpty { return .empty }
        if label.allSatisfy({ $0.isWhitespace }) { return .onlySpaces }
        if label.count > 2 { return .tooLong }
        return nil
    }

    public static func isValid(_ label: String) -> Bool { validate(label) == nil }
}

/// Settings search (Decision #42): case- and diacritic-insensitive match on label or text.
public enum SquareSearch {
    public static func filter(_ squares: [Square], query: String) -> [Square] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return squares }
        return squares.filter { matches($0, query: trimmed) }
    }

    public static func matches(_ square: Square, query: String) -> Bool {
        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        return square.label.range(of: query, options: options) != nil
            || square.text.range(of: query, options: options) != nil
    }
}

/// Builds the hover-preview text (Decision #31). Lines wrap so no line is wider than
/// `maxWidth` (measured per character by `width`, so wide characters and emoji count fully);
/// line breaks in the snippet are kept. Tabs are shown as four spaces. When the wrapped text
/// has more than `maxLines` lines, the last visible line becomes "… N more lines".
public struct PreviewLayout: Equatable, Sendable {
    public var lines: [String]
    public var hiddenLineCount: Int

    public var displayText: String { lines.joined(separator: "\n") }

    public static func make(text: String, columns: Int, maxLines: Int) -> PreviewLayout {
        make(text: text, maxWidth: Double(max(1, columns)), maxLines: maxLines, width: { _ in 1 })
    }

    public static func make(text: String, maxWidth: Double, maxLines: Int, width: (Character) -> Double) -> PreviewLayout {
        let wrapped = wrap(text, maxWidth: maxWidth, width: width)
        let limit = max(1, maxLines)
        guard wrapped.count > limit else { return PreviewLayout(lines: wrapped, hiddenLineCount: 0) }
        let shown = Array(wrapped.prefix(limit - 1))
        let hidden = wrapped.count - shown.count
        return PreviewLayout(lines: shown + ["… \(hidden) more \(hidden == 1 ? "line" : "lines")"], hiddenLineCount: hidden)
    }

    /// Splits on every newline (including CRLF, which Swift treats as one character) and
    /// hard-wraps each source line. Empty lines are kept as empty lines.
    public static func wrap(_ text: String, columns: Int) -> [String] {
        wrap(text, maxWidth: Double(max(1, columns)), width: { _ in 1 })
    }

    public static func wrap(_ text: String, maxWidth: Double, width: (Character) -> Double) -> [String] {
        var result: [String] = []
        for line in text.split(omittingEmptySubsequences: false, whereSeparator: { $0.isNewline }) {
            var current = ""
            var used = 0.0
            for ch in line.replacingOccurrences(of: "\t", with: "    ") {
                let w = width(ch)
                if !current.isEmpty && used + w > maxWidth {
                    result.append(current)
                    current = ""
                    used = 0
                }
                current.append(ch)
                used += w
            }
            result.append(current)
        }
        return result
    }
}
