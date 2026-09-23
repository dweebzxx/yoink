import AppKit
import SwiftUI
import YoinkCore

// MARK: Squares (Decisions #17, #37, #40, #42)

struct SquaresPane: View {
    let app: AppController
    @State private var navigation = SettingsNavigation.shared
    @State private var query = ""
    @State private var addingSquare = false

    var body: some View {
        let store = app.store
        let visible = SquareSearch.filter(store.squares, query: query)
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                TextField("Search label or text", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .padding(8)
                List(selection: $navigation.selectedSquareID) {
                    ForEach(visible) { square in
                        HStack(spacing: 8) {
                            LabelBadge(label: square.label)
                            Text(firstLine(square.text))
                                .font(.system(.callout, design: .monospaced))
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .foregroundStyle(square.text.isEmpty ? .secondary : .primary)
                        }
                        .tag(square.id)
                        .contextMenu {
                            Button("Duplicate") { select(app.duplicate(square.id)) }
                            Button("Delete") { delete(square.id) }
                        }
                    }
                }
                .listStyle(.inset)
                .overlay {
                    if visible.isEmpty {
                        Text(query.isEmpty ? "No squares" : "No matches").foregroundStyle(.secondary)
                    }
                }
                Divider()
                HStack(spacing: 4) {
                    Button { addingSquare = true } label: { Image(systemName: "plus") }
                        .help("Add Square")
                    Button { if let id = navigation.selectedSquareID { delete(id) } } label: { Image(systemName: "minus") }
                        .help("Delete Square")
                        .disabled(navigation.selectedSquareID == nil)
                    Button { if let id = navigation.selectedSquareID { select(app.duplicate(id)) } } label: { Image(systemName: "plus.square.on.square") }
                        .help("Duplicate Square")
                        .disabled(navigation.selectedSquareID == nil)
                    Spacer()
                    Button("Snap to Grid") { app.snapToGrid() }
                        .disabled(store.preferences.positionsLocked)
                        .help(store.preferences.positionsLocked ? "Unlock positions to snap squares to the grid" : "Line up every square on its own display")
                }
                .buttonStyle(.borderless)
                .padding(8)
            }
            .frame(width: 260)
            Divider()
            if let id = navigation.selectedSquareID, store.square(id) != nil {
                SquareEditor(app: app, squareID: id).id(id)
            } else {
                Text("Select a square to edit it.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sheet(isPresented: $addingSquare) {
            AddSquareSheet(app: app) { select($0) }
        }
        .onChange(of: navigation.selectedSquareID) { _, _ in store.commitEdits() }
    }

    private func firstLine(_ text: String) -> String {
        let first = text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).first.map(String.init) ?? ""
        return text.contains(where: \.isNewline) ? first + " …" : first
    }

    private func select(_ id: UUID?) {
        if let id { navigation.selectedSquareID = id }
    }

    private func delete(_ id: UUID) {
        if navigation.selectedSquareID == id { navigation.selectedSquareID = nil }
        app.store.deleteSquare(id)
    }
}

struct SquareEditor: View {
    let app: AppController
    let squareID: UUID
    @State private var labelDraft = ""
    @State private var labelError: LabelError?

