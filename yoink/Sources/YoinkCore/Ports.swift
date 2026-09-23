import Foundation

/// Writes the exact snippet text to the system clipboard. Returns false if the write failed.
/// Implementations must never parse, run, open, paste, or log the text.
@MainActor
public protocol ClipboardPort: AnyObject {
    func write(_ text: String) -> Bool
}

/// Plays the approved confirmation sound. Called only after a successful copy.
@MainActor
public protocol SoundPort: AnyObject {
    func playCopySound()
}

/// Operating-system login-item registration (SMAppService in the App).
public enum LoginItemState: Equatable, Sendable {
    case enabled
    case disabled
    case requiresApproval
}

@MainActor
public protocol LoginItemPort: AnyObject {
    var state: LoginItemState { get }
    /// Asks macOS for the requested state and returns the state macOS reports afterwards.
    func apply(enabled: Bool) -> LoginItemState
}

/// Registers system-wide shortcuts (Carbon `RegisterEventHotKey` in the App).
@MainActor
public protocol HotkeyPort: AnyObject {
    /// Returns false when macOS refuses the registration.
    func register(_ shortcut: KeyShortcut, id: UInt32) -> Bool
    func unregister(id: UInt32)
}
