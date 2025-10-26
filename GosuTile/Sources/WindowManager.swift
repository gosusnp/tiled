// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Jimmy Ma

import Cocoa
import ApplicationServices

// MARK: - WindowManager
class WindowManager {
    let logger: Logger
    var windows: [Window] = []

    init(logger: Logger) {
        self.logger = logger
    }

    func initialize() {
        self.logger.debug("Initializing WindowManager")
        self.windows = getAllWindows()

        for w in self.windows {
            logger.debug("Found window: \(w.appName): \(w.title)")
        }

    }

    private func getAllWindows() -> [Window] {
        var windows: [Window] = []

        for app in NSWorkspace.shared.runningApplications {
            guard app.activationPolicy == .regular else { continue }

            let appElement = AXUIElementCreateApplication(app.processIdentifier)
            var windowsRef: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef)

            if result == .success, let windowList = windowsRef as? [AXUIElement] {
                windows += windowList.compactMap { Window($0) }
            }
        }

        return windows
    }
}