    var body: some View {
        let store = app.store
        let square = store.square(squareID)
        Form {
            Section {
                LabeledContent("Label") {
                    VStack(alignment: .trailing, spacing: 4) {
                        TextField("", text: $labelDraft, prompt: Text("1–2 characters"))
                            .textFieldStyle(.roundedBorder)
                            .autocorrectionDisabled()
                            .multilineTextAlignment(.center)
                            .frame(width: 80)
                            .onSubmit { revertInvalidLabel() }
                        if let labelError {
                            Text(labelError.message).font(.caption).foregroundStyle(.red)
                        }
                    }
                }
                ShortcutField(title: "Shortcut", app: app, owner: .square(squareID))
            } footer: {
                Text("The shortcut copies this square from any app.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Text") {
                SnippetTextEditor(text: Binding(
                    get: { store.square(squareID)?.text ?? "" },
                    set: { store.updateText(squareID, to: $0) }
                ), onCommit: { store.commitEdits() })
                .frame(minHeight: 200)
            }
        }
        .settingsForm()
        .onAppear { labelDraft = square?.label ?? "" }
        .onChange(of: labelDraft) { _, draft in
            labelError = LabelRules.validate(draft)
            if labelError == nil { try? store.updateLabel(squareID, to: draft) }
        }
        .onChange(of: square?.label) { _, label in
            // Undo/redo changed the label: show it unless the user is mid-way through a fix.
            if let label, labelError == nil, label != labelDraft { labelDraft = label }
        }
        .onDisappear { revertInvalidLabel() }
    }

    private func revertInvalidLabel() {
        guard labelError != nil, let label = app.store.square(squareID)?.label else { return }
        labelDraft = label
        labelError = nil
    }
}

struct AddSquareSheet: View {
    let app: AppController
    let onAdded: (UUID?) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var label = ""
    @State private var text = ""

    var body: some View {
        let error = LabelRules.validate(label)
        VStack(alignment: .leading, spacing: 12) {
            Text("Add Square").font(.headline)
            LabeledContent("Label") {
                TextField("", text: $label, prompt: Text("1–2 characters"))
                    .autocorrectionDisabled()
                    .frame(width: 80)
            }
            if !label.isEmpty, let error {
                Text(error.message).font(.caption).foregroundStyle(.red)
            }
            Text("Text").font(.subheadline)
            SnippetTextEditor(text: $text, onCommit: {})
                .frame(width: 420, height: 160)
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Add") {
                    let id = try? app.addSquare(label: label, text: text)
                    onAdded(id)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(error != nil)
            }
        }
        .padding(20)
    }
}

// MARK: Appearance (Decisions #13, #24, #36)

struct AppearancePane: View {
    let store: YoinkStore

    var body: some View {
        Form {
            Section {
                LabeledContent("Square size") {
                    HStack(spacing: 12) {
                        Slider(value: Binding(get: { store.preferences.squareSize }, set: { store.setSquareSize($0) }),
                               in: Preferences.sizeRange) { editing in if !editing { store.commitEdits() } }
                            .frame(width: 220)
                        Text("\(Int(store.preferences.squareSize)) pt").monospacedDigit().foregroundStyle(.secondary).frame(width: 52, alignment: .trailing)
                    }
                }
                LabeledContent("Opacity") {
                    HStack(spacing: 12) {
                        Slider(value: Binding(get: { store.preferences.opacity }, set: { store.setOpacity($0) }),
                               in: Preferences.opacityRange) { editing in if !editing { store.commitEdits() } }
                            .frame(width: 220)
                        Text("\(Int((store.preferences.opacity * 100).rounded()))%").monospacedDigit().foregroundStyle(.secondary).frame(width: 52, alignment: .trailing)
                    }
                }
            } footer: {
                Text("Size and opacity apply to every square.").font(.caption).foregroundStyle(.secondary)
            }
        }
        .settingsForm()
    }
}

// MARK: Interaction (Decisions #11, #14, #25, #33, #38, #40)

struct InteractionPane: View {
    let app: AppController

    var body: some View {
        let store = app.store
        Form {
            Section("When a square is copied") {
                Picker("Visual feedback", selection: Binding(get: { store.preferences.feedbackMode }, set: { store.setFeedbackMode($0) })) {
                    Text("Checkmark").tag(FeedbackMode.checkmark)
                    Text("Burst").tag(FeedbackMode.burst)
                    Text("None").tag(FeedbackMode.none)
                }
                .pickerStyle(.segmented)
                Toggle("Play sound on copy", isOn: Binding(get: { store.preferences.playSound }, set: { store.setPlaySound($0) }))
                    .toggleStyle(.switch)
            }
            Section {
                Toggle(isOn: Binding(get: { store.preferences.positionsLocked }, set: { store.setPositionsLocked($0) })) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Lock positions")
                        Text("Squares can't be dragged. Hover and click-to-copy still work.").font(.caption).foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)
            }
            Section("App shortcuts") {
                ShortcutField(title: "Hide/Show All Squares", app: app, owner: .hideShowAll)
                ShortcutField(title: "Snap to Grid", app: app, owner: .snapToGrid)
            }
        }
        .settingsForm()
    }
}

