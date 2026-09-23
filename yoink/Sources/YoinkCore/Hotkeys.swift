import Foundation

public enum HotkeyAction: Equatable, Sendable {
    case copy(UUID)
    case toggleHidden
    case snapToGrid
}

public enum ShortcutAssignError: Error, Equatable, Sendable {
    case usedBy(ShortcutOwner)
    case cannotRegister
}

/// Keeps the system-wide registrations in step with the store and maps presses to actions.
/// A press is handled exactly like a click on the square (Decision #37).
@MainActor
public final class HotkeyCoordinator {
    private let port: HotkeyPort
    private let store: YoinkStore
    private var registered: [UInt32: ShortcutOwner] = [:]
    private var registeredSet: [ShortcutOwner: KeyShortcut] = [:]
    private var nextID: UInt32 = 1
    private var suspended = false
    private let probeID: UInt32 = 0xFFFF_FFFF

    public init(port: HotkeyPort, store: YoinkStore) {
        self.port = port
        self.store = store
    }

    /// Re-registers only when the set of assigned shortcuts changed.
    public func sync() {
        guard !suspended else { return }
        var desired: [ShortcutOwner: KeyShortcut] = [:]
        for item in store.assignedShortcuts { desired[item.owner] = item.shortcut }
        guard desired != registeredSet else { return }
        unregisterAll()
        var failures = Set<ShortcutOwner>()
        for item in store.assignedShortcuts {
            let id = nextID
            nextID &+= 1
            if port.register(item.shortcut, id: id) {
                registered[id] = item.owner
            } else {
                failures.insert(item.owner)
            }
        }
        registeredSet = desired
        if store.shortcutFailures != failures { store.shortcutFailures = failures }
    }

    /// Assigns (or clears, with nil) a shortcut. Refuses one already used by yo!nk or one
    /// macOS will not register; the previous value is kept in both cases.
    public func assign(_ shortcut: KeyShortcut?, to owner: ShortcutOwner) throws(ShortcutAssignError) {
        if let shortcut {
            if let other = store.conflict(for: shortcut, excluding: owner) { throw .usedBy(other) }
            if store.shortcut(for: owner) != shortcut {
                guard probe(shortcut) else { throw .cannotRegister }
            }
        }
        store.setShortcut(shortcut, for: owner)
        sync()
    }

    public func action(forHotkeyID id: UInt32) -> HotkeyAction? {
        guard let owner = registered[id] else { return nil }
        switch owner {
        case .square(let squareID): return store.square(squareID) == nil ? nil : .copy(squareID)
        case .hideShowAll: return .toggleHidden
        case .snapToGrid: return .snapToGrid
        }
    }

    /// Pauses every registration while the Settings shortcut recorder listens for keys.
    public func suspend() {
        suspended = true
        unregisterAll()
    }

    public func resume() {
        guard suspended else { return }
        suspended = false
        sync()
    }

    private func probe(_ shortcut: KeyShortcut) -> Bool {
        guard port.register(shortcut, id: probeID) else { return false }
        port.unregister(id: probeID)
        return true
    }

    private func unregisterAll() {
        for id in registered.keys { port.unregister(id: id) }
        registered.removeAll()
        registeredSet.removeAll()
    }
}
