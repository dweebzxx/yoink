import Foundation
import Testing
@testable import YoinkCore

@MainActor
@Suite("Persistence")
struct PersistenceTests {
    private func fullDocument() -> ConfigDocument {
        var prefs = Preferences()
        prefs.squareSize = 123
        prefs.opacity = 0.42
        prefs.playSound = false
        prefs.feedbackMode = .burst
        prefs.positionsLocked = true
        prefs.launchAtLogin = true
        prefs.squaresHidden = true
        prefs.hideShowShortcut = nil
        prefs.snapShortcut = KeyShortcut(keyCode: 5, modifiers: KeyShortcut.command | KeyShortcut.shift)
        let squares = [
            Square(label: "A", text: Fixture.seedA, placement: placement("disp-1", 10, 30)),
            Square(label: "M1", text: Fixture.multiBlank, placement: placement("disp-2", 500.5, 700.25), shortcut: KeyShortcut(keyCode: 18, modifiers: 6144)),
            Square(label: "M2", text: Fixture.multiTrailing, placement: placement("disp-2", 0, 0), isHidden: true),
            Square(label: "e\u{301}1", text: "", placement: placement()),
            Square(label: "🙂🚀", text: "crlf\r\nand\ttab", placement: placement()),
        ]
        let history = [HistoryEntry(text: Fixture.multiBlank, label: "M1", lastUsed: Date(timeIntervalSince1970: 1_790_000_000))]
        return ConfigDocument(preferences: prefs, squares: squares, history: history)
    }

    @Test func fullFieldCatalogRoundTripsThroughTheFile() throws {
        let dir = try TempDir()
        defer { dir.remove() }
        let files = ConfigFileStore(directory: dir.url)
        let doc = fullDocument()
        try files.save(doc)
        #expect(files.load() == .loaded(doc))
        let mode = try FileManager.default.attributesOfItem(atPath: files.fileURL.path)[.posixPermissions] as? Int
        #expect(mode == 0o600)
    }

    @Test func missingFileIsFirstLaunch() throws {
        let dir = try TempDir()
        defer { dir.remove() }
        #expect(ConfigFileStore(directory: dir.url).load() == .notFound)
    }

    @Test func versionOneFixtureLoadsWithEveryFieldIntact() throws {
        // Upgrade compatibility: a document written by schema 1 must keep loading unchanged.
        guard case .loaded(let doc) = ConfigCodec.decode(try Fixture.data("cfg-two-display.v1.json")) else {
            Issue.record("fixture did not load")
            return
        }
        #expect(doc.schemaVersion == 1)
        #expect(doc.squares.map(\.label) == ["S", "O", "C", "CL", "A"])
        #expect(doc.squares.filter { $0.placement.displayID == "disp-1" }.map(\.label) == ["S", "O"])
        #expect(doc.squares.filter { $0.placement.displayID == "disp-2" }.map(\.label) == ["C", "CL", "A"])
        #expect(doc.squares[4].text == Fixture.seedA)
        #expect(doc.squares[2].shortcut == KeyShortcut(keyCode: 18, modifiers: 6144))
        #expect(doc.squares.allSatisfy { !$0.isHidden }, "squares saved before isHidden existed default to visible")
        #expect(doc.squares[1].placement == Placement(displayID: "disp-1", x: 40, y: 180, displayWidth: 1512, displayHeight: 982))
        let p = doc.preferences
        #expect(p.feedbackMode == .burst && p.positionsLocked && !p.playSound && p.squaresHidden)
        #expect(p.squareSize == 96 && p.opacity == 0.6)
        #expect(p.hideShowShortcut == .defaultHideShowAll && p.snapShortcut == nil)
        #expect(doc.history.count == 1)
    }

    @Test(arguments: [
        ("bad-unreadable.json", CorruptReason.unreadable),
        ("bad-empty-file.json", CorruptReason.unreadable),
        ("bad-newer-schema.json", CorruptReason.newerSchema(2)),
    ])
    func corruptDocumentsAreNotFirstLaunch(_ name: String, _ reason: CorruptReason) throws {
        #expect(ConfigCodec.decode(try Fixture.data(name)) == .corrupt(reason))
    }

    @Test(arguments: ["bad-missing-squares.json", "bad-missing-identity.json", "bad-feedback.json", "bad-label.json"])
    func invalidDocumentsAreCorrupt(_ name: String) throws {
        guard case .corrupt(.invalid) = ConfigCodec.decode(try Fixture.data(name)) else {
            Issue.record("\(name) was not classified invalid")
            return
        }
    }

