import AppKit
import Carbon

@MainActor
final class HotKeyCenter {
    static let shared = HotKeyCenter()

    var onToggle: (() -> Void)?
    var onPause: (() -> Void)?

    private var hotKeyRefs: [EventHotKeyRef] = []
    private var handlerRef: EventHandlerRef?
    private var handlerUPP: EventHandlerUPP?

    func register() {
        unregister()

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let upp: EventHandlerUPP = { _, event, _ in
            var hotKeyID = EventHotKeyID()
            GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            DispatchQueue.main.async {
                switch hotKeyID.id {
                case 1: HotKeyCenter.shared.onToggle?()
                case 2: HotKeyCenter.shared.onPause?()
                default: break
                }
            }
            return noErr
        }
        handlerUPP = upp
        InstallEventHandler(GetApplicationEventTarget(), upp, 1, &eventType, nil, &handlerRef)

        add(id: 1, AppSettings.shared.toggleShortcut)
        add(id: 2, AppSettings.shared.pauseShortcut)
    }

    func unregister() {
        for ref in hotKeyRefs {
            UnregisterEventHotKey(ref)
        }
        hotKeyRefs.removeAll()
        if let handlerRef {
            RemoveEventHandler(handlerRef)
            self.handlerRef = nil
        }
    }

    private func add(id: UInt32, _ shortcut: KeyShortcut) {
        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: OSType(0x434C4950), id: id)
        let status = RegisterEventHotKey(
            UInt32(shortcut.keyCode),
            shortcut.carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        if status == noErr, let ref {
            hotKeyRefs.append(ref)
        }
    }
}
