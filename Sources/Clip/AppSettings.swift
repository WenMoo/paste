import Foundation
import ServiceManagement

@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var launchAtLogin: Bool {
        didSet { UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin") }
    }

    @Published var autoPaste: Bool {
        didSet { UserDefaults.standard.set(autoPaste, forKey: "autoPaste") }
    }

    @Published var retention: HistoryRetention {
        didSet { UserDefaults.standard.set(retention.rawValue, forKey: "retention") }
    }

    @Published var ignoredBundleIDs: [String] {
        didSet { UserDefaults.standard.set(ignoredBundleIDs, forKey: "ignoredBundleIDs") }
    }

    @Published var pausedUntil: Date? {
        didSet { UserDefaults.standard.set(pausedUntil, forKey: "pausedUntil") }
    }

    @Published var didOnboard: Bool {
        didSet { UserDefaults.standard.set(didOnboard, forKey: "didOnboard") }
    }

    @Published var panelHeight: Double {
        didSet { UserDefaults.standard.set(panelHeight, forKey: "panelHeight") }
    }

    @Published var toggleShortcut: KeyShortcut {
        didSet { persistShortcut(toggleShortcut, key: "toggleShortcut") }
    }

    @Published var pauseShortcut: KeyShortcut {
        didSet { persistShortcut(pauseShortcut, key: "pauseShortcut") }
    }

    @Published var pasteShortcut: KeyShortcut {
        didSet { persistShortcut(pasteShortcut, key: "pasteShortcut") }
    }

    @Published var pastePlainShortcut: KeyShortcut {
        didSet { persistShortcut(pastePlainShortcut, key: "pastePlainShortcut") }
    }

    @Published var searchShortcut: KeyShortcut {
        didSet { persistShortcut(searchShortcut, key: "searchShortcut") }
    }

    @Published var editShortcut: KeyShortcut {
        didSet { persistShortcut(editShortcut, key: "editShortcut") }
    }

    @Published var renameShortcut: KeyShortcut {
        didSet { persistShortcut(renameShortcut, key: "renameShortcut") }
    }

    @Published var newTextShortcut: KeyShortcut {
        didSet { persistShortcut(newTextShortcut, key: "newTextShortcut") }
    }

    @Published var newPinboardShortcut: KeyShortcut {
        didSet { persistShortcut(newPinboardShortcut, key: "newPinboardShortcut") }
    }

    @Published var previewShortcut: KeyShortcut {
        didSet { persistShortcut(previewShortcut, key: "previewShortcut") }
    }

    private var ready = false

    var isPaused: Bool {
        if let pausedUntil, pausedUntil > Date() { return true }
        if pausedUntil == .distantFuture { return true }
        return false
    }

    var isPausedIndefinitely: Bool {
        pausedUntil == .distantFuture
    }

    private init() {
        let defaults = UserDefaults.standard
        launchAtLogin = defaults.bool(forKey: "launchAtLogin")
        autoPaste = defaults.object(forKey: "autoPaste") as? Bool ?? true
        retention = HistoryRetention(rawValue: defaults.string(forKey: "retention") ?? "") ?? .forever
        ignoredBundleIDs = (defaults.stringArray(forKey: "ignoredBundleIDs") ?? AppSettings.defaultIgnored)
            .filter { $0 != "app.local.clip" }
        pausedUntil = defaults.object(forKey: "pausedUntil") as? Date
        didOnboard = defaults.bool(forKey: "didOnboard")
        panelHeight = defaults.object(forKey: "panelHeight") as? Double ?? 320
        toggleShortcut = Self.loadShortcut("toggleShortcut") ?? .toggleDefault
        pauseShortcut = Self.loadShortcut("pauseShortcut") ?? .pauseDefault
        pasteShortcut = Self.loadShortcut("pasteShortcut") ?? .pasteDefault
        pastePlainShortcut = Self.loadShortcut("pastePlainShortcut") ?? .pastePlainDefault
        searchShortcut = Self.loadShortcut("searchShortcut") ?? .searchDefault
        editShortcut = Self.loadShortcut("editShortcut") ?? .editDefault
        renameShortcut = Self.loadShortcut("renameShortcut") ?? .renameDefault
        newTextShortcut = Self.loadShortcut("newTextShortcut") ?? .newTextDefault
        newPinboardShortcut = Self.loadShortcut("newPinboardShortcut") ?? .newPinboardDefault
        previewShortcut = Self.loadShortcut("previewShortcut") ?? .previewDefault
        ready = true
    }

    func shortcut(for action: ShortcutAction) -> KeyShortcut {
        switch action {
        case .toggle: toggleShortcut
        case .pause: pauseShortcut
        case .paste: pasteShortcut
        case .pastePlain: pastePlainShortcut
        case .search: searchShortcut
        case .edit: editShortcut
        case .rename: renameShortcut
        case .newText: newTextShortcut
        case .newPinboard: newPinboardShortcut
        case .preview: previewShortcut
        }
    }

    func setShortcut(_ shortcut: KeyShortcut, for action: ShortcutAction) {
        switch action {
        case .toggle: toggleShortcut = shortcut
        case .pause: pauseShortcut = shortcut
        case .paste: pasteShortcut = shortcut
        case .pastePlain: pastePlainShortcut = shortcut
        case .search: searchShortcut = shortcut
        case .edit: editShortcut = shortcut
        case .rename: renameShortcut = shortcut
        case .newText: newTextShortcut = shortcut
        case .newPinboard: newPinboardShortcut = shortcut
        case .preview: previewShortcut = shortcut
        }
    }

    func resetShortcuts() {
        toggleShortcut = .toggleDefault
        pauseShortcut = .pauseDefault
        pasteShortcut = .pasteDefault
        pastePlainShortcut = .pastePlainDefault
        searchShortcut = .searchDefault
        editShortcut = .editDefault
        renameShortcut = .renameDefault
        newTextShortcut = .newTextDefault
        newPinboardShortcut = .newPinboardDefault
        previewShortcut = .previewDefault
    }

    private func persistShortcut(_ shortcut: KeyShortcut, key: String) {
        if let data = try? JSONEncoder().encode(shortcut) {
            UserDefaults.standard.set(data, forKey: key)
        }
        guard ready else { return }
        if key == "toggleShortcut" || key == "pauseShortcut" {
            HotKeyCenter.shared.register()
        }
    }

    private static func loadShortcut(_ key: String) -> KeyShortcut? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(KeyShortcut.self, from: data)
    }

    static let defaultIgnored = [
        "com.1password.1password",
        "com.1password.1password7",
        "com.1password.1password8",
        "com.agilebits.onepassword7",
        "com.apple.Passwords",
        "com.apple.securityagent",
        "com.lastpass.LastPass",
        "com.bitwarden.desktop",
        "com.apple.keychainaccess",
        "com.apple.loginwindow",
    ]

    func pause(for interval: TimeInterval?) {
        if let interval {
            pausedUntil = Date().addingTimeInterval(interval)
        } else {
            pausedUntil = .distantFuture
        }
    }

    func resume() {
        pausedUntil = nil
    }

    func applyLaunchAtLogin() {
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Launch-at-login requires a real app bundle; ignore when running from swift build.
        }
    }
}
