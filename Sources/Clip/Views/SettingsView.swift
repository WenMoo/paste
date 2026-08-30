import SwiftUI
import AppKit
import ServiceManagement
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var store: ClipStore
    @State private var trusted = AXIsProcessTrusted()

    var body: some View {
        TabView {
            general.tabItem { Label(L10n.general, systemImage: "gearshape") }
            privacy.tabItem { Label(L10n.privacy, systemImage: "lock") }
            shortcuts.tabItem { Label(L10n.shortcuts, systemImage: "keyboard") }
            about.tabItem { Label(L10n.about, systemImage: "info.circle") }
        }
        .padding(20)
        .frame(width: 560, height: 560)
        .onAppear { trusted = AXIsProcessTrusted() }
    }

    private var general: some View {
        Form {
            Toggle(L10n.launchAtLogin, isOn: $settings.launchAtLogin)
                .onChange(of: settings.launchAtLogin) { _, _ in
                    settings.applyLaunchAtLogin()
                }
            Toggle(L10n.autoPaste, isOn: $settings.autoPaste)
            Picker(L10n.keepHistory, selection: $settings.retention) {
                ForEach(HistoryRetention.allCases) { item in
                    Text(item.title).tag(item)
                }
            }
            HStack {
                Text(L10n.accessibility)
                Spacer()
                Text(trusted ? L10n.granted : L10n.notGranted)
                    .foregroundStyle(trusted ? .green : .secondary)
                Button(L10n.openAccessibility) {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
            Button(L10n.clearHistory, role: .destructive) {
                store.clearHistory()
            }
        }
        .formStyle(.grouped)
    }

    private var privacy: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.localOnly)
                .foregroundStyle(.secondary)
            Text(L10n.ignoredApps)
                .font(.headline)
            List {
                ForEach(settings.ignoredBundleIDs, id: \.self) { id in
                    HStack {
                        Text(displayName(for: id))
                        Spacer()
                        Text(id)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
                .onDelete { indexSet in
                    settings.ignoredBundleIDs.remove(atOffsets: indexSet)
                }
            }
            .listStyle(.inset)
            Button(L10n.addApp) { pickApp() }
        }
        .padding(.top, 8)
    }

    private var shortcuts: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.shortcutHint)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Form {
                Section(L10n.globalShortcuts) {
                    recorder(for: .toggle)
                    recorder(for: .pause)
                }
                Section(L10n.panelShortcuts) {
                    recorder(for: .paste)
                    recorder(for: .pastePlain)
                    recorder(for: .search)
                    recorder(for: .edit)
                    recorder(for: .rename)
                    recorder(for: .newText)
                    recorder(for: .newPinboard)
                    recorder(for: .preview)
                }
            }
            .formStyle(.grouped)
            HStack {
                Spacer()
                Button(L10n.resetShortcuts) {
                    settings.resetShortcuts()
                }
            }
        }
        .padding(.top, 4)
    }

    private func recorder(for action: ShortcutAction) -> some View {
        LabeledContent(action.title) {
            ShortcutRecorder(
                shortcut: Binding(
                    get: { settings.shortcut(for: action) },
                    set: { settings.setShortcut($0, for: action) }
                ),
                defaultShortcut: action.defaultValue,
                requiresModifier: action.isGlobal
            )
        }
    }

    private var about: some View {
        VStack(spacing: 12) {
            Image(systemName: "clipboard.fill")
                .font(.system(size: 42))
                .foregroundStyle(Color(red: 0.49, green: 0.36, blue: 0.99))
            Text(L10n.appName)
                .font(.title2.bold())
            Text("1.0.0")
                .foregroundStyle(.secondary)
            Text(L10n.aboutBody)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 360)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func displayName(for bundleID: String) -> String {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return FileManager.default.displayName(atPath: url.path)
        }
        return bundleID
    }

    private func pickApp() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.application]
        if panel.runModal() == .OK, let url = panel.url,
           let bundle = Bundle(url: url),
           let id = bundle.bundleIdentifier,
           !settings.ignoredBundleIDs.contains(id) {
            settings.ignoredBundleIDs.append(id)
        }
    }
}

struct OnboardingView: View {
    var onContinue: () -> Void
    var onSkip: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.33, green: 0.45, blue: 0.98), Color(red: 0.56, green: 0.32, blue: 0.98)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 88, height: 88)
                Image(systemName: "clipboard.fill")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(.white)
            }
            Text(L10n.welcomeTitle)
                .font(.system(size: 26, weight: .bold))
            Text(L10n.welcomeBody)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 380)
            VStack(alignment: .leading, spacing: 8) {
                bullet("shift", AppSettings.shared.toggleShortcut.display, L10n.hotkeyHint)
                bullet("pin.fill", L10n.pin, L10n.emptyBoard)
                bullet("lock.fill", L10n.privacy, L10n.localOnly)
            }
            .padding(.top, 8)
            Spacer()
            HStack {
                Button(L10n.skip, action: onSkip)
                Spacer()
                Button(L10n.continueBtn, action: onContinue)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(28)
        .frame(width: 520, height: 420)
    }

    private func bullet(_ symbol: String, _ title: String, _ subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .frame(width: 18)
                .foregroundStyle(Color(red: 0.49, green: 0.36, blue: 0.99))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .semibold))
                Text(subtitle).font(.system(size: 12)).foregroundStyle(.secondary)
            }
        }
    }
}

struct ShortcutRecorder: View {
    @Binding var shortcut: KeyShortcut
    var defaultShortcut: KeyShortcut
    var requiresModifier: Bool

    @State private var recording = false
    @State private var invalid = false
    @State private var monitor: Any?

    var body: some View {
        Button(action: toggle) {
            Text(recording ? L10n.pressShortcut : shortcut.display)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(recording ? Color.accentColor : .primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .frame(minWidth: 108)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(recording ? Color.accentColor.opacity(0.16) : Color.primary.opacity(0.08))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(recording ? Color.accentColor : Color.clear, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .help(invalid && requiresModifier ? L10n.globalNeedsModifier : L10n.shortcutHint)
        .onDisappear { stop() }
    }

    private func toggle() {
        if recording {
            stop()
        } else {
            start()
        }
    }

    private func start() {
        stop()
        recording = true
        invalid = false
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handle(event)
        }
    }

    private func handle(_ event: NSEvent) -> NSEvent? {
        if event.keyCode == 53 {
            stop()
            return nil
        }
        if event.keyCode == 51 {
            shortcut = defaultShortcut
            stop()
            return nil
        }
        guard let next = KeyShortcut.from(event: event) else { return nil }
        if requiresModifier, next.modifiers.intersection([.command, .option, .control]).isEmpty {
            invalid = true
            return nil
        }
        shortcut = next
        stop()
        return nil
    }

    private func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        recording = false
    }
}
