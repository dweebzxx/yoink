import CoreGraphics
import Foundation
import Testing
@testable import YoinkCore

@MainActor
@Suite("Undo, grid, placement, history, and login item")
struct UndoGridPlacementTests {
    // MARK: Undo and redo (Decision #41)

    @Test func everyChangeTypeUndoesAndRedoesAsOneStep() throws {
        let store = makeStore()
        let id = store.squares[0].id
        let changes: [(String, () throws -> Void)] = [
            ("Add Square", { _ = try store.addSquare(label: "N", text: "new", placement: placement()) }),
            ("Edit Square", { try store.updateLabel(id, to: "X") }),
            ("Edit Square", { store.updateText(id, to: "edited") }),
            ("Duplicate Square", { _ = store.duplicateSquare(id, placement: placement("disp-1", 300, 300)) }),
            ("Delete Square", { store.deleteSquare(store.squares[1].id) }),
            ("Move Square", { store.moveSquare(id, to: placement("disp-1", 500, 500)) }),
            ("Change Square Size", { store.setSquareSize(120) }),
            ("Change Opacity", { store.setOpacity(0.5) }),
            ("Change Copy Feedback", { store.setFeedbackMode(.burst) }),
            ("Change Copy Sound", { store.setPlaySound(false) }),
            ("Lock Positions", { store.setPositionsLocked(true) }),
            ("Unlock Positions", { store.setPositionsLocked(false) }),
            ("Hide Square", { store.setSquareHidden(id, true) }),
            ("Show Square", { store.setSquareHidden(id, false) }),
            ("Snap to Grid", { store.snapToGrid(displays: [Displays.one]) }),
        ]
        for (name, change) in changes {
            store.commitEdits()
            let before = store.document
            try change()
            let after = store.document
            #expect(after != before, "\(name) changed nothing")
            #expect(store.undoActionName == name)
            store.undo()
            #expect(store.document.squares == before.squares && store.document.preferences == before.preferences, "undo \(name)")
            #expect(store.redoActionName == name)
            store.redo()
            #expect(store.document.squares == after.squares && store.document.preferences == after.preferences, "redo \(name)")
        }
    }

    @Test func typingCoalescesIntoOneUndoStepUntilEditingEnds() {
        let store = makeStore()
        let id = store.squares[2].id
        let original = store.squares[2].text
        for text in ["c", "co", "cod", "code"] { store.updateText(id, to: text) }
        store.undo()
        #expect(store.square(id)?.text == original)
        #expect(!store.canUndo)

        store.updateText(id, to: "one")
        store.commitEdits()
        store.updateText(id, to: "two")
        store.undo()
        #expect(store.square(id)?.text == "one")
    }

    @Test func sizeSettingStaysWithinFortyToOneSixty() {
        let store = makeStore()
        #expect(store.preferences.squareSize == 70, "default is still 70 pt")
        store.setSquareSize(40)
        #expect(store.preferences.squareSize == 40)
        store.setSquareSize(30)
        #expect(store.preferences.squareSize == 40)
        store.setSquareSize(400)
        #expect(store.preferences.squareSize == 160)
    }

    @Test func sliderDragsCoalesceIntoOneStep() {
        let store = makeStore()
        for size in stride(from: 70.0, through: 160, by: 10) { store.setSquareSize(size) }
        #expect(store.preferences.squareSize == 160)
        store.undo()
        #expect(store.preferences.squareSize == 70)
    }

    @Test func undoKeepsHiddenStateAndLoginItemAndNeverTouchesTheClipboard() {
        let clipboard = FakeClipboard()
        let store = makeStore(clipboard: clipboard)
        store.setSquareSize(100)
        store.setSquaresHidden(true)
        store.undo()
        #expect(store.preferences.squareSize == 70)
        #expect(store.preferences.squaresHidden)
        #expect(clipboard.writes.isEmpty)
    }

    @Test func aNewChangeClearsRedo() {
        let store = makeStore()
        store.setOpacity(0.5)
        store.undo()
        #expect(store.canRedo)
        store.setPlaySound(false)
        #expect(!store.canRedo)
    }

    // MARK: Snap to Grid (Decision #40)

