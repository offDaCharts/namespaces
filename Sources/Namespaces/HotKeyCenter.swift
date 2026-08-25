import Carbon
import Foundation
import NamespacesCore

@MainActor
final class HotKeyCenter {
    static let shared = HotKeyCenter()
    private var references: [UInt32: EventHotKeyRef] = [:]
    private var actions: [UInt32: () -> Void] = [:]
    private var nextID: UInt32 = 1

    private init() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var id = EventHotKeyID()
            let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
            if status == noErr { Task { @MainActor in HotKeyCenter.shared.actions[id.id]?() } }
            return noErr
        }, 1, &spec, nil, nil)
    }

    @discardableResult func register(_ shortcut: ShortcutSpec, action: @escaping () -> Void) -> UInt32? {
        let id = nextID; nextID += 1
        var reference: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: OSType(0x4E535043), id: id) // NSPC
        guard RegisterEventHotKey(shortcut.keyCode, shortcut.modifiers, hotKeyID, GetApplicationEventTarget(), 0, &reference) == noErr, let reference else { return nil }
        references[id] = reference; actions[id] = action; return id
    }

    func unregisterAll() {
        for reference in references.values { _ = UnregisterEventHotKey(reference) }
        references.removeAll(); actions.removeAll(); nextID = 1
    }
}
