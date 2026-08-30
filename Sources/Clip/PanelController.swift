import AppKit
import SwiftUI

@MainActor
final class PanelController: NSObject, NSWindowDelegate {
    let panel: NSPanel
    private var hosting: NSHostingView<PanelRootView>
    private var previousApp: NSRunningApplication?
    private var clickMonitor: Any?
    private var keyMonitor: Any?
    let watcher: PasteboardWatcher

    var isVisible: Bool { panel.isVisible }

    init(watcher: PasteboardWatcher) {
        self.watcher = watcher
        let height = AppSettings.shared.panelHeight
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        panel = NSPanel(
            contentRect: NSRect(x: screen.minX, y: screen.minY, width: screen.width, height: height),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .resizable, .borderless],
            backing: .buffered,
            defer: false
        )
        hosting = NSHostingView(rootView: PanelRootView())
        super.init()

        panel.delegate = self
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovable = false
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = false
        panel.minSize = NSSize(width: 640, height: 168)
        panel.maxSize = NSSize(width: 10000, height: 560)
        panel.contentView = hosting
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true

        NotificationCenter.default.addObserver(forName: .clipPasteRequested, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.pasteSelected(plain: false) }
        }
        NotificationCenter.default.addObserver(forName: .clipPastePlainRequested, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.pasteSelected(plain: true) }
        }
        NotificationCenter.default.addObserver(forName: .clipCopyRequested, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.copySelected() }
        }
    }

    func toggle() {
        if panel.isVisible {
            hide()
        } else {
            show()
        }
    }

    func show() {
        FrontAppTracker.shared.remember(NSWorkspace.shared.frontmostApplication)
        previousApp = FrontAppTracker.shared.target
        NSApp.unhide(nil)
        layoutOnScreen(animated: false, offscreen: true)
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        layoutOnScreen(animated: true, offscreen: false)
        installMonitors()
        if ClipStore.shared.selectedIDs.isEmpty {
            ClipStore.shared.selectIndex(0)
        }
    }

    func hide(animated: Bool = true) {
        removeMonitors()
        panel.makeFirstResponder(nil)
        guard panel.isVisible else { return }
        if animated {
            let screen = currentScreen()
            let height = panel.frame.height
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18
                context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                panel.animator().setFrameOrigin(NSPoint(x: screen.minX, y: screen.minY - height - 12))
            } completionHandler: {
                Task { @MainActor in
                    self.panel.orderOut(nil)
                }
            }
        } else {
            panel.orderOut(nil)
        }
        ClipStore.shared.previewItemID = nil
        ClipStore.shared.query = ""
    }

    func pasteSelected(plain: Bool) {
        guard let item = ClipStore.shared.selectedItem else { return }
        let target = previousApp ?? FrontAppTracker.shared.target
        hide(animated: false)
        PasteEngine.paste(item, into: target, plain: plain, watcher: watcher)
    }

    func copySelected() {
        guard let item = ClipStore.shared.selectedItem else { return }
        watcher.ignoreInternalWrite {
            PasteEngine.copy(item)
        }
    }

    func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        let screen = currentScreen()
        return NSSize(width: screen.width, height: min(max(frameSize.height, 168), 560))
    }

    func windowDidResize(_ notification: Notification) {
        let screen = currentScreen()
        let frame = panel.frame
        if abs(frame.minX - screen.minX) > 1 || abs(frame.width - screen.width) > 1 {
            panel.setFrame(
                NSRect(x: screen.minX, y: screen.minY, width: screen.width, height: frame.height),
                display: true
            )
        }
        AppSettings.shared.panelHeight = frame.height
    }

    private func layoutOnScreen(animated: Bool, offscreen: Bool) {
        let screen = currentScreen()
        let height = AppSettings.shared.panelHeight
        let y = offscreen ? screen.minY - height - 12 : screen.minY
        let frame = NSRect(x: screen.minX, y: y, width: screen.width, height: height)
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.22
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().setFrame(frame, display: true)
            }
        } else {
            panel.setFrame(frame, display: true)
        }
    }

    private func currentScreen() -> NSRect {
        (NSScreen.main ?? NSScreen.screens.first)?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
    }

    private func installMonitors() {
        removeMonitors()
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self else { return }
            let point = NSEvent.mouseLocation
            if !self.panel.frame.contains(point) {
                self.hide()
            }
        }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKey(event) ?? event
        }
    }

    private func removeMonitors() {
        if let clickMonitor {
            NSEvent.removeMonitor(clickMonitor)
            self.clickMonitor = nil
        }
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
    }

    private func handleKey(_ event: NSEvent) -> NSEvent? {
        let store = ClipStore.shared
        let settings = AppSettings.shared

        if event.keyCode == 53 { // escape
            if store.previewItemID != nil {
                store.previewItemID = nil
            } else if !store.query.isEmpty {
                store.query = ""
            } else if store.creatingBoard {
                store.creatingBoard = false
            } else {
                hide()
            }
            return nil
        }

        if settings.searchShortcut.matches(event) {
            return event
        }
        if settings.newPinboardShortcut.matches(event) {
            store.creatingBoard = true
            return nil
        }
        if settings.newTextShortcut.matches(event) {
            store.createTextItem(text: "")
            return nil
        }
        if settings.renameShortcut.matches(event) {
            store.renamingItem = store.selectedItem
            return nil
        }
        if settings.editShortcut.matches(event) {
            store.editingItem = store.selectedItem
            return nil
        }
        if settings.pauseShortcut.matches(event) {
            if settings.isPaused {
                settings.resume()
            } else {
                settings.pause(for: nil)
            }
            return nil
        }
        if settings.pastePlainShortcut.matches(event) {
            pasteSelected(plain: true)
            return nil
        }
        if settings.pasteShortcut.matches(event) || event.keyCode == 76 {
            pasteSelected(plain: false)
            return nil
        }
        if settings.previewShortcut.matches(event) {
            if store.previewItemID == store.selectedItem?.id {
                store.previewItemID = nil
            } else {
                store.previewItemID = store.selectedItem?.id
            }
            return nil
        }

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let cmd = flags.contains(.command)
        let shift = flags.contains(.shift)

        if cmd && event.keyCode == 31 { // O
            if let item = store.selectedItem, !item.url.isEmpty, let url = URL(string: item.url) {
                NSWorkspace.shared.open(url)
            }
            return nil
        }
        if cmd && event.keyCode == 8 { // C
            copySelected()
            return nil
        }
        if cmd && event.keyCode == 43 { // comma
            hide()
            SettingsWindow.shared.show()
            return nil
        }
        if cmd && event.keyCode == 12 { // Q
            NSApp.terminate(nil)
            return nil
        }
        if cmd && (123...126).contains(event.keyCode) {
            if event.keyCode == 123 { store.selectBoard(offset: -1) }
            if event.keyCode == 124 { store.selectBoard(offset: 1) }
            return nil
        }

        if cmd, let chars = event.charactersIgnoringModifiers, let number = Int(chars), (1...9).contains(number) {
            store.selectIndex(number - 1)
            pasteSelected(plain: shift)
            return nil
        }

        if event.keyCode == 51 {
            store.deleteSelected()
            return nil
        }
        if event.keyCode == 123 {
            if shift { store.extendSelection(by: -1) } else { store.selectPrevious() }
            return nil
        }
        if event.keyCode == 124 {
            if shift { store.extendSelection(by: 1) } else { store.selectNext() }
            return nil
        }

        return event
    }
}

enum SettingsWindow {
    static let shared = Controller()

    @MainActor
    final class Controller {
        private var window: NSWindow?

        func show() {
            if window == nil {
                let view = NSHostingView(rootView: SettingsView().environmentObject(AppSettings.shared).environmentObject(ClipStore.shared))
                let window = NSWindow(
                    contentRect: NSRect(x: 0, y: 0, width: 560, height: 580),
                    styleMask: [.titled, .closable, .fullSizeContentView],
                    backing: .buffered,
                    defer: false
                )
                window.title = L10n.settings
                window.contentView = view
                window.isReleasedWhenClosed = false
                window.center()
                self.window = window
            }
            NSApp.activate(ignoringOtherApps: true)
            window?.makeKeyAndOrderFront(nil)
        }
    }
}