    @Test(arguments: [40.0, 70.0, 160.0])
    func gridCellsNeverOverlapAndSquaresStayOnTheirDisplay(_ size: Double) throws {
        guard case .loaded(var doc) = ConfigCodec.decode(try Fixture.data("cfg-two-display.v1.json")) else {
            Issue.record("fixture did not load")
            return
        }
        doc.preferences.positionsLocked = false
        doc.preferences.squareSize = size
        // Add a crowd of squares that all start on the same spot.
        for i in 0..<12 { doc.squares.append(Square(label: "\(i)", text: "t\(i)", placement: placement("disp-1", 10, 30))) }
        let store = makeStore(doc)
        #expect(store.snapToGrid(displays: Displays.pair))
        let step = size + GridLayout.gap
        var cells = Set<String>()
        for (before, after) in zip(doc.squares, store.squares) {
            #expect(after.placement.displayID == before.placement.displayID)
            let display = try #require(Displays.pair.first { $0.id == after.placement.displayID })
            let c = (after.placement.x - display.usable.minX) / step
            let r = (after.placement.y - display.usable.minY) / step
            #expect(c == c.rounded() && r == r.rounded(), "on a grid cell")
            #expect(after.placement.x + size <= display.usable.maxX && after.placement.y + size <= display.usable.maxY)
            #expect(cells.insert("\(display.id):\(c):\(r)").inserted, "no two squares share a cell")
        }
        store.undo()
        #expect(store.squares == doc.squares, "one undo restores every square")
    }

    @Test func gridIsUnavailableWhileLocked() {
        let store = makeStore()
        store.setPositionsLocked(true)
        let before = store.squares
        #expect(!store.snapToGrid(displays: [Displays.one]))
        #expect(store.squares == before)
    }

    @Test func gridLeavesSquaresOnAMissingDisplayAlone() {
        let squares = [Square(label: "C", text: "c", placement: placement("disp-2", 900, 60))]
        #expect(GridLayout.snap(squares, squareSize: 70, displays: [Displays.one]).isEmpty)
    }

    // MARK: Positioning and displays (Decisions #14, #15, #26)

    @Test func lockBlocksMovesButKeepsCoordinates() {
        let store = makeStore()
        let id = store.squares[0].id
        let original = store.squares[0].placement
        store.setPositionsLocked(true)
        store.moveSquare(id, to: placement("disp-1", 400, 400))
        #expect(store.square(id)?.placement == original)
        store.setPositionsLocked(false)
        store.moveSquare(id, to: placement("disp-2", 400, 400))
        #expect(store.square(id)?.placement == placement("disp-2", 400, 400))
    }

    @Test func savedDisplayAndPositionRestoreExactly() {
        let p = placement("disp-2", 900, 300)
        let r = PlacementResolver.resolve(p, squareSize: 70, displays: Displays.pair)
        #expect(r == ResolvedPlacement(displayID: "disp-2", origin: CGPoint(x: 900, y: 300), adjusted: false))
        // Arrangement swap does not matter: positions are display-relative.
        #expect(PlacementResolver.resolve(p, squareSize: 70, displays: Displays.pair.reversed()) == r)
    }

    @Test func missingDisplayFallsBackToTheMainDisplayAtTheSameRelativePosition() {
        let p = Placement(displayID: "disp-2", x: 960, y: 540, displayWidth: 1920, displayHeight: 1080)
        let r = PlacementResolver.resolve(p, squareSize: 70, displays: [Displays.one])
        #expect(r?.displayID == "disp-1")
        #expect(r?.origin == CGPoint(x: 756, y: 491))
        #expect(r?.adjusted == true)

        // Near the far corner: clamped fully on-screen.
        let corner = Placement(displayID: "disp-2", x: 1900, y: 1070, displayWidth: 1920, displayHeight: 1080)
        let c = PlacementResolver.resolve(corner, squareSize: 70, displays: [Displays.one])
        #expect(c?.origin == CGPoint(x: 1512 - 70, y: 982 - 70))

        // The stored placement is untouched, so the square returns when disp-2 reconnects.
        let store = makeStore(ConfigDocument(squares: [Square(label: "C", text: "c", placement: p)]))
        _ = PlacementResolver.resolve(store.squares[0].placement, squareSize: 70, displays: [Displays.one])
        #expect(store.squares[0].placement == p)
        #expect(PlacementResolver.resolve(p, squareSize: 70, displays: Displays.pair)?.displayID == "disp-2")

        // Moving the displaced square replaces the stored placement.
        let dropped = PlacementResolver.placementForDrop(origin: CGPoint(x: 100, y: 100), squareSize: 70, on: Displays.one)
        store.moveSquare(store.squares[0].id, to: dropped)
        #expect(store.squares[0].placement.displayID == "disp-1")
    }