    @Test func unknownFieldsAreUnsupportedInsteadOfBeingDroppedOnSave() throws {
        #expect(ConfigCodec.decode(try Fixture.data("bad-unknown-field.json")) == .corrupt(.invalid("unknown field color")))
    }

    @Test func historyRemoveAndClearPersistAfterReload() throws {
        let dir = try TempDir()
        defer { dir.remove() }
        let files = ConfigFileStore(directory: dir.url)
        let store = makeStore()
        let removed = store.history[1].id
        store.removeHistoryEntry(removed)
        try files.save(store.document)
        guard case .loaded(let afterRemove) = files.load() else { Issue.record("reload failed"); return }
        #expect(afterRemove.history.count == 4 && !afterRemove.history.contains { $0.id == removed })
        store.clearHistory()
        try files.save(store.document)
        guard case .loaded(let afterClear) = files.load() else { Issue.record("reload failed"); return }
        #expect(afterClear.history.isEmpty)
        #expect(afterClear.squares.count == 5, "clearing history never touches squares")
    }

    @Test func outOfRangeSizeAndOpacityAreClampedOnRead() throws {
        guard case .loaded(let big) = ConfigCodec.decode(try Fixture.data("cfg-out-of-range.json")),
              case .loaded(let small) = ConfigCodec.decode(try Fixture.data("cfg-too-small.json")) else {
            Issue.record("clamping fixtures did not load")
            return
        }
        #expect(big.preferences.squareSize == 160 && big.preferences.opacity == 0.30)
        #expect(small.preferences.squareSize == 40, "30 pt clamps to the 40 pt minimum (Decision #57)")
    }

    @Test func failedWriteKeepsThePreviousValidDocument() throws {
        let dir = try TempDir()
        defer {
            chmod(dir.url.path, 0o700)
            dir.remove()
        }
        let files = ConfigFileStore(directory: dir.url)
        let original = fullDocument()
        try files.save(original)
        chmod(dir.url.path, 0o500) // read-only folder: the temporary file cannot be created
        var changed = original
        changed.squares.removeAll()
        #expect(throws: (any Error).self) { try files.save(changed) }
        chmod(dir.url.path, 0o700)
        #expect(files.load() == .loaded(original))
        let leftovers = try FileManager.default.contentsOfDirectory(atPath: dir.url.path).filter { $0.hasSuffix(".tmp") }
        #expect(leftovers.isEmpty)
    }

    @Test func startFreshBacksUpTheUnreadableFileBeforeWritingSeeds() throws {
        let dir = try TempDir()
        defer { dir.remove() }
        let files = ConfigFileStore(directory: dir.url)
        let bad = try Fixture.data("bad-unreadable.json")
        try bad.write(to: files.fileURL)
        #expect(files.load() == .corrupt(.unreadable))
        // Nothing is written until the user chooses Start Fresh.
        #expect(try Data(contentsOf: files.fileURL) == bad)

        let backup = try files.backUpUnreadableFile(now: Date(timeIntervalSince1970: 1_790_000_000))
        #expect(backup.lastPathComponent.hasPrefix("config.unreadable-"))
        #expect(try Data(contentsOf: backup) == bad)
        try files.save(SeedData.document(main: Displays.one))
        guard case .loaded(let doc) = files.load() else {
            Issue.record("seed document did not load")
            return
        }
        #expect(doc.squares.count == 5)
    }

    @Test func onlyOneInstanceOwnsAConfigurationFolder() throws {
        let dir = try TempDir()
        defer { dir.remove() }
        let first = InstanceLock(directory: dir.url)
        #expect(first != nil)
        // flock is per open file description, so a second descriptor in this process is refused too.
        #expect(InstanceLock(directory: dir.url) == nil)
        _ = first
    }

    @Test func storeChangesPersistThroughASaveAndReload() throws {
        let dir = try TempDir()
        defer { dir.remove() }
        let files = ConfigFileStore(directory: dir.url)
        let store = makeStore()
        store.setSquareSize(160)
        store.setOpacity(0.3)
        store.setPositionsLocked(true)
        store.setFeedbackMode(.none)
        store.updateText(store.squares[0].id, to: Fixture.multiBlank)
        store.commitEdits()
        store.setSquaresHidden(true)
        try files.save(store.document)
        #expect(files.load() == .loaded(store.document))
    }
}
