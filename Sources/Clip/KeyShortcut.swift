import AppKit
import Carbon

struct KeyShortcut: Codable, Equatable, Hashable {
    var keyCode: UInt16
    var modifierFlags: UInt

    var modifiers: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: modifierFlags).intersection(Self.modifierMask)
    }

    var carbonModifiers: UInt32 {
        var value: UInt32 = 0
        if modifiers.contains(.command) { value |= UInt32(cmdKey) }
        if modifiers.contains(.shift) { value |= UInt32(shiftKey) }
        if modifiers.contains(.option) { value |= UInt32(optionKey) }
        if modifiers.contains(.control) { value |= UInt32(controlKey) }
        return value
    }

    var display: String {
        var parts: [String] = []
        if modifiers.contains(.control) { parts.append("⌃") }
        if modifiers.contains(.option) { parts.append("⌥") }
        if modifiers.contains(.shift) { parts.append("⇧") }
        if modifiers.contains(.command) { parts.append("⌘") }
        parts.append(Self.keyName(keyCode))
        return parts.joined()
    }

    var menuKeyEquivalent: String {
        Self.menuCharacter(keyCode)
    }

    var hasModifiers: Bool {
        !modifiers.isEmpty
    }

    func matches(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(Self.modifierMask)
        return event.keyCode == keyCode && flags == modifiers
    }

    static let modifierMask: NSEvent.ModifierFlags = [.command, .shift, .option, .control]

    static func from(event: NSEvent) -> KeyShortcut? {
        if Self.modifierKeyCodes.contains(event.keyCode) { return nil }
        if event.keyCode == 53 { return nil }
        let flags = event.modifierFlags.intersection(modifierMask)
        return KeyShortcut(keyCode: event.keyCode, modifierFlags: flags.rawValue)
    }

    static let toggleDefault = KeyShortcut(keyCode: UInt16(kVK_ANSI_V), modifierFlags: NSEvent.ModifierFlags([.command, .shift]).rawValue)
    static let pauseDefault = KeyShortcut(keyCode: UInt16(kVK_ANSI_T), modifierFlags: NSEvent.ModifierFlags([.command]).rawValue)
    static let pasteDefault = KeyShortcut(keyCode: UInt16(kVK_Return), modifierFlags: 0)
    static let pastePlainDefault = KeyShortcut(keyCode: UInt16(kVK_Return), modifierFlags: NSEvent.ModifierFlags([.shift]).rawValue)
    static let searchDefault = KeyShortcut(keyCode: UInt16(kVK_ANSI_F), modifierFlags: NSEvent.ModifierFlags([.command]).rawValue)
    static let editDefault = KeyShortcut(keyCode: UInt16(kVK_ANSI_E), modifierFlags: NSEvent.ModifierFlags([.command]).rawValue)
    static let renameDefault = KeyShortcut(keyCode: UInt16(kVK_ANSI_R), modifierFlags: NSEvent.ModifierFlags([.command]).rawValue)
    static let newTextDefault = KeyShortcut(keyCode: UInt16(kVK_ANSI_N), modifierFlags: NSEvent.ModifierFlags([.command]).rawValue)
    static let newPinboardDefault = KeyShortcut(keyCode: UInt16(kVK_ANSI_N), modifierFlags: NSEvent.ModifierFlags([.command, .shift]).rawValue)
    static let previewDefault = KeyShortcut(keyCode: UInt16(kVK_Space), modifierFlags: 0)

    private static let modifierKeyCodes: Set<UInt16> = [54, 55, 56, 57, 58, 59, 60, 61, 62, 63]

    private static func keyName(_ keyCode: UInt16) -> String {
        switch Int(keyCode) {
        case kVK_Return, kVK_ANSI_KeypadEnter: return "↩"
        case kVK_Space: return "Space"
        case kVK_Tab: return "⇥"
        case kVK_Delete: return "⌫"
        case kVK_ForwardDelete: return "⌦"
        case kVK_Escape: return "Esc"
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_UpArrow: return "↑"
        case kVK_DownArrow: return "↓"
        case kVK_F1: return "F1"
        case kVK_F2: return "F2"
        case kVK_F3: return "F3"
        case kVK_F4: return "F4"
        case kVK_F5: return "F5"
        case kVK_F6: return "F6"
        case kVK_F7: return "F7"
        case kVK_F8: return "F8"
        case kVK_F9: return "F9"
        case kVK_F10: return "F10"
        case kVK_F11: return "F11"
        case kVK_F12: return "F12"
        default:
            return menuCharacter(keyCode).uppercased()
        }
    }

    private static func menuCharacter(_ keyCode: UInt16) -> String {
        switch Int(keyCode) {
        case kVK_ANSI_A: return "a"
        case kVK_ANSI_B: return "b"
        case kVK_ANSI_C: return "c"
        case kVK_ANSI_D: return "d"
        case kVK_ANSI_E: return "e"
        case kVK_ANSI_F: return "f"
        case kVK_ANSI_G: return "g"
        case kVK_ANSI_H: return "h"
        case kVK_ANSI_I: return "i"
        case kVK_ANSI_J: return "j"
        case kVK_ANSI_K: return "k"
        case kVK_ANSI_L: return "l"
        case kVK_ANSI_M: return "m"
        case kVK_ANSI_N: return "n"
        case kVK_ANSI_O: return "o"
        case kVK_ANSI_P: return "p"
        case kVK_ANSI_Q: return "q"
        case kVK_ANSI_R: return "r"
        case kVK_ANSI_S: return "s"
        case kVK_ANSI_T: return "t"
        case kVK_ANSI_U: return "u"
        case kVK_ANSI_V: return "v"
        case kVK_ANSI_W: return "w"
        case kVK_ANSI_X: return "x"
        case kVK_ANSI_Y: return "y"
        case kVK_ANSI_Z: return "z"
        case kVK_ANSI_0: return "0"
        case kVK_ANSI_1: return "1"
        case kVK_ANSI_2: return "2"
        case kVK_ANSI_3: return "3"
        case kVK_ANSI_4: return "4"
        case kVK_ANSI_5: return "5"
        case kVK_ANSI_6: return "6"
        case kVK_ANSI_7: return "7"
        case kVK_ANSI_8: return "8"
        case kVK_ANSI_9: return "9"
        case kVK_ANSI_Minus: return "-"
        case kVK_ANSI_Equal: return "="
        case kVK_ANSI_LeftBracket: return "["
        case kVK_ANSI_RightBracket: return "]"
        case kVK_ANSI_Backslash: return "\\"
        case kVK_ANSI_Semicolon: return ";"
        case kVK_ANSI_Quote: return "'"
        case kVK_ANSI_Comma: return ","
        case kVK_ANSI_Period: return "."
        case kVK_ANSI_Slash: return "/"
        case kVK_ANSI_Grave: return "`"
        default: return ""
        }
    }
}

enum ShortcutAction: String, CaseIterable, Identifiable {
    case toggle
    case pause
    case paste
    case pastePlain
    case search
    case edit
    case rename
    case newText
    case newPinboard
    case preview

    var id: String { rawValue }

    var title: String {
        switch self {
        case .toggle: L10n.hotkeyHint
        case .pause: L10n.pause
        case .paste: L10n.paste
        case .pastePlain: L10n.pastePlain
        case .search: L10n.search
        case .edit: L10n.edit
        case .rename: L10n.rename
        case .newText: L10n.newText
        case .newPinboard: L10n.newPinboard
        case .preview: L10n.preview
        }
    }

    var isGlobal: Bool {
        self == .toggle || self == .pause
    }

    var defaultValue: KeyShortcut {
        switch self {
        case .toggle: .toggleDefault
        case .pause: .pauseDefault
        case .paste: .pasteDefault
        case .pastePlain: .pastePlainDefault
        case .search: .searchDefault
        case .edit: .editDefault
        case .rename: .renameDefault
        case .newText: .newTextDefault
        case .newPinboard: .newPinboardDefault
        case .preview: .previewDefault
        }
    }
}
