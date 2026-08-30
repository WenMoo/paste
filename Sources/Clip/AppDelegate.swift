import AppKit
import SwiftUI

@main
enum ClipEntry {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
        withExtendedLifetime(delegate) {}
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var watcher: PasteboardWatcher!
    private var panel: PanelController!
    private var statusItem: StatusItemController!
    private var onboarding: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        watcher = PasteboardWatcher()
        panel = PanelController(watcher: watcher)
        statusItem = StatusItemController(panel: panel)
        watcher.start()
        FrontAppTracker.shared.start()
        HotKeyCenter.shared.onToggle = { [weak self] in
            self?.panel.toggle()
        }
        HotKeyCenter.shared.onPause = {
            if AppSettings.shared.isPaused {
                AppSettings.shared.resume()
            } else {
                AppSettings.shared.pause(for: nil)
            }
        }
        HotKeyCenter.shared.register()

        if !AppSettings.shared.didOnboard {
            showOnboarding()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        HotKeyCenter.shared.unregister()
    }

    private func showOnboarding() {
        let view = NSHostingView(rootView: OnboardingView(
            onContinue: { [weak self] in
                AppSettings.shared.didOnboard = true
                self?.onboarding?.close()
                self?.panel.show()
            },
            onSkip: { [weak self] in
                AppSettings.shared.didOnboard = true
                self?.onboarding?.close()
            }
        ))
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 420),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = L10n.appName
        window.contentView = view
        window.isReleasedWhenClosed = false
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        onboarding = window
    }
}
