import Foundation
import Testing
@testable import YoinkCore

@MainActor
@Suite("Copy, feedback, and shortcuts")
struct CopyAndFeedbackTests {
    @Test(arguments: [Fixture.seedA, Fixture.multiBlank, Fixture.multiTrailing, "tab\there", "crlf\r\nline", "  leading and trailing  "])
    func copyWritesTheExactStoredText(_ text: String) throws {
        let clipboard = FakeClipboard()
        let store = makeStore(clipboard: clipboard)
        let id = try store.addSquare(label: "M", text: text, placement: placement())
        #expect(store.copy(squareID: id) == .copied(.checkmark))
        #expect(clipboard.writes == [text])
        #expect(store.square(id)?.text == text, "copy never mutates the snippet")
    }

    @Test func failedClipboardWriteGivesNoFeedbackAndNoSound() {
        let clipboard = FakeClipboard()
        clipboard.succeeds = false
        let sound = FakeSound()
        let store = makeStore(clipboard: clipboard, sound: sound)
        let before = store.document
        #expect(store.copy(squareID: store.squares[0].id) == .failed)
        #expect(sound.plays == 0)
        #expect(store.document == before)
    }

    @Test func soundFollowsThePreferenceAndVisualModeFollowsTheSelection() {
        let sound = FakeSound()
        let store = makeStore(sound: sound)
        let id = store.squares[2].id
        #expect(store.copy(squareID: id) == .copied(.checkmark))
        #expect(sound.plays == 1)

        store.setPlaySound(false)
        store.setFeedbackMode(.burst)
        #expect(store.copy(squareID: id) == .copied(.burst))
        #expect(sound.plays == 1, "silent when Play sound on copy is off")

        store.setFeedbackMode(.none)
        #expect(store.copy(squareID: id) == .copied(.none))
    }

    @Test func copyingNeverChangesTheDocument() {
        let store = makeStore()
        let before = store.document
        for square in store.squares { _ = store.copy(squareID: square.id) }
        #expect(store.document == before)
        #expect(!store.canUndo)
    }

    @Test func squareShortcutPressUsesTheSameCopyPathAsAClick() throws {
        let clipboard = FakeClipboard()
        let sound = FakeSound()
        let store = makeStore(clipboard: clipboard, sound: sound)
        let port = FakeHotkeys()
        let hotkeys = HotkeyCoordinator(port: port, store: store)
        hotkeys.sync()
        let a = store.squares[4].id
        let ctrlOpt1 = KeyShortcut(keyCode: 18, modifiers: KeyShortcut.control | KeyShortcut.option)
        try hotkeys.assign(ctrlOpt1, to: .square(a))

        let pressed = try #require(port.idFor(ctrlOpt1))
        #expect(hotkeys.action(forHotkeyID: pressed) == .copy(a))
        #expect(store.copy(squareID: a) == .copied(.checkmark))
        #expect(clipboard.writes == [Fixture.seedA])
        #expect(sound.plays == 1)

        #expect(hotkeys.action(forHotkeyID: try #require(port.idFor(.defaultHideShowAll))) == .toggleHidden)
        #expect(hotkeys.action(forHotkeyID: try #require(port.idFor(.defaultSnapToGrid))) == .snapToGrid)
    }

    @Test func conflictingOrUnregistrableShortcutsAreRefusedAndThePreviousValueIsKept() throws {
        let store = makeStore()
        let port = FakeHotkeys()
        let hotkeys = HotkeyCoordinator(port: port, store: store)
        hotkeys.sync()
        let id = store.squares[0].id
        let first = KeyShortcut(keyCode: 18, modifiers: KeyShortcut.control | KeyShortcut.option)
        try hotkeys.assign(first, to: .square(id))

        #expect(throws: ShortcutAssignError.usedBy(.hideShowAll)) { try hotkeys.assign(.defaultHideShowAll, to: .square(id)) }
        let taken = KeyShortcut(keyCode: 19, modifiers: KeyShortcut.command)
        port.refused = [taken]
        #expect(throws: ShortcutAssignError.cannotRegister) { try hotkeys.assign(taken, to: .square(id)) }
        #expect(store.square(id)?.shortcut == first)

        // Clearing removes the registration.
        try hotkeys.assign(nil, to: .square(id))
        #expect(port.idFor(first) == nil)
        // App shortcuts can be changed and cleared too.
        try hotkeys.assign(nil, to: .snapToGrid)
        #expect(store.preferences.snapShortcut == nil)
        #expect(port.idFor(.defaultSnapToGrid) == nil)
    }

