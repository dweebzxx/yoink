import Foundation

/// Visual feedback shown after a successful copy (Decisions #11, #33).
public enum FeedbackMode: String, Codable, CaseIterable, Sendable {
    case checkmark
    case burst
    case none
}

/// A global key combination. `keyCode` is a macOS virtual key code and `modifiers`
/// uses the Carbon modifier mask, so the App can hand it straight to `RegisterEventHotKey`.
public struct KeyShortcut: Codable, Hashable, Sendable {
    public var keyCode: UInt32
    public var modifiers: UInt32

    public init(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    // Carbon modifier bits (HIToolbox/Events.h), repeated here so Core stays free of Carbon.
    public static let command: UInt32 = 0x0100
    public static let shift: UInt32 = 0x0200
    public static let option: UInt32 = 0x0800
    public static let control: UInt32 = 0x1000

    /// ⌃⌥H, the preset Hide/Show All shortcut (Decision #38).
    public static let defaultHideShowAll = KeyShortcut(keyCode: 0x04, modifiers: control | option)
    /// ⌃⌥G, the preset Snap to Grid shortcut (Decision #40).
    public static let defaultSnapToGrid = KeyShortcut(keyCode: 0x05, modifiers: control | option)
}

/// Where a square lives: the display it belongs to and the square's top-left corner,
/// measured in points from that display's top-left corner. The display size at save
/// time lets the missing-display fallback keep the same relative position (Decision #26).
public struct Placement: Codable, Hashable, Sendable {
    public var displayID: String
    public var x: Double
    public var y: Double
    public var displayWidth: Double
    public var displayHeight: Double

    public init(displayID: String, x: Double, y: Double, displayWidth: Double, displayHeight: Double) {
        self.displayID = displayID
        self.x = x
        self.y = y
        self.displayWidth = displayWidth
        self.displayHeight = displayHeight
    }
}

public struct Square: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var label: String
    public var text: String
    public var placement: Placement
    public var shortcut: KeyShortcut?
    public var isHidden: Bool

    public init(id: UUID = UUID(), label: String, text: String, placement: Placement, shortcut: KeyShortcut? = nil, isHidden: Bool = false) {
        self.id = id
        self.label = label
        self.text = text
        self.placement = placement
        self.shortcut = shortcut
        self.isHidden = isHidden
    }

    private enum CodingKeys: String, CodingKey {
        case id, label, text, placement, shortcut, isHidden
    }

    // `isHidden` defaults to false for documents saved before this field existed.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        label = try c.decode(String.self, forKey: .label)
        text = try c.decode(String.self, forKey: .text)
        placement = try c.decode(Placement.self, forKey: .placement)
        shortcut = try c.decodeIfPresent(KeyShortcut.self, forKey: .shortcut)
        isHidden = try c.decodeIfPresent(Bool.self, forKey: .isHidden) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(label, forKey: .label)
        try c.encode(text, forKey: .text)
        try c.encode(placement, forKey: .placement)
        try c.encode(shortcut, forKey: .shortcut)
        try c.encode(isHidden, forKey: .isHidden)
    }
}

public struct HistoryEntry: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var text: String
    public var label: String
    public var lastUsed: Date

    public init(id: UUID = UUID(), text: String, label: String, lastUsed: Date) {
        self.id = id
        self.text = text
        self.label = label
        self.lastUsed = lastUsed
    }
}

public struct Preferences: Codable, Hashable, Sendable {
    public static let sizeRange: ClosedRange<Double> = 40...160      // Decisions #36, #57 (default stays 70)
    public static let opacityRange: ClosedRange<Double> = 0.30...1.0 // Decision #24

    public var squareSize: Double = 70
    public var opacity: Double = 0.85
    public var playSound = true
    public var feedbackMode: FeedbackMode = .checkmark
    public var positionsLocked = false
    public var launchAtLogin = false
    public var squaresHidden = false
    public var hideShowShortcut: KeyShortcut? = .defaultHideShowAll
    public var snapShortcut: KeyShortcut? = .defaultSnapToGrid

    public init() {}

    /// Out-of-range size and opacity are clamped on read, not treated as corruption.
    public func clamped() -> Preferences {
        var copy = self
        copy.squareSize = min(max(squareSize, Self.sizeRange.lowerBound), Self.sizeRange.upperBound)
        copy.opacity = min(max(opacity, Self.opacityRange.lowerBound), Self.opacityRange.upperBound)
        return copy
    }

    private enum CodingKeys: String, CodingKey {
        case squareSize, opacity, playSound, feedbackMode, positionsLocked
        case launchAtLogin, squaresHidden, hideShowShortcut, snapShortcut
    }

    // Every key is required. The two app shortcuts may be `null` (cleared) but not absent.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        squareSize = try c.decode(Double.self, forKey: .squareSize)
        opacity = try c.decode(Double.self, forKey: .opacity)
        playSound = try c.decode(Bool.self, forKey: .playSound)
        feedbackMode = try c.decode(FeedbackMode.self, forKey: .feedbackMode)
        positionsLocked = try c.decode(Bool.self, forKey: .positionsLocked)
        launchAtLogin = try c.decode(Bool.self, forKey: .launchAtLogin)
        squaresHidden = try c.decode(Bool.self, forKey: .squaresHidden)
        guard c.contains(.hideShowShortcut), c.contains(.snapShortcut) else {
            throw DecodingError.keyNotFound(CodingKeys.hideShowShortcut, .init(codingPath: c.codingPath, debugDescription: "App shortcut keys are required"))
        }
        hideShowShortcut = try c.decode(KeyShortcut?.self, forKey: .hideShowShortcut)
        snapShortcut = try c.decode(KeyShortcut?.self, forKey: .snapShortcut)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(squareSize, forKey: .squareSize)
        try c.encode(opacity, forKey: .opacity)
        try c.encode(playSound, forKey: .playSound)
        try c.encode(feedbackMode, forKey: .feedbackMode)
        try c.encode(positionsLocked, forKey: .positionsLocked)
        try c.encode(launchAtLogin, forKey: .launchAtLogin)
        try c.encode(squaresHidden, forKey: .squaresHidden)
        try c.encode(hideShowShortcut, forKey: .hideShowShortcut)
        try c.encode(snapShortcut, forKey: .snapShortcut)
    }
}

/// The single saved configuration document.
public struct ConfigDocument: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var preferences: Preferences
    public var squares: [Square]
    public var history: [HistoryEntry]

    public init(schemaVersion: Int = ConfigDocument.currentSchemaVersion, preferences: Preferences = Preferences(), squares: [Square] = [], history: [HistoryEntry] = []) {
        self.schemaVersion = schemaVersion
        self.preferences = preferences
        self.squares = squares
        self.history = history
    }
}
