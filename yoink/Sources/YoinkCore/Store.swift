import Foundation
import Observation

public enum ShortcutOwner: Hashable, Sendable {
    case square(UUID)
    case hideShowAll
    case snapToGrid
}

public enum CopyOutcome: Equatable, Sendable {
    /// The clipboard write failed: no sound and no visual feedback.
    case failed
    /// The text is on the clipboard; show this visual mode.
    case copied(FeedbackMode)
}

/// The product state for yo!nk. All durable changes go through this type so validation,
/// undo (Decision #41), and snippet history (Decision #43) stay consistent. No AppKit.
@MainActor
@Observable
public final class YoinkStore {
    public private(set) var document: ConfigDocument
    /// Shortcuts macOS refused to register (flagged in Settings; the square still works by click).
    public internal(set) var shortcutFailures: Set<ShortcutOwner> = []
    public private(set) var undoActionName: String?
    public private(set) var redoActionName: String?

    /// Called after every change to the document. The App saves, updates windows, and re-syncs hotkeys.
    @ObservationIgnored public var onChange: (() -> Void)?

    @ObservationIgnored private let clipboard: ClipboardPort
    @ObservationIgnored private let sound: SoundPort
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private var undoStack: [UndoStep] = []
    @ObservationIgnored private var redoStack: [UndoStep] = []
    @ObservationIgnored private var coalesceKey: String?
    @ObservationIgnored private var pendingHistory: [UUID] = []
    @ObservationIgnored private let undoLimit = 200

    public init(document: ConfigDocument, clipboard: ClipboardPort, sound: SoundPort, now: @escaping () -> Date = Date.init) {
        self.document = document
        self.clipboard = clipboard
        self.sound = sound
        self.now = now
    }

    public var squares: [Square] { document.squares }
    public var preferences: Preferences { document.preferences }
    public var history: [HistoryEntry] { document.history }

    public func square(_ id: UUID) -> Square? { document.squares.first { $0.id == id } }

    // MARK: Copy (Decisions #9, #10, #12, #25)

    /// Copies the square's complete text. Feedback is decided only after the clipboard write succeeds.
    public func copy(squareID: UUID) -> CopyOutcome {
        guard let square = square(squareID) else { return .failed }
        guard clipboard.write(square.text) else { return .failed }
        if preferences.playSound { sound.playCopySound() }
        return .copied(preferences.feedbackMode)
    }

    /// Copies a History entry from Settings. No sound or square feedback.
    @discardableResult
    public func copyHistoryEntry(_ id: UUID) -> Bool {
        guard let entry = document.history.first(where: { $0.id == id }) else { return false }
        return clipboard.write(entry.text)
    }

    // MARK: Squares

    @discardableResult
    public func addSquare(label: String, text: String, placement: Placement) throws(LabelError) -> UUID {
        if let error = LabelRules.validate(label) { throw error }
        let square = Square(label: label, text: text, placement: placement)
        perform("Add Square") { $0.squares.append(square) }
        recordHistory(text: text, label: label)
        return square.id
    }

    @discardableResult
    public func addSquare(fromHistory entryID: UUID, placement: Placement) -> UUID? {
        guard let entry = document.history.first(where: { $0.id == entryID }) else { return nil }
        let label = LabelRules.isValid(entry.label) ? entry.label : "?"
        return try? addSquare(label: label, text: entry.text, placement: placement)
    }

    public func updateLabel(_ id: UUID, to label: String) throws(LabelError) {
        if let error = LabelRules.validate(label) { throw error }
        mutateSquare(id, name: "Edit Square", coalesce: "label-\(id)") { $0.label = label }
    }

    /// Live text edit from Settings. History is refreshed when editing is committed.
    public func updateText(_ id: UUID, to text: String) {
        guard square(id)?.text != text else { return }
        mutateSquare(id, name: "Edit Square", coalesce: "text-\(id)") { $0.text = text }
        if !pendingHistory.contains(id) { pendingHistory.append(id) }
    }

    /// Ends the current edit: records edited texts in History and closes the undo coalescing window.
    public func commitEdits() {
        let ids = pendingHistory
        pendingHistory.removeAll()
        coalesceKey = nil
        for id in ids {
            if let square = square(id) { recordHistory(text: square.text, label: square.label) }
        }
    }

