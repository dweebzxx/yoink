import CoreGraphics
import Foundation
@testable import YoinkCore

@MainActor
final class FakeClipboard: ClipboardPort {
    var succeeds = true
    private(set) var writes: [String] = []
    func write(_ text: String) -> Bool {
        guard succeeds else { return false }
        writes.append(text)
        return true
    }
}

@MainActor
final class FakeSound: SoundPort {
    private(set) var plays = 0
    func playCopySound() { plays += 1 }
}

@MainActor
final class FakeLoginItem: LoginItemPort {
    var state: LoginItemState = .disabled
    var result: LoginItemState?
    func apply(enabled: Bool) -> LoginItemState {
        state = result ?? (enabled ? .enabled : .disabled)
        return state
    }
}

@MainActor
final class FakeHotkeys: HotkeyPort {
    var refused: Set<KeyShortcut> = []
    private(set) var active: [UInt32: KeyShortcut] = [:]
    func register(_ shortcut: KeyShortcut, id: UInt32) -> Bool {
        guard !refused.contains(shortcut), !active.values.contains(shortcut) else { return false }
        active[id] = shortcut
        return true
    }
    func unregister(id: UInt32) { active[id] = nil }
    /// Simulates macOS delivering a press of `shortcut`.
    func idFor(_ shortcut: KeyShortcut) -> UInt32? { active.first { $0.value == shortcut }?.key }
}

enum Displays {
    /// `disp-1` on the left (the main display, menu bar 24 pt), `disp-2` on the right.
    static let one = DisplayGeometry(id: "disp-1", size: CGSize(width: 1512, height: 982), usable: CGRect(x: 0, y: 24, width: 1512, height: 958), isMain: true)
    static let two = DisplayGeometry(id: "disp-2", size: CGSize(width: 1920, height: 1080), usable: CGRect(x: 0, y: 0, width: 1920, height: 1080), isMain: false)
    static let pair = [one, two]
}

enum Fixture {
    static func data(_ name: String) throws -> Data {
        guard let url = Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try Data(contentsOf: url)
    }

    static let seedA = "cd /Volumes/etcetera/etceteraOS/ai-projects/code-playground-beta/spicedanime-webapp-docs\nagy --dangerously-skip-permissions"
    static let multiBlank = "line one\n\nline three"
    static let multiTrailing = "has trailing newline\n"
}

/// An isolated temporary configuration folder inside the package's git-ignored `.build/`
/// folder: never the live Application Support location and never outside the repository.
struct TempDir {
    static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("../../.build/test-tmp", isDirectory: true)
        .standardized
    let url: URL
    init() throws {
        url = Self.root.appendingPathComponent("yoink-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
    func remove() { try? FileManager.default.removeItem(at: url) }
}

@MainActor
func makeStore(_ doc: ConfigDocument? = nil, clipboard: FakeClipboard = FakeClipboard(), sound: FakeSound = FakeSound()) -> YoinkStore {
    YoinkStore(document: doc ?? SeedData.document(main: Displays.one), clipboard: clipboard, sound: sound)
}

func placement(_ display: String = "disp-1", _ x: Double = 100, _ y: Double = 100) -> Placement {
    Placement(displayID: display, x: x, y: y, displayWidth: display == "disp-1" ? 1512 : 1920, displayHeight: display == "disp-1" ? 982 : 1080)
}
