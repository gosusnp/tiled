// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Jimmy Ma

import Cocoa
import ApplicationServices

// MARK: - AppDelegate
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        print(
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
}
