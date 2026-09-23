import AppKit
import AVFoundation
import Carbon.HIToolbox
import ServiceManagement
import YoinkCore

/// Writes plain text to the general pasteboard. Never reads it back, never logs it.
@MainActor
final class PasteboardClipboard: ClipboardPort {
    func write(_ text: String) -> Bool {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        return pasteboard.setString(text, forType: .string)
    }
}

/// Plays the bundled `audio-hehe.mp3` (Decision #25). Loaded once so each copy plays without delay.
@MainActor
final class CopySoundPlayer: SoundPort {
    private let player: AVAudioPlayer?

    init() {
        if let url = Bundle.main.url(forResource: "copy-sound", withExtension: "mp3") {
            player = try? AVAudioPlayer(contentsOf: url)
            player?.prepareToPlay()
        } else {
            player = nil
        }
    }

    func playCopySound() {
        guard let player else { return }
        player.currentTime = 0
        player.play()
    }
}

/// Launch at login through `SMAppService.mainApp` (architecture spec). The Settings toggle
/// shows what macOS reports, never just the saved preference.
@MainActor
final class LoginItemService: LoginItemPort {
    var state: LoginItemState {
        switch SMAppService.mainApp.status {
        case .enabled: .enabled
        case .requiresApproval: .requiresApproval
        default: .disabled
        }
    }

    func apply(enabled: Bool) -> LoginItemState {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            NSLog("yo!nk: login item change failed (%@)", String(describing: (error as NSError).code))
        }
        return state
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}

/// System-wide shortcuts with Carbon `RegisterEventHotKey`, which needs no Accessibility or
/// Input Monitoring permission and never sees other keystrokes (Decision #37).
@MainActor
final class CarbonHotkeys: HotkeyPort {
    private static let signature: OSType = 0x796F_4E4B // 'yoNK'
    private var refs: [UInt32: EventHotKeyRef] = [:]
    private var handler: EventHandlerRef?
    var onPress: ((UInt32) -> Void)?

    init() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let context = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let event, let userData else { return OSStatus(eventNotHandledErr) }
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            guard status == noErr else { return status }
            let center = Unmanaged<CarbonHotkeys>.fromOpaque(userData).takeUnretainedValue()
            let id = hotKeyID.id
            MainActor.assumeIsolated { center.onPress?(id) }
            return noErr
        }, 1, &eventType, context, &handler)
    }

    func register(_ shortcut: KeyShortcut, id: UInt32) -> Bool {
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(shortcut.keyCode, shortcut.modifiers, EventHotKeyID(signature: Self.signature, id: id), GetApplicationEventTarget(), 0, &ref)
        guard status == noErr, let ref else { return false }
        refs[id] = ref
        return true
    }

    func unregister(id: UInt32) {
        if let ref = refs.removeValue(forKey: id) { UnregisterEventHotKey(ref) }
    }
}

/// Human-readable shortcut names such as "⌃⌥H".
enum ShortcutFormatter {
    static func string(for shortcut: KeyShortcut) -> String {
        var s = ""
        if shortcut.modifiers & KeyShortcut.control != 0 { s += "⌃" }
        if shortcut.modifiers & KeyShortcut.option != 0 { s += "⌥" }
        if shortcut.modifiers & KeyShortcut.shift != 0 { s += "⇧" }
        if shortcut.modifiers & KeyShortcut.command != 0 { s += "⌘" }
        return s + keyName(shortcut.keyCode)
    }

    static let special: [Int: String] = [
        kVK_Return: "↩", kVK_Tab: "⇥", kVK_Space: "Space", kVK_Delete: "⌫", kVK_ForwardDelete: "⌦",
        kVK_Escape: "⎋", kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
        kVK_Home: "↖", kVK_End: "↘", kVK_PageUp: "⇞", kVK_PageDown: "⇟",
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
        kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
        kVK_F13: "F13", kVK_F14: "F14", kVK_F15: "F15", kVK_F16: "F16", kVK_F17: "F17", kVK_F18: "F18",
        kVK_F19: "F19", kVK_F20: "F20",
    ]

    static let functionKeys: Set<Int> = [kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6, kVK_F7, kVK_F8, kVK_F9, kVK_F10,
                                         kVK_F11, kVK_F12, kVK_F13, kVK_F14, kVK_F15, kVK_F16, kVK_F17, kVK_F18, kVK_F19, kVK_F20]

    static func keyName(_ keyCode: UInt32) -> String {
        if let name = special[Int(keyCode)] { return name }
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let raw = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return "#\(keyCode)" }
        let data = Unmanaged<CFData>.fromOpaque(raw).takeUnretainedValue() as Data
        return data.withUnsafeBytes { buffer -> String in
            guard let layout = buffer.bindMemory(to: UCKeyboardLayout.self).baseAddress else { return "#\(keyCode)" }
            var deadKeys: UInt32 = 0
            var chars = [UniChar](repeating: 0, count: 4)
            var length = 0
            let status = UCKeyTranslate(layout, UInt16(keyCode), UInt16(kUCKeyActionDisplay), 0, UInt32(LMGetKbdType()),
                                        OptionBits(kUCKeyTranslateNoDeadKeysBit), &deadKeys, chars.count, &length, &chars)
            guard status == noErr, length > 0 else { return "#\(keyCode)" }
            return String(utf16CodeUnits: chars, count: length).uppercased()
        }
    }

    /// Converts a key event into a shortcut. A shortcut needs ⌘, ⌃, or ⌥ unless it is a function key.
    static func shortcut(from event: NSEvent) -> KeyShortcut? {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var mods: UInt32 = 0
        if flags.contains(.command) { mods |= KeyShortcut.command }
        if flags.contains(.option) { mods |= KeyShortcut.option }
        if flags.contains(.control) { mods |= KeyShortcut.control }
        if flags.contains(.shift) { mods |= KeyShortcut.shift }
        let hasRealModifier = mods & (KeyShortcut.command | KeyShortcut.option | KeyShortcut.control) != 0
        guard hasRealModifier || functionKeys.contains(Int(event.keyCode)) else { return nil }
        return KeyShortcut(keyCode: UInt32(event.keyCode), modifiers: mods)
    }
}