    @discardableResult
    public func duplicateSquare(_ id: UUID, placement: Placement) -> UUID? {
        commitEdits()
        guard let source = square(id) else { return nil }
        let copy = Square(label: source.label, text: source.text, placement: placement)
        perform("Duplicate Square") { doc in
            let index = doc.squares.firstIndex { $0.id == id }.map { $0 + 1 } ?? doc.squares.count
            doc.squares.insert(copy, at: index)
        }
        recordHistory(text: copy.text, label: copy.label)
        return copy.id
    }

    public func deleteSquare(_ id: UUID) {
        commitEdits()
        perform("Delete Square") { $0.squares.removeAll { $0.id == id } }
    }

    public func moveSquare(_ id: UUID, to placement: Placement) {
        guard !preferences.positionsLocked else { return }
        mutateSquare(id, name: "Move Square", coalesce: nil) { $0.placement = placement }
    }

    /// Snap to Grid (Decision #40). Unavailable while locked. One undo step for all squares.
    @discardableResult
    public func snapToGrid(displays: [DisplayGeometry]) -> Bool {
        guard !preferences.positionsLocked else { return false }
        let placements = GridLayout.snap(document.squares, squareSize: preferences.squareSize, displays: displays)
        guard !placements.isEmpty else { return false }
        perform("Snap to Grid") { doc in
            for index in doc.squares.indices {
                if let p = placements[doc.squares[index].id] { doc.squares[index].placement = p }
            }
        }
        return true
    }

    // MARK: Shortcuts (Decisions #37, #38, #40)

    public func shortcut(for owner: ShortcutOwner) -> KeyShortcut? {
        switch owner {
        case .square(let id): square(id)?.shortcut
        case .hideShowAll: preferences.hideShowShortcut
        case .snapToGrid: preferences.snapShortcut
        }
    }

    public var assignedShortcuts: [(owner: ShortcutOwner, shortcut: KeyShortcut)] {
        var result: [(ShortcutOwner, KeyShortcut)] = []
        if let s = preferences.hideShowShortcut { result.append((.hideShowAll, s)) }
        if let s = preferences.snapShortcut { result.append((.snapToGrid, s)) }
        for square in document.squares {
            if let s = square.shortcut { result.append((.square(square.id), s)) }
        }
        return result
    }

    /// Another yo!nk owner already using `shortcut`, if any.
    public func conflict(for shortcut: KeyShortcut, excluding owner: ShortcutOwner) -> ShortcutOwner? {
        assignedShortcuts.first { $0.shortcut == shortcut && $0.owner != owner }?.owner
    }

    /// Stores a shortcut. Callers check conflicts and registration first (see `HotkeyCoordinator`).
    func setShortcut(_ shortcut: KeyShortcut?, for owner: ShortcutOwner) {
        switch owner {
        case .square(let id):
            mutateSquare(id, name: "Change Shortcut", coalesce: nil) { $0.shortcut = shortcut }
        case .hideShowAll:
            perform("Change Shortcut") { $0.preferences.hideShowShortcut = shortcut }
        case .snapToGrid:
            perform("Change Shortcut") { $0.preferences.snapShortcut = shortcut }
        }
    }

    // MARK: Preferences

    public func setSquareSize(_ size: Double) {
        let value = min(max(size.rounded(), Preferences.sizeRange.lowerBound), Preferences.sizeRange.upperBound)
        perform("Change Square Size", coalesce: "size") { $0.preferences.squareSize = value }
    }

    public func setOpacity(_ opacity: Double) {
        let value = min(max((opacity * 100).rounded() / 100, Preferences.opacityRange.lowerBound), Preferences.opacityRange.upperBound)
        perform("Change Opacity", coalesce: "opacity") { $0.preferences.opacity = value }
    }

    public func setFeedbackMode(_ mode: FeedbackMode) {
        perform("Change Copy Feedback") { $0.preferences.feedbackMode = mode }
    }

    public func setPlaySound(_ on: Bool) {
        perform("Change Copy Sound") { $0.preferences.playSound = on }
    }

