import AppKit
import SwiftUI
import YoinkCore

/// Multiline snippet editor that keeps the text exactly as typed or pasted: plain text only,
/// every automatic substitution off, and no private undo (⌘Z goes to the Core history).
struct SnippetTextEditor: NSViewRepresentable {
    @Binding var text: String
    var onCommit: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSTextView.scrollableTextView()
        scroll.borderType = .bezelBorder
        let view = scroll.documentView as! NSTextView
        view.isRichText = false
        view.importsGraphics = false
        view.allowsUndo = false
        view.usesFindBar = true
        view.isAutomaticQuoteSubstitutionEnabled = false
        view.isAutomaticDashSubstitutionEnabled = false
        view.isAutomaticTextReplacementEnabled = false
        view.isAutomaticSpellingCorrectionEnabled = false
        view.isAutomaticLinkDetectionEnabled = false
        view.isAutomaticDataDetectionEnabled = false
        view.isAutomaticTextCompletionEnabled = false
        view.isContinuousSpellCheckingEnabled = false
        view.isGrammarCheckingEnabled = false
        view.smartInsertDeleteEnabled = false
        view.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        view.textContainerInset = NSSize(width: 4, height: 6)
        view.string = text
        view.delegate = context.coordinator
        view.setAccessibilityLabel("Snippet text")
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let view = scroll.documentView as? NSTextView, view.string != text else { return }
        view.string = text
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: SnippetTextEditor
        init(_ parent: SnippetTextEditor) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let view = notification.object as? NSTextView else { return }
            parent.text = view.string
        }

        func textDidEndEditing(_ notification: Notification) {
            parent.onCommit()
        }
    }
}

/// In-house shortcut recorder (no third-party package). Click, then press a key combination
/// with ⌘, ⌃, or ⌥ (or a function key). Esc cancels.
final class ShortcutRecorderView: NSView {
    var shortcut: KeyShortcut? { didSet { needsDisplay = true } }
    var onRecord: ((KeyShortcut) -> Void)?
    var onRecordingChanged: ((Bool) -> Void)?
    private var recording = false { didSet { needsDisplay = true; onRecordingChanged?(recording) } }

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        NotificationCenter.default.removeObserver(self)
        guard let window else {
            if recording { recording = false }
            return
        }
        // Switching to another app or window ends recording, so global shortcuts resume.
        NotificationCenter.default.addObserver(self, selector: #selector(windowResignedKey), name: NSWindow.didResignKeyNotification, object: window)
    }

    @objc private func windowResignedKey() {
        if recording { window?.makeFirstResponder(nil) }
    }

    override var intrinsicContentSize: NSSize { NSSize(width: 150, height: 24) }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
    }

    override func becomeFirstResponder() -> Bool {
        recording = true
        return true
    }

    override func resignFirstResponder() -> Bool {
        if recording { recording = false }
        return true
    }

    override func keyDown(with event: NSEvent) {
        guard recording else { return super.keyDown(with: event) }
        capture(event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard recording, window?.firstResponder === self else { return false }
        capture(event)
        return true
    }

    private func capture(_ event: NSEvent) {
        if event.keyCode == 53 { // Esc
            window?.makeFirstResponder(nil)
            return
        }
        guard let shortcut = ShortcutFormatter.shortcut(from: event) else {
            NSSound.beep()
            return
        }
        window?.makeFirstResponder(nil)
        onRecord?(shortcut)
    }

    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds.insetBy(dx: 0.5, dy: 0.5)
        let path = NSBezierPath(roundedRect: rect, xRadius: 6, yRadius: 6)
        (recording ? NSColor.controlAccentColor.withAlphaComponent(0.12) : NSColor.controlBackgroundColor).setFill()
        path.fill()
        (recording ? NSColor.controlAccentColor : NSColor.separatorColor).setStroke()
        path.stroke()
        let text: String
        let color: NSColor
        if recording {
            text = "Type shortcut…"
            color = .secondaryLabelColor
        } else if let shortcut {
            text = ShortcutFormatter.string(for: shortcut)
            color = .labelColor
        } else {
            text = "Record Shortcut"
            color = .secondaryLabelColor
        }
        let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 12), .foregroundColor: color]
        let size = (text as NSString).size(withAttributes: attributes)
        (text as NSString).draw(at: NSPoint(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2), withAttributes: attributes)
    }
}

struct ShortcutRecorder: NSViewRepresentable {
    var shortcut: KeyShortcut?
    var onRecord: (KeyShortcut) -> Void
    var onRecordingChanged: (Bool) -> Void

    func makeNSView(context: Context) -> ShortcutRecorderView {
        let view = ShortcutRecorderView()
        view.setAccessibilityRole(.button)
        view.setAccessibilityLabel("Keyboard shortcut")
        return view
    }

    /// Fixed size, so a grouped form keeps the recorder on the same line as its label.
    func sizeThatFits(_ proposal: ProposedViewSize, nsView: ShortcutRecorderView, context: Context) -> CGSize? {
        CGSize(width: 150, height: 24)
    }

    func updateNSView(_ view: ShortcutRecorderView, context: Context) {
        view.shortcut = shortcut
        view.onRecord = onRecord
        view.onRecordingChanged = onRecordingChanged
    }
}

/// A shortcut row: recorder, clear button, refusal message, and registration-failure flag.
struct ShortcutField: View {
    let title: String
    let app: AppController
    let owner: ShortcutOwner
    @State private var message: String?

    @ViewBuilder
    var body: some View {
        let current = app.store.shortcut(for: owner)
        // Rendered as form rows: the recorder stays on the label's line, and any message
        // gets its own row underneath.
        HStack(spacing: 6) {
            Text(title)
            Spacer(minLength: 12)
            HStack(spacing: 6) {
                ShortcutRecorder(shortcut: current, onRecord: { shortcut in
                    message = app.assignShortcut(shortcut, to: owner)
                }, onRecordingChanged: { recording in
                    if recording { app.beginRecordingShortcut() } else { app.endRecordingShortcut() }
                })
                .frame(width: 150, height: 24)
                Button {
                    message = app.assignShortcut(nil, to: owner)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.borderless)
                .disabled(current == nil)
                .help("Remove shortcut")
            }
            .fixedSize()
        }
        if let message {
            Text(message).font(.caption).foregroundStyle(.red)
        } else if app.store.shortcutFailures.contains(owner) {
            Text("This shortcut couldn't be registered. It may be used by another app.")
                .font(.caption).foregroundStyle(.red)
        }
    }
}

/// The label drawn like the square art: Burnt Orange rounded heavy on the warm off-white face.
struct LabelBadge: View {
    let label: String
    var size: CGFloat = 26

    var body: some View {
        Text(label)
            .font(.system(size: size * 0.46, weight: .heavy, design: .rounded))
            .foregroundStyle(Color(nsColor: Art.burntOrange700))
            .frame(width: size, height: size)
            .background(RoundedRectangle(cornerRadius: size * 0.24).fill(Color(red: 0xFA / 255, green: 0xF7 / 255, blue: 0xF2 / 255)))
            .overlay(RoundedRectangle(cornerRadius: size * 0.24).stroke(Color(nsColor: Art.periwinkle500).opacity(0.45), lineWidth: 1))
    }
}
