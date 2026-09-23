import CoreGraphics
import Foundation
import Testing
@testable import YoinkCore

@MainActor
@Suite("State, labels, and seeds")
struct StateTests {
    @Test func seedsMatchTheMVPTableWithApprovedDefaults() {
        let doc = SeedData.document(main: Displays.one)
        #expect(doc.squares.map(\.label) == ["S", "O", "C", "CL", "A"])
        #expect(doc.squares[4].text == Fixture.seedA)
        #expect(doc.squares[4].text.split(separator: "\n", omittingEmptySubsequences: false).count == 2)
        #expect(Set(doc.squares.map(\.id)).count == 5)
        let p = doc.preferences
        #expect(p.squareSize == 70 && p.opacity == 0.85 && p.playSound && p.feedbackMode == .checkmark)
        #expect(!p.positionsLocked && !p.launchAtLogin && !p.squaresHidden)
        #expect(p.hideShowShortcut == .defaultHideShowAll && p.snapShortcut == .defaultSnapToGrid)
        #expect(doc.squares.allSatisfy { $0.shortcut == nil })
        // Seeds are on-screen on the main display and do not overlap.
        for square in doc.squares {
            let r = PlacementResolver.resolve(square.placement, squareSize: 70, displays: [Displays.one])
            #expect(r?.adjusted == false)
        }
    }

    @Test(arguments: ["S", "C1", "CL", ">", "//", "$", "Aa", "e\u{301}1", "🙂", "🙂🚀", "👩‍💻"])
    func acceptedLabels(_ label: String) {
        #expect(LabelRules.validate(label) == nil)
    }

    @Test func rejectedLabels() {
        #expect(LabelRules.validate("CL1") == .tooLong)
        #expect(LabelRules.validate("") == .empty)
        #expect(LabelRules.validate("  ") == .onlySpaces)
        #expect(LabelRules.validate(" ") == .onlySpaces)
    }

    @Test func addEditDuplicateDelete() throws {
        let store = makeStore()
        let id = try store.addSquare(label: "M1", text: Fixture.multiBlank, placement: placement())
        #expect(store.square(id)?.text == Fixture.multiBlank)

        try store.updateLabel(id, to: "M2")
        store.updateText(id, to: Fixture.multiTrailing)
        #expect(store.square(id)?.label == "M2")
        #expect(store.square(id)?.text == Fixture.multiTrailing)

        #expect(throws: LabelError.tooLong) { try store.updateLabel(id, to: "CL1") }
        #expect(store.square(id)?.label == "M2")

        let copy = try #require(store.duplicateSquare(id, placement: placement("disp-1", 120, 120)))
        #expect(copy != id)
        #expect(store.square(copy)?.label == "M2" && store.square(copy)?.text == Fixture.multiTrailing)
        #expect(store.square(copy)?.shortcut == nil)

        store.deleteSquare(id)
        #expect(store.square(id) == nil)
        #expect(store.square(copy) != nil)
        #expect(store.squares.count == 6)
    }

    @Test func duplicateLabelsAreAllowedAndDoNotAffectBehavior() throws {
        let clipboard = FakeClipboard()
        let store = makeStore(clipboard: clipboard)
        let a = try store.addSquare(label: "C", text: "first", placement: placement())
        let b = try store.addSquare(label: "C", text: "second", placement: placement("disp-1", 200, 200))
        _ = store.copy(squareID: b)
        _ = store.copy(squareID: a)
        #expect(clipboard.writes == ["second", "first"])
    }

    @Test func addRejectsInvalidLabel() {
        let store = makeStore()
        #expect(throws: LabelError.empty) { try store.addSquare(label: "", text: "x", placement: placement()) }
        #expect(store.squares.count == 5)
    }

    @Test func searchMatchesLabelOrTextCaseInsensitively() {
        let squares = SeedData.document(main: Displays.one).squares
        #expect(SquareSearch.filter(squares, query: "cl").map(\.label) == ["CL"])
        #expect(SquareSearch.filter(squares, query: "YOLO").map(\.label) == ["C"])
        #expect(SquareSearch.filter(squares, query: "agy").map(\.label) == ["A"])
        #expect(SquareSearch.filter(squares, query: "  ").count == 5)
        #expect(SquareSearch.filter(squares, query: "zzz").isEmpty)
    }

    @Test func coreHasNoAppKitProcessOrNetworkAPIs() throws {
        // Decisions #3, #10, SC12, SC14: Core never imports AppKit, runs processes, opens URLs, or uses the network.
        let coreDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../../Sources/YoinkCore").standardized
        let files = try FileManager.default.contentsOfDirectory(at: coreDir, includingPropertiesForKeys: nil).filter { $0.pathExtension == "swift" }
        #expect(files.count >= 5)
        let forbidden = ["import AppKit", "import SwiftUI", "Process(", "NSTask", "posix_spawn", "system(", "URLSession", "NSWorkspace", "open(URL", "print("]
        for file in files {
            let source = try String(contentsOf: file, encoding: .utf8)
            for token in forbidden {
                #expect(!source.contains(token), "\(file.lastPathComponent) contains \(token)")
            }
        }
    }
}