    @Test func changedGeometryClampsOnTheSameDisplay() {
        let smaller = DisplayGeometry(id: "disp-2", size: CGSize(width: 1280, height: 720), usable: CGRect(x: 0, y: 0, width: 1280, height: 720), isMain: false)
        let r = PlacementResolver.resolve(placement("disp-2", 1800, 1000), squareSize: 160, displays: [Displays.one, smaller])
        #expect(r == ResolvedPlacement(displayID: "disp-2", origin: CGPoint(x: 1120, y: 560), adjusted: true))
    }

    @Test func dropsAreClampedToTheUsableArea() {
        let p = PlacementResolver.placementForDrop(origin: CGPoint(x: -30, y: 0), squareSize: 70, on: Displays.one)
        #expect(p.x == 0 && p.y == 24, "not under the menu bar")
    }

    @Test func duplicatesDoNotStackOnTheirSource() {
        let source = Square(label: "S", text: "s", placement: placement("disp-1", 100, 100))
        let p = NewSquarePlacement.forDuplicate(of: source, squareSize: 70, displays: [Displays.one])
        #expect(p.x != 100 || p.y != 100)
        let fresh = NewSquarePlacement.forNewSquare(existing: [], squareSize: 70, displays: [Displays.one])
        let second = NewSquarePlacement.forNewSquare(existing: [Square(label: "N", text: "", placement: fresh!)], squareSize: 70, displays: [Displays.one])
        #expect(fresh != second)
    }

    // MARK: History (Decision #43)

    @Test func seedTextsAreInHistoryOnFirstLaunch() {
        let doc = SeedData.document(main: Displays.one)
        #expect(Set(doc.history.map(\.text)) == Set(doc.squares.map(\.text)))
        #expect(doc.history.first?.label == "A", "newest first")
    }

    @Test func historyKeepsEditedAndDeletedTextsStoresEachTextOnceAndCanBeCleared() throws {
        var clock = Date(timeIntervalSince1970: 1_790_000_000)
        let store = YoinkStore(document: SeedData.document(main: Displays.one, now: clock), clipboard: FakeClipboard(), sound: FakeSound(), now: { clock })
        let c = store.squares[2]
        clock += 60
        store.updateText(c.id, to: "e")
        store.updateText(c.id, to: "edited-c")
        store.commitEdits()
        #expect(store.history.first?.text == "edited-c")
        #expect(!store.history.contains { $0.text == "e" }, "keystrokes are not history entries")
        #expect(store.history.contains { $0.text == c.text }, "old text kept")

        store.deleteSquare(store.squares[1].id)
        #expect(store.history.count == 6, "delete keeps entries")

        // Saving identical text refreshes the existing entry instead of adding one.
        clock += 60
        _ = try store.addSquare(label: "Z", text: "codex --yolo", placement: placement())
        #expect(store.history.filter { $0.text == "codex --yolo" }.count == 1)
        #expect(store.history.first?.label == "Z")
        #expect(store.history.first?.lastUsed == clock)

        // Undo does not add entries.
        let count = store.history.count
        store.undo()
        store.redo()
        #expect(store.history.count == count)

        // Copy and add-as-new-square from an entry.
        let entry = store.history.last!
        let clipboard = FakeClipboard()
        let other = YoinkStore(document: store.document, clipboard: clipboard, sound: FakeSound())
        #expect(other.copyHistoryEntry(entry.id))
        #expect(clipboard.writes == [entry.text])
        let added = try #require(other.addSquare(fromHistory: entry.id, placement: placement()))
        #expect(other.square(added)?.text == entry.text)

        store.removeHistoryEntry(entry.id)
        #expect(!store.history.contains { $0.id == entry.id })
        store.clearHistory()
        #expect(store.history.isEmpty)
    }

    // MARK: Launch at login (Decisions #19, #34)

    @Test func launchAtLoginSavesOnlyWhatMacOSReports() {
        let store = makeStore()
        let port = FakeLoginItem()
        #expect(store.applyLaunchAtLogin(true, port: port) == .enabled)
        #expect(store.preferences.launchAtLogin)

        port.result = .requiresApproval
        store.applyLaunchAtLogin(false, port: FakeLoginItem())
        #expect(store.applyLaunchAtLogin(true, port: port) == .requiresApproval)
        #expect(!store.preferences.launchAtLogin, "pending approval is not saved as on")

        port.state = .disabled
        store.syncLaunchAtLogin(from: port)
        #expect(!store.preferences.launchAtLogin)
        port.state = .enabled
        store.syncLaunchAtLogin(from: port)
        #expect(store.preferences.launchAtLogin)
    }
}