    public func setPositionsLocked(_ locked: Bool) {
        perform(locked ? "Lock Positions" : "Unlock Positions") { $0.preferences.positionsLocked = locked }
    }

    /// Hide/Show All (Decision #38). Remembered across relaunch; not an undo step.
    public func setSquaresHidden(_ hidden: Bool) {
        guard preferences.squaresHidden != hidden else { return }
        document.preferences.squaresHidden = hidden
        onChange?()
    }

    /// Applies launch at login through macOS. The saved preference only records what macOS
    /// reports, so a failed or pending registration is never saved as success.
    @discardableResult
    public func applyLaunchAtLogin(_ enabled: Bool, port: LoginItemPort) -> LoginItemState {
        let state = port.apply(enabled: enabled)
        setLaunchAtLoginPreference(state == .enabled)
        return state
    }

    /// Makes the saved preference follow the operating-system state (read only, never registers).
    public func syncLaunchAtLogin(from port: LoginItemPort) {
        setLaunchAtLoginPreference(port.state == .enabled)
    }

    private func setLaunchAtLoginPreference(_ value: Bool) {
        guard preferences.launchAtLogin != value else { return }
        document.preferences.launchAtLogin = value
        onChange?()
    }

    // MARK: History (Decision #43)

    public func removeHistoryEntry(_ id: UUID) {
        var history = SnippetHistory(entries: document.history)
        history.remove(id: id)
        document.history = history.entries
        onChange?()
    }

    public func clearHistory() {
        document.history = []
        onChange?()
    }

    private func recordHistory(text: String, label: String) {
        var history = SnippetHistory(entries: document.history)
        history.record(text: text, label: label, at: now())
        document.history = history.entries
        onChange?()
    }

    // MARK: Undo and Redo (Decision #41), session only

    public var canUndo: Bool { undoActionName != nil }
    public var canRedo: Bool { redoActionName != nil }

    public func undo() {
        commitEdits()
        guard let step = undoStack.popLast() else { return }
        redoStack.append(UndoStep(name: step.name, snapshot: snapshot))
        restore(step.snapshot)
    }

    public func redo() {
        guard let step = redoStack.popLast() else { return }
        undoStack.append(UndoStep(name: step.name, snapshot: snapshot))
        restore(step.snapshot)
    }

    private struct Snapshot {
        var squares: [Square]
        var preferences: Preferences
    }

    private struct UndoStep {
        var name: String
        var snapshot: Snapshot
    }

    private var snapshot: Snapshot { Snapshot(squares: document.squares, preferences: document.preferences) }

    /// Restores squares and undoable preferences. Launch at login (operating-system state) and
    /// the hidden state are not undo steps, so they keep their current values.
    private func restore(_ snap: Snapshot) {
        var prefs = snap.preferences
        prefs.launchAtLogin = document.preferences.launchAtLogin
        prefs.squaresHidden = document.preferences.squaresHidden
        document.squares = snap.squares
        document.preferences = prefs
        coalesceKey = nil
        refreshUndoNames()
        onChange?()
    }

    private func mutateSquare(_ id: UUID, name: String, coalesce: String?, _ change: (inout Square) -> Void) {
        perform(name, coalesce: coalesce) { doc in
            guard let index = doc.squares.firstIndex(where: { $0.id == id }) else { return }
            change(&doc.squares[index])
        }
    }

    private func perform(_ name: String, coalesce: String? = nil, _ change: (inout ConfigDocument) -> Void) {
        let before = snapshot
        var doc = document
        change(&doc)
        guard doc.squares != before.squares || doc.preferences != before.preferences else { return }
        document = doc
        if coalesce == nil || coalesce != coalesceKey || undoStack.isEmpty {
            undoStack.append(UndoStep(name: name, snapshot: before))
            if undoStack.count > undoLimit { undoStack.removeFirst() }
        }
        coalesceKey = coalesce
        redoStack.removeAll()
        refreshUndoNames()
        onChange?()
    }

    private func refreshUndoNames() {
        undoActionName = undoStack.last?.name
        redoActionName = redoStack.last?.name
    }
}
