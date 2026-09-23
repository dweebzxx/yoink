import AppKit
import YoinkCore

/// Keeps one square window per saved square in step with the store, and handles hover,
/// click, drag, context menu, and feedback presentation.
@MainActor
final class SquaresController: NSObject, SquareViewDelegate, NSMenuDelegate {
    private unowned let app: AppController
    private var panels: [UUID: (panel: SquarePanel, view: SquareView)] = [:]
    private let preview = PreviewController()
    private let drag = DragAnimation()
    private var hoverWork: DispatchWorkItem?
    private var hoveredID: UUID?

    static let hoverDelay: TimeInterval = 0.2

    init(app: AppController) {
        self.app = app
    }

    private var reduceMotion: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

    /// Applies the current state: creates, updates, places, hides, or closes square windows.
    /// Placement comes only from the configuration document (resolved with Decision #26).
    func reconcile() {
        let store = app.store
        let prefs = store.preferences
        let size = CGFloat(prefs.squareSize)
        let displays = ScreenMap.displays
        var seen = Set<UUID>()
        for square in store.squares {
            seen.insert(square.id)
            let entry = panels[square.id] ?? makePanel(for: square.id, size: size)
            entry.view.configure(label: square.label, text: square.text, locked: prefs.positionsLocked, opacity: CGFloat(prefs.opacity))
            if !entry.view.isDragging,
               let resolved = PlacementResolver.resolve(square.placement, squareSize: prefs.squareSize, displays: displays),
               let screen = ScreenMap.screen(withID: resolved.displayID) {
                let frame = ScreenMap.frame(origin: resolved.origin, size: size, on: screen)
                if entry.panel.frame != frame { entry.panel.setFrame(frame, display: true) }
            }
            if prefs.squaresHidden {
                entry.panel.orderOut(nil)
            } else if !entry.panel.isVisible {
                entry.panel.orderFrontRegardless()
            }
        }
        for (id, entry) in panels where !seen.contains(id) {
            if hoveredID == id { hidePreview() }
            entry.panel.orderOut(nil)
            entry.panel.close()
            panels[id] = nil
        }
        if prefs.squaresHidden { hidePreview() }
    }

    private func makePanel(for id: UUID, size: CGFloat) -> (panel: SquarePanel, view: SquareView) {
        let panel = SquarePanel(size: size)
        let view = SquareView(squareID: id, size: size)
        view.delegate = self
        panel.contentView = view
        let entry = (panel, view)
        panels[id] = entry
        return entry
    }

    // MARK: Feedback

    func presentFeedback(_ mode: FeedbackMode, for id: UUID) {
        guard let entry = panels[id], entry.panel.isVisible else { return }
        switch mode {
        case .checkmark: entry.view.showCheckmark(shake: !reduceMotion)
        case .burst: BurstEffect.play(around: entry.panel.frame, reduceMotion: reduceMotion)
        case .none: break
        }
    }

    // MARK: SquareViewDelegate

    func squareHover(_ view: SquareView, inside: Bool) {
        hoverWork?.cancel()
        guard inside, !view.isDragging else {
            if hoveredID == view.squareID || !inside { hidePreview() }
            return
        }
        hoveredID = view.squareID
        let work = DispatchWorkItem { [weak self, weak view] in
            guard let self, let view, self.hoveredID == view.squareID, !view.isDragging,
                  let panel = view.window, panel.isVisible,
                  let text = self.app.store.square(view.squareID)?.text,
                  let screen = panel.screen ?? NSScreen.screens.first else { return }
            self.preview.show(text: text, beside: panel.frame, on: screen)
        }
        hoverWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.hoverDelay, execute: work)
    }

    private func hidePreview() {
        hoverWork?.cancel()
        hoveredID = nil
        preview.hide()
    }

    func squarePressBegan(_ view: SquareView) {
        hoverWork?.cancel()
    }

    func squareDragBegan(_ view: SquareView) {
        hidePreview()
        guard let panel = view.window else { return }
        drag.start(on: panel, label: view.label, opacity: view.opacity, reduceMotion: reduceMotion)
    }

    func squareDragEnded(_ view: SquareView) {
        drag.stop()
        guard let panel = view.window, let located = ScreenMap.locate(panel.frame) else { return }
        let geometry = ScreenMap.geometry(for: located.screen)
        let placement = PlacementResolver.placementForDrop(origin: located.origin, squareSize: Double(panel.frame.width), on: geometry)
        app.store.moveSquare(view.squareID, to: placement)
        reconcile()
    }

    func squareClicked(_ view: SquareView) {
        hidePreview()
        app.copy(view.squareID)
    }

    // MARK: Right-click menu (Decision #39). Never copies.

    private var menuSquareID: UUID?

    func squareContextMenu(_ view: SquareView, event: NSEvent) {
        hidePreview()
        menuSquareID = view.squareID
        let locked = app.store.preferences.positionsLocked
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.addItem(item("Edit…", #selector(menuEdit)))
        menu.addItem(item("Duplicate", #selector(menuDuplicate)))
        menu.addItem(item("Delete", #selector(menuDelete)))
        menu.addItem(.separator())
        menu.addItem(item(locked ? "Unlock Positions" : "Lock Positions", #selector(menuToggleLock)))
        menu.addItem(item("Hide All Squares", #selector(menuHideAll)))
        NSMenu.popUpContextMenu(menu, with: event, for: view)
    }

    private func item(_ title: String, _ action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    @objc private func menuEdit() {
        if let id = menuSquareID { app.openSettings(selecting: id) }
    }

    @objc private func menuDuplicate() {
        if let id = menuSquareID { app.duplicate(id) }
    }

    @objc private func menuDelete() {
        if let id = menuSquareID { app.store.deleteSquare(id) }
    }

    @objc private func menuToggleLock() {
        app.store.setPositionsLocked(!app.store.preferences.positionsLocked)
    }

    @objc private func menuHideAll() {
        app.store.setSquaresHidden(true)
    }
}
