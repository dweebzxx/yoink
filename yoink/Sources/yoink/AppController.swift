import AppKit
import YoinkCore

/// Owns the product store and every AppKit integration. Settings talks to this type.
@MainActor
final class AppController: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var storage: YoinkStore?
    /// Set once at launch, before any window or Settings view exists.
    var store: YoinkStore { storage! }
    private(set) var hotkeys: HotkeyCoordinator!
    let loginItem = LoginItemService()
    private let clipboard = PasteboardClipboard()
    private let sound = CopySoundPlayer()
    private let carbon = CarbonHotkeys()
    private var files: ConfigFileStore!
    private var lock: InstanceLock?
    private var squares: SquaresController!
    private var statusItem: NSStatusItem?
    private var settings: SettingsWindowController?
    private var saveWork: DispatchWorkItem?

    // MARK: Launch

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let directory = Self.configDirectory()
        files = ConfigFileStore(directory: directory)
        do {
            try files.ensureDirectory()
        } catch {
            NSLog("yo!nk: cannot create the configuration folder")
            NSApp.terminate(nil)
            return
        }
        guard let lock = InstanceLock(directory: directory) else {
            // Another yo!nk already owns this configuration. Never become a second writer.
            NSLog("yo!nk: another instance is using this configuration; quitting")
            NSApp.terminate(nil)
            return
        }
        self.lock = lock
        guard let document = loadDocument() else { return }

        storage = YoinkStore(document: document, clipboard: clipboard, sound: sound)
        hotkeys = HotkeyCoordinator(port: carbon, store: store)
        squares = SquaresController(app: self)
        carbon.onPress = { [weak self] id in self?.handleHotkey(id) }
        store.onChange = { [weak self] in self?.stateChanged() }
        store.syncLaunchAtLogin(from: loginItem)

        NSApp.mainMenu = MainMenu.make(appName: "yo!nk")
        installStatusItem()
        hotkeys.sync()
        squares.reconcile()

        NotificationCenter.default.addObserver(self, selector: #selector(screensChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)

        // Development and verification only: `--open-settings <tab>` opens Settings at launch
        // so the window can be checked without driving the mouse.
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--open-settings") {
            let tab = i + 1 < args.count ? SettingsTab(rawValue: args[i + 1]) : nil
            SettingsNavigation.shared.selectedTab = tab ?? .squares
            if tab == .squares { SettingsNavigation.shared.selectedSquareID = store.squares.first?.id }
            openSettings(selecting: nil)
        }
    }

    /// `--config-dir <path>` (or `YOINK_CONFIG_DIR`) points the app at an isolated folder for
    /// development and testing; otherwise the live `~/Library/Application Support/com.dweebzxx.yoink/`.
    static func configDirectory() -> URL {
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--config-dir"), i + 1 < args.count {
            return URL(fileURLWithPath: args[i + 1], isDirectory: true)
        }
        if let env = ProcessInfo.processInfo.environment["YOINK_CONFIG_DIR"], !env.isEmpty {
            return URL(fileURLWithPath: env, isDirectory: true)
        }
        return ConfigFileStore.defaultDirectory()
    }

    private func loadDocument() -> ConfigDocument? {
        switch files.load() {
        case .loaded(let document):
            return document
        case .notFound:
            return writeSeeds()
        case .corrupt:
            return recoverFromUnreadableFile()
        }
    }

    private func writeSeeds() -> ConfigDocument? {
        // With no display attached (rare, e.g. headless at login) seed against a nominal
        // display; squares are placed on the real main display once one appears.
        let main = NSScreen.screens.first.map(ScreenMap.geometry(for:))
            ?? DisplayGeometry(id: "none", size: CGSize(width: 1440, height: 900), usable: CGRect(x: 0, y: 25, width: 1440, height: 875), isMain: true)
        let seeds = SeedData.document(main: main)
        do { try files.save(seeds) } catch { NSLog("yo!nk: saving the configuration failed") }
        return seeds
    }

    /// Decision #28: write nothing, one alert, three choices. The alert never shows snippet text.
    private func recoverFromUnreadableFile() -> ConfigDocument? {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "yo!nk can't read its saved squares"
        alert.informativeText = "The saved configuration is damaged or was made by a newer version of yo!nk. Nothing has been changed.\n\nStart Fresh keeps the unreadable file as a dated backup in the same folder and starts over with the sample squares."
        alert.addButton(withTitle: "Quit")
        alert.addButton(withTitle: "Show in Finder")
        alert.addButton(withTitle: "Start Fresh")
        switch alert.runModal() {
        case .alertSecondButtonReturn:
            NSWorkspace.shared.activateFileViewerSelecting([files.fileURL])
            NSApp.terminate(nil)
            return nil
        case .alertThirdButtonReturn:
            do {
                try files.backUpUnreadableFile()
            } catch {
                NSLog("yo!nk: could not back up the unreadable configuration")
                NSApp.terminate(nil)
                return nil
            }
            return writeSeeds()
        default:
            NSApp.terminate(nil)
            return nil
        }
    }

    // MARK: State changes and saving

    private func stateChanged() {
        squares.reconcile()
        hotkeys.sync()
        scheduleSave()
    }

    /// Coalesced safe write so typing in Settings does not rewrite the file on every keystroke.
    private func scheduleSave() {
        saveWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.saveNow() }
        saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    func saveNow() {
        saveWork?.cancel()
        saveWork = nil
        guard let storage else { return }
        do {
            try files.save(storage.document)
        } catch {
            // The previous valid file stays in place and in-memory state is kept.
            NSLog("yo!nk: saving the configuration failed")
        }
    }

    /// Settings close and quit: end the current edit (History) and write immediately.
    func flush() {
        guard storage != nil else { return }
        store.commitEdits()
        saveNow()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        flush()
        return .terminateNow
    }

    @objc private func screensChanged() {
        squares?.reconcile()
    }

    // MARK: Actions

    func copy(_ id: UUID) {
        if case .copied(let mode) = store.copy(squareID: id) {
            squares.presentFeedback(mode, for: id)
        }
    }

    private func handleHotkey(_ id: UInt32) {
        switch hotkeys.action(forHotkeyID: id) {
        case .copy(let squareID): copy(squareID)
        case .toggleHidden: toggleHidden()
        case .snapToGrid: snapToGrid()
        case nil: break
        }
    }

    @objc func toggleHidden() {
        store.setSquaresHidden(!store.preferences.squaresHidden)
    }

    @objc func snapToGrid() {
        store.snapToGrid(displays: ScreenMap.displays)
    }

    @objc func undoLatest() {
        store.undo()
    }

    @objc func openSettingsFromMenu() {
        openSettings(selecting: nil)
    }

    func openSettings(selecting squareID: UUID?) {
        if let squareID {
            SettingsNavigation.shared.selectedTab = .squares
            SettingsNavigation.shared.selectedSquareID = squareID
        }
        if settings == nil {
            settings = SettingsWindowController(app: self) { [weak self] in
                self?.flush()
                self?.settings = nil
            }
        }
        settings?.present()
    }

    @discardableResult
    func addSquare(label: String, text: String) throws(LabelError) -> UUID? {
        guard let placement = NewSquarePlacement.forNewSquare(existing: store.squares, squareSize: store.preferences.squareSize, displays: ScreenMap.displays) else { return nil }
        return try store.addSquare(label: label, text: text, placement: placement)
    }

    @discardableResult
    func addSquare(fromHistory entryID: UUID) -> UUID? {
        guard let placement = NewSquarePlacement.forNewSquare(existing: store.squares, squareSize: store.preferences.squareSize, displays: ScreenMap.displays) else { return nil }
        return store.addSquare(fromHistory: entryID, placement: placement)
    }

    @discardableResult
    func duplicate(_ id: UUID) -> UUID? {
        guard let source = store.square(id) else { return nil }
        let placement = NewSquarePlacement.forDuplicate(of: source, squareSize: store.preferences.squareSize, displays: ScreenMap.displays)
        return store.duplicateSquare(id, placement: placement)
    }

    /// Returns a message when the shortcut is refused; the previous value is kept.
    func assignShortcut(_ shortcut: KeyShortcut?, to owner: ShortcutOwner) -> String? {
        do {
            try hotkeys.assign(shortcut, to: owner)
            return nil
        } catch {
            switch error {
            case .usedBy(let other): return "Already used by \(ownerName(other))."
            case .cannotRegister: return "macOS couldn't set this shortcut. It may be used by another app."
            }
        }
    }

    func ownerName(_ owner: ShortcutOwner) -> String {
        switch owner {
        case .square(let id): "square “\(store.square(id)?.label ?? "?")”"
        case .hideShowAll: "Hide/Show All Squares"
        case .snapToGrid: "Snap to Grid"
        }
    }

    func beginRecordingShortcut() { hotkeys.suspend() }
    func endRecordingShortcut() { hotkeys.resume() }

    // MARK: Menu bar (Decision #23)

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = Art.menuBarIcon
        item.button?.toolTip = "yo!nk"
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        statusItem = item
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        menu.autoenablesItems = false
        let prefs = store.preferences
        menu.addItem(menuItem("Settings…", #selector(openSettingsFromMenu), key: ","))
        menu.addItem(.separator())
        menu.addItem(menuItem(prefs.squaresHidden ? "Show All Squares" : "Hide All Squares", #selector(toggleHidden), shortcut: prefs.hideShowShortcut))
        let snap = menuItem("Snap to Grid", #selector(snapToGrid), shortcut: prefs.snapShortcut)
        snap.isEnabled = !prefs.positionsLocked
        menu.addItem(snap)
        let undo = menuItem(store.undoActionName.map { "Undo \($0)" } ?? "Undo", #selector(undoLatest))
        undo.isEnabled = store.canUndo
        menu.addItem(undo)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit yo!nk", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
    }

    private func menuItem(_ title: String, _ action: Selector, key: String = "", shortcut: KeyShortcut? = nil) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        if let shortcut {
            // Shown as a hint only; the global hotkey does the work.
            item.toolTip = ShortcutFormatter.string(for: shortcut)
            item.title = "\(title)    \(ShortcutFormatter.string(for: shortcut))"
        }
        return item
    }
}

/// Standard application, Edit, and Window menus. Even without a visible menu bar they give
/// Settings text fields ⌘X, ⌘C, ⌘V, ⌘Z, ⌘A, plus ⌘W and ⌘, (architecture spec).
@MainActor
enum MainMenu {
    static func make(appName: String) -> NSMenu {
        let main = NSMenu()

        let appMenu = NSMenu()
        appMenu.addItem(NSMenuItem(title: "About \(appName)", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: ""))
        appMenu.addItem(.separator())
        let settings = NSMenuItem(title: "Settings…", action: #selector(AppController.openSettingsFromMenu), keyEquivalent: ",")
        appMenu.addItem(settings)
        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(title: "Quit \(appName)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        main.addItem(submenu(appMenu, title: appName))

        let edit = NSMenu(title: "Edit")
        edit.addItem(NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z"))
        let redo = NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        edit.addItem(redo)
        edit.addItem(.separator())
        edit.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        edit.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        edit.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        edit.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        main.addItem(submenu(edit, title: "Edit"))

        let window = NSMenu(title: "Window")
        window.addItem(NSMenuItem(title: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w"))
        window.addItem(NSMenuItem(title: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m"))
        main.addItem(submenu(window, title: "Window"))
        NSApp.windowsMenu = window
        return main
    }

    private static func submenu(_ menu: NSMenu, title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.submenu = menu
        return item
    }
}
