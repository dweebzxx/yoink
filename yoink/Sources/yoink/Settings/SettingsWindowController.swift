import AppKit
import SwiftUI
import YoinkCore

/// The Settings window: an AppKit window hosting SwiftUI content (Decision #45). The app
/// shows a Dock icon and a ⌘-Tab entry only while it is open (Decision #23).
@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private unowned let app: AppController
    private let onClose: () -> Void

    init(app: AppController, onClose: @escaping () -> Void) {
        self.app = app
        self.onClose = onClose
        let window = SettingsWindow(
            contentRect: NSRect(x: 0, y: 0, width: 820, height: 580),
            styleMask: [.titled, .closable, .resizable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.store = app.store
        super.init(window: window)
        window.title = "yo!nk Settings"
        // One continuous surface: transparent title bar, no toolbar band or separator line.
        // The title stays set for the Window menu and Mission Control.
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.isMovableByWindowBackground = true
        window.isRestorable = false
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 760, height: 520)
        window.delegate = self
        window.contentViewController = NSHostingController(rootView: SettingsView(app: app))
        window.setContentSize(NSSize(width: 820, height: 580))
        window.center()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// Opening Settings is the one intentional activation: regular policy, activate, bring forward.
    func present() {
        NSApp.setActivationPolicy(.regular)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        window?.makeFirstResponder(nil) // ends shortcut recording
        app.endRecordingShortcut()      // never leave global shortcuts paused
        onClose()
        NSApp.setActivationPolicy(.accessory)
    }

    /// Text views register nothing here, so ⌘Z reaches the window's Core-backed undo.
    func windowWillReturnUndoManager(_ window: NSWindow) -> UndoManager? {
        (window as? SettingsWindow)?.silentUndoManager
    }
}

/// Routes ⌘Z / ⇧⌘Z to the Core undo history (Decision #41).
final class SettingsWindow: NSWindow {
    weak var store: YoinkStore?
    let silentUndoManager: UndoManager = {
        let manager = UndoManager()
        manager.disableUndoRegistration()
        return manager
    }()

    @objc func undo(_ sender: Any?) {
        makeFirstResponder(nil) // end the current text edit so it is one step
        store?.undo()
    }

    @objc func redo(_ sender: Any?) {
        store?.redo()
    }

    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(SettingsWindow.undo(_:)):
            menuItem.title = store?.undoActionName.map { "Undo \($0)" } ?? "Undo"
            return store?.canUndo ?? false
        case #selector(SettingsWindow.redo(_:)):
            menuItem.title = store?.redoActionName.map { "Redo \($0)" } ?? "Redo"
            return store?.canRedo ?? false
        default:
            return super.validateMenuItem(menuItem)
        }
    }
}

enum SettingsTab: String, CaseIterable, Identifiable {
    case squares, appearance, interaction, history, general, about

    var id: Self { self }

    var title: String {
        switch self {
        case .squares: "Squares"
        case .appearance: "Appearance"
        case .interaction: "Interaction"
        case .history: "History"
        case .general: "General"
        case .about: "About"
        }
    }

    var systemImage: String {
        switch self {
        case .squares: "square.grid.2x2"
        case .appearance: "paintbrush"
        case .interaction: "cursorarrow.click"
        case .history: "clock.arrow.circlepath"
        case .general: "gearshape"
        case .about: "info.circle"
        }
    }
}

@MainActor
@Observable
final class SettingsNavigation {
    static let shared = SettingsNavigation()
    var selectedTab: SettingsTab? = .squares
    var selectedSquareID: UUID?
    private init() {}
}

struct SettingsView: View {
    let app: AppController
    @State private var navigation = SettingsNavigation.shared

    private var activeTab: SettingsTab { navigation.selectedTab ?? .squares }

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                List(selection: $navigation.selectedTab) {
                    ForEach(SettingsTab.allCases) { tab in
                        Label(tab.title, systemImage: tab.systemImage).tag(tab)
                    }
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)
                .padding(.top, 40) // room for the window buttons
                Text(AboutPane.versionString)
                    .font(.footnote)
                    .fontDesign(.monospaced)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
            }
            .frame(width: 200)
            .background(SidebarMaterial())
            VStack(alignment: .leading, spacing: 0) {
                Text(activeTab.title)
                    .font(.title2.weight(.semibold))
                    .padding(.horizontal, 24)
                    .padding(.top, 14)
                    .padding(.bottom, 6)
                Group {
                    switch activeTab {
                    case .squares: SquaresPane(app: app)
                    case .appearance: AppearancePane(store: app.store)
                    case .interaction: InteractionPane(app: app)
                    case .history: HistoryPane(app: app)
                    case .general: GeneralPane(app: app)
                    case .about: AboutPane()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .ignoresSafeArea(.container, edges: .top)
        .frame(minWidth: 760, minHeight: 520)
    }
}

/// The translucent sidebar material behind the tab list.
struct SidebarMaterial: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .sidebar
        view.blendingMode = .behindWindow
        view.state = .followsWindowActiveState
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}

extension View {
    /// Grouped form styling from the macos-settings-ui skill.
    func settingsForm() -> some View {
        formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .contentMargins(.top, 8, for: .scrollContent)
    }
}
