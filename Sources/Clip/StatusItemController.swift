import AppKit
import SwiftUI

@MainActor
final class StatusItemController {
    private let item: NSStatusItem
    private weak var panel: PanelController?

    init(panel: PanelController) {
        self.panel = panel
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "clipboard", accessibilityDescription: L10n.appName)
            button.image?.isTemplate = true
            button.toolTip = L10n.appName
            button.target = self
            button.action = #selector(clicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    func refresh() {}

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        let show = NSMenuItem(title: L10n.showClip, action: #selector(showPanel), keyEquivalent: AppSettings.shared.toggleShortcut.menuKeyEquivalent)
        show.keyEquivalentModifierMask = AppSettings.shared.toggleShortcut.modifiers
        show.target = self
        menu.addItem(show)
        menu.addItem(.separator())

        if AppSettings.shared.isPaused {
            let resume = NSMenuItem(title: L10n.resume, action: #selector(resume), keyEquivalent: AppSettings.shared.pauseShortcut.menuKeyEquivalent)
            resume.keyEquivalentModifierMask = AppSettings.shared.pauseShortcut.modifiers
            resume.target = self
            menu.addItem(resume)
        } else {
            let pause = NSMenuItem(title: L10n.pause, action: nil, keyEquivalent: AppSettings.shared.pauseShortcut.menuKeyEquivalent)
            pause.keyEquivalentModifierMask = AppSettings.shared.pauseShortcut.modifiers
            let pauseMenu = NSMenu()
            pauseMenu.addItem(withTitle: L10n.pause5, action: #selector(pause5), keyEquivalent: "").target = self
            pauseMenu.addItem(withTitle: L10n.pause15, action: #selector(pause15), keyEquivalent: "").target = self
            pauseMenu.addItem(withTitle: L10n.pause60, action: #selector(pause60), keyEquivalent: "").target = self
            pauseMenu.addItem(withTitle: L10n.pauseUntil, action: #selector(pauseForever), keyEquivalent: "").target = self
            pause.submenu = pauseMenu
            menu.addItem(pause)
        }

        menu.addItem(.separator())
        menu.addItem(withTitle: L10n.settings, action: #selector(showSettings), keyEquivalent: ",").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: L10n.quit, action: #selector(quit), keyEquivalent: "q").target = self
        return menu
    }

    @objc private func clicked() {
        guard let event = NSApp.currentEvent else {
            panel?.toggle()
            return
        }
        if event.type == .rightMouseUp, let button = item.button {
            let menu = buildMenu()
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 6), in: button)
        } else {
            panel?.toggle()
        }
    }

    @objc private func showPanel() { panel?.toggle() }
    @objc private func resume() { AppSettings.shared.resume(); refresh() }
    @objc private func pause5() { AppSettings.shared.pause(for: 300); refresh() }
    @objc private func pause15() { AppSettings.shared.pause(for: 900); refresh() }
    @objc private func pause60() { AppSettings.shared.pause(for: 3600); refresh() }
    @objc private func pauseForever() { AppSettings.shared.pause(for: nil); refresh() }
    @objc private func showSettings() { SettingsWindow.shared.show() }
    @objc private func quit() { NSApp.terminate(nil) }
}
