import AppKit
import ApplicationServices

@MainActor
final class FrontAppTracker {
    static let shared = FrontAppTracker()
    private(set) var app: NSRunningApplication?
    private var observer: NSObjectProtocol?

    func start() {
        remember(NSWorkspace.shared.frontmostApplication)
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            Task { @MainActor in
                FrontAppTracker.shared.remember(app)
            }
        }
    }

    func remember(_ app: NSRunningApplication?) {
        guard let app,
              !app.isTerminated,
              app.bundleIdentifier != "app.local.clip",
              app.bundleIdentifier != Bundle.main.bundleIdentifier else { return }
        self.app = app
    }

    var target: NSRunningApplication? {
        if let app, !app.isTerminated { return app }
        remember(NSWorkspace.shared.frontmostApplication)
        return self.app
    }
}

@MainActor
enum PasteEngine {
    static func copy(_ item: ClipItem, plain: Bool = false) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        if plain {
            pasteboard.setString(plainText(for: item), forType: .string)
            return
        }

        switch item.kind {
        case .image:
            if let image = NSImage(contentsOfFile: item.imagePath) {
                pasteboard.writeObjects([image])
            } else {
                pasteboard.setString(item.title, forType: .string)
            }
        case .file:
            let urls = item.filePaths.map { URL(fileURLWithPath: $0) as NSURL }
            if !pasteboard.writeObjects(urls) {
                pasteboard.setString(item.filePaths.joined(separator: "\n"), forType: .string)
            }
        case .color:
            pasteboard.setString(item.colorHex.isEmpty ? item.text : item.colorHex, forType: .string)
        case .link:
            pasteboard.setString(item.url.isEmpty ? item.text : item.url, forType: .string)
        case .text, .code:
            pasteboard.setString(item.text.isEmpty ? item.previewText : item.text, forType: .string)
        }
    }

    static func paste(_ item: ClipItem, into app: NSRunningApplication?, plain: Bool, watcher: PasteboardWatcher) {
        watcher.ignoreInternalWrite {
            copy(item, plain: plain)
        }

        guard AppSettings.shared.autoPaste else { return }

        NSApp.keyWindow?.makeFirstResponder(nil)
        NSApp.hide(nil)

        let target = app ?? FrontAppTracker.shared.target
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            if let target, !target.isTerminated, !target.isActive {
                NSApp.yieldActivation(to: target)
                _ = target.activate(from: NSRunningApplication.current)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                simulateCommandV()
            }
        }
    }

    static func simulateCommandV() {
        let source = CGEventSource(stateID: .hidSystemState)
        source?.localEventsSuppressionInterval = 0

        let command: CGKeyCode = 0x37
        let vKey: CGKeyCode = 0x09

        let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: command, keyDown: true)
        cmdDown?.flags = .maskCommand
        let vDown = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true)
        vDown?.flags = .maskCommand
        let vUp = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
        vUp?.flags = .maskCommand
        let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: command, keyDown: false)

        cmdDown?.post(tap: .cghidEventTap)
        vDown?.post(tap: .cghidEventTap)
        vUp?.post(tap: .cghidEventTap)
        cmdUp?.post(tap: .cghidEventTap)
    }

    private static func plainText(for item: ClipItem) -> String {
        if !item.text.isEmpty { return item.text }
        if !item.url.isEmpty { return item.url }
        if !item.colorHex.isEmpty { return item.colorHex }
        return item.previewText
    }
}
