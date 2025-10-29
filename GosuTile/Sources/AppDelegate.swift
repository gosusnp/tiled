// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Jimmy Ma

import Cocoa
@preconcurrency import ApplicationServices

// MARK: - AppDelegate
@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    let logger: Logger
    let hm: HotkeyManager
    let wm: WindowManager

    override init() {
        self.logger = Logger()
        self.wm = WindowManager(logger: self.logger)
        self.hm = HotkeyManager(windowManager: self.wm, logger: self.logger)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        self.ensureAccessibilityPermissions()
        self.wm.initialize()

        logger.info(
        """
        +==========================================+
        |    _____              _______ _ _        |
        |   / ____|            |__   __(_) |       |
        |  | |  __  ___  ___ _   _| |   _| | ___   |
        |  | | |_ |/ _ \\/ __| | | | |  | | |/ _ \\  |
        |  | |__| | (_) \\__ \\ |_| | |  | | |  __/  |
        |   \\_____|\\___/|___/\\__,_|_|  |_|_|\\___|  |
        +==========================================+
        """)
    }

    private func ensureAccessibilityPermissions() {
        let options: NSDictionary = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ]
        let trusted = AXIsProcessTrustedWithOptions(options)

        if !trusted {
            let alert = NSAlert()
            alert.messageText = "Accessibility Permission Required"
            alert.informativeText = "This app needs accessibility permissions to manage windows. Please grant permission in System Preferences > Security & Privacy > Privacy > Accessibility"
            alert.runModal()
        }
    }
}