// MARK: History (Decision #43)

struct HistoryPane: View {
    let app: AppController
    @State private var confirmingClear = false

    var body: some View {
        let store = app.store
        VStack(spacing: 0) {
            if store.history.isEmpty {
                Text("No snippet history").foregroundStyle(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(store.history) { entry in
                        HStack(alignment: .top, spacing: 10) {
                            LabelBadge(label: entry.label)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(entry.text.isEmpty ? "(empty)" : entry.text)
                                    .font(.system(.callout, design: .monospaced))
                                    .lineLimit(4)
                                    .textSelection(.enabled)
                                Text(entry.lastUsed, format: .dateTime.year().month().day().hour().minute())
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button { store.copyHistoryEntry(entry.id) } label: { Image(systemName: "doc.on.doc") }
                                .help("Copy")
                            Button { selectNew(app.addSquare(fromHistory: entry.id)) } label: { Image(systemName: "plus.square") }
                                .help("Add as New Square")
                            Button { store.removeHistoryEntry(entry.id) } label: { Image(systemName: "trash") }
                                .help("Remove from History")
                        }
                        .buttonStyle(.borderless)
                        .padding(.vertical, 2)
                    }
                }
                .listStyle(.inset)
            }
            Divider()
            HStack {
                Text("History keeps every text used in a square, on this Mac only.").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Clear History…") { confirmingClear = true }.disabled(store.history.isEmpty)
            }
            .padding(10)
        }
        .confirmationDialog("Clear all snippet history?", isPresented: $confirmingClear) {
            Button("Clear History", role: .destructive) { store.clearHistory() }
        } message: {
            Text("This can't be undone. Your squares are not affected.")
        }
    }

    private func selectNew(_ id: UUID?) {
        guard let id else { return }
        SettingsNavigation.shared.selectedSquareID = id
        SettingsNavigation.shared.selectedTab = .squares
    }
}

// MARK: General (Decisions #19, #34)

struct GeneralPane: View {
    let app: AppController
    @State private var state: LoginItemState = .disabled

    var body: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: Binding(get: { state == .enabled }, set: { on in
                    state = app.store.applyLaunchAtLogin(on, port: app.loginItem)
                }))
                .toggleStyle(.switch)
                if state == .requiresApproval {
                    HStack {
                        Text("Approve yo!nk in System Settings › General › Login Items.").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button("Open Login Items") { app.loginItem.openSystemSettings() }
                    }
                }
            }
        }
        .settingsForm()
        .onAppear {
            state = app.loginItem.state
            app.store.syncLaunchAtLogin(from: app.loginItem)
        }
    }
}

// MARK: About

struct AboutPane: View {
    static var versionString: String {
        let info = Bundle.main.infoDictionary
        return "Version \(info?["CFBundleShortVersionString"] as? String ?? "1.0")"
    }

    var body: some View {
        Form {
            Section {
                VStack(spacing: 8) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 96, height: 96)
                    Text("yo!nk").font(.system(size: 28, weight: .heavy, design: .rounded))
                    Text(Self.versionString).foregroundStyle(.secondary).monospacedDigit()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            Section {
                LabeledContent("What it does", value: "Hover to read, click to copy.")
                LabeledContent("Privacy", value: "Everything stays on your Mac.")
            }
            Section {
                Text("© 2026 dweebzxx")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .settingsForm()
    }
}