    @Test func savedShortcutThatFailsToRegisterIsFlaggedAndTheSquareStillCopies() throws {
        var doc = SeedData.document(main: Displays.one)
        let bad = KeyShortcut(keyCode: 20, modifiers: KeyShortcut.command)
        doc.squares[1].shortcut = bad
        let store = makeStore(doc)
        let port = FakeHotkeys()
        port.refused = [bad]
        HotkeyCoordinator(port: port, store: store).sync()
        #expect(store.shortcutFailures == [.square(doc.squares[1].id)])
        #expect(store.copy(squareID: doc.squares[1].id) == .copied(.checkmark))
    }

    @Test func shortcutsStillResolveWhileSquaresAreHidden() throws {
        let store = makeStore()
        let port = FakeHotkeys()
        let hotkeys = HotkeyCoordinator(port: port, store: store)
        let s = KeyShortcut(keyCode: 18, modifiers: KeyShortcut.control | KeyShortcut.option)
        try hotkeys.assign(s, to: .square(store.squares[0].id))
        store.setSquaresHidden(true)
        hotkeys.sync()
        #expect(hotkeys.action(forHotkeyID: try #require(port.idFor(s))) == .copy(store.squares[0].id))
    }

    @Test func clickVersusDrag() {
        // Unlocked: small movement copies, movement past ~4 pt drags and never copies.
        var t = PointerTracker(start: .init(x: 100, y: 100), locked: false)
        let moved1 = t.moved(to: .init(x: 102, y: 102))
        #expect(!moved1)
        #expect(t.release(insideSquare: true) == .copy)

        t = PointerTracker(start: .init(x: 100, y: 100), locked: false)
        let moved2 = t.moved(to: .init(x: 110, y: 100))
        #expect(moved2)
        let moved3 = t.moved(to: .init(x: 101, y: 100))
        #expect(moved3, "once dragging, stays a drag")
        #expect(t.release(insideSquare: true) == .endDrag)

        // Locked: never moves; release over the square copies whatever the movement.
        t = PointerTracker(start: .init(x: 100, y: 100), locked: true)
        let moved4 = t.moved(to: .init(x: 140, y: 100))
        #expect(!moved4)
        #expect(t.release(insideSquare: true) == .copy)

        // Releasing outside the square copies nothing.
        t = PointerTracker(start: .init(x: 100, y: 100), locked: true)
        #expect(t.release(insideSquare: false) == .nothing)
    }

    @Test func previewKeepsTextExactWhenItFits() {
        for text in [Fixture.seedA, Fixture.multiBlank, Fixture.multiTrailing] {
            let layout = PreviewLayout.make(text: text, columns: 200, maxLines: 50)
            #expect(layout.displayText == text)
            #expect(layout.hiddenLineCount == 0)
        }
    }

    @Test func previewWrapIsWidthAwareSoNothingIsClipped() {
        // Wide characters count by their measured width; tabs show as four spaces.
        let width: (Character) -> Double = { $0.unicodeScalars.first!.value > 0x2E80 ? 2 : 1 }
        let lines = PreviewLayout.wrap("漢字漢字漢字", maxWidth: 5, width: width)
        #expect(lines == ["漢字", "漢字", "漢字"])
        #expect(lines.allSatisfy { $0.reduce(0) { $0 + width($1) } <= 5 })
        #expect(PreviewLayout.wrap("\tx", maxWidth: 80, width: { _ in 1 }) == ["    x"])
        #expect(PreviewLayout.wrap("a\n", maxWidth: 80, width: { _ in 1 }) == ["a", ""], "trailing newline kept")
    }

    @Test func previewWrapsLongLinesAndEndsWithAMoreLinesMarker() {
        let long = String(repeating: "x", count: 25)
        #expect(PreviewLayout.wrap(long, columns: 10) == ["xxxxxxxxxx", "xxxxxxxxxx", "xxxxx"])
        let many = (1...40).map { "line \($0)" }.joined(separator: "\n")
        let layout = PreviewLayout.make(text: many, columns: 80, maxLines: 10)
        #expect(layout.lines.count == 10)
        #expect(layout.lines.last == "… 31 more lines")
        #expect(layout.lines.first == "line 1")
        #expect(layout.hiddenLineCount == 31)
    }
}
