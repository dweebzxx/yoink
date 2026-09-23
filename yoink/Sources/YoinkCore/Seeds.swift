import CoreGraphics
import Foundation

/// First-launch seed data (MVP "Initial Editable Snippets"). Plain editable data only:
/// nothing in the app depends on these labels or texts.
public enum SeedData {
    public static let snippets: [(label: String, text: String)] = [
        ("S", "cd /Volumes/etcetera/etceteraOS/ai-projects/code-playground/spicedanime-webapp"),
        ("O", "cd /Volumes/etcetera/etceteraOS/ai-projects/code-playground/spicedanime-webapp/spicy-project-manager/outputs"),
        ("C", "codex --yolo"),
        ("CL", "claude --dangerously-skip-permissions"),
        ("A", "cd /Volumes/etcetera/etceteraOS/ai-projects/code-playground-beta/spicedanime-webapp-docs\nagy --dangerously-skip-permissions"),
    ]

    public static let margin: Double = 24
    public static let spacing: Double = 12

    /// Seed squares stacked in a column near the top-right of the main display, with the
    /// default preferences and their texts already in History (Decision #43).
    public static func document(main: DisplayGeometry, now: Date = Date()) -> ConfigDocument {
        let prefs = Preferences()
        let size = prefs.squareSize
        var squares: [Square] = []
        for (index, seed) in snippets.enumerated() {
            let origin = CGPoint(
                x: main.usable.maxX - size - margin,
                y: main.usable.minY + margin + Double(index) * (size + spacing)
            )
            let placement = PlacementResolver.placementForDrop(origin: origin, squareSize: size, on: main)
            squares.append(Square(label: seed.label, text: seed.text, placement: placement))
        }
        var history = SnippetHistory(entries: [])
        for square in squares { history.record(text: square.text, label: square.label, at: now) }
        return ConfigDocument(preferences: prefs, squares: squares, history: history.entries)
    }
}

/// Snippet history rules (Decision #43): identical text is stored once, its label and date
/// are refreshed, newest first. Only the user's Remove and Clear actions delete entries.
public struct SnippetHistory: Equatable, Sendable {
    public private(set) var entries: [HistoryEntry]

    public init(entries: [HistoryEntry]) {
        self.entries = entries
    }

    public mutating func record(text: String, label: String, at time: Date) {
        // Whole seconds, so the date survives the ISO-8601 file format unchanged.
        let date = Date(timeIntervalSince1970: time.timeIntervalSince1970.rounded(.down))
        if let index = entries.firstIndex(where: { $0.text == text }) {
            var entry = entries.remove(at: index)
            entry.label = label
            entry.lastUsed = date
            entries.insert(entry, at: 0)
        } else {
            entries.insert(HistoryEntry(text: text, label: label, lastUsed: date), at: 0)
        }
    }

    public mutating func remove(id: UUID) {
        entries.removeAll { $0.id == id }
    }

    public mutating func clear() {
        entries.removeAll()
    }
}
