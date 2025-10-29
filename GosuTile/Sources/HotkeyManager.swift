// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Jimmy Ma

import Cocoa
import Carbon

// MARK: - HotkeyManager
class HotkeyManager {
    private let wm: WindowManager
    private var eventHandler: EventHandlerRef?
    private var hotkeys: [(EventHotKeyRef?, () -> Void)] = []

    init(windowManager: WindowManager) {
        self.wm = windowManager
    }

    func registerHotkeys() {
        registerEventHandler()

        let windowManager = self.wm

        registerHotkey(key: kVK_ANSI_N, mods: cmdKey | shiftKey) {
            Task { @MainActor in
                windowManager.nextWindow()
            }
        }

        registerHotkey(key: kVK_ANSI_P, mods: cmdKey | shiftKey) {
            Task { @MainActor in
                windowManager.previousWindow()
            }
        }
    }

    private func registerEventHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: OSType(kEventHotKeyPressed)
        )

        let selfPtr = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData -> OSStatus in
                guard let userData = userData else { return OSStatus(eventNotHandledErr) }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()

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

                // Execute handler for this hotkey
                if Int(hotKeyID.id) < manager.hotkeys.count {
                    manager.hotkeys[Int(hotKeyID.id)].1()
                }

                return noErr
            },
            1,
            &eventType,
            selfPtr,
            &(self.eventHandler)
        )
    }

    private func registerHotkey(key: Int, mods: Int, handler: @escaping () -> Void) {
        let id = UInt32(self.hotkeys.count)
        let hotKeyID = EventHotKeyID(signature: OSType(0x494F4E31), id: id)
        var hotKeyRef: EventHotKeyRef?

        RegisterEventHotKey(
            UInt32(key),
            UInt32(mods),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        self.hotkeys.append((hotKeyRef, handler))
    }
}
