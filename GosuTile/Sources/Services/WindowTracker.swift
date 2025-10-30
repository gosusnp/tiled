// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Jimmy Ma

import Cocoa
import ApplicationServices

class WindowTracker: @unchecked Sendable {
    let logger: Logger
    private(set) var windows: [AXUIElement] = []

    var onWindowOpened: ((AXUIElement) -> Void)?
    var onWindowClosed: ((AXUIElement) -> Void)?
    var onWindowFocused: ((AXUIElement) -> Void)?

    init(logger: Logger) {
        self.logger = logger
    }

    func startTracking() {
        self.logger.debug("Starting window tracking")

        // Initial discovery - returns windows sorted by z-index (most recent first)
        self.windows = getAllWindows()

        self.logger.debug("Discovered \(self.windows.count) windows")

        // Notify subscribers about existing windows in order
        for window in self.windows {
            self.onWindowOpened?(window)
        }

        // Begin monitoring for changes (TODO: implement event detection)
    }

    func getWindows() -> [AXUIElement] {
        return self.windows
    }

    // MARK: - Window Discovery

    private func getAllWindows() -> [AXUIElement] {
        var windows: [AXUIElement] = []

        for app in getApplicationsSortedByZIndex() {
            guard app.activationPolicy == .regular && !app.isHidden else { continue }

            let appElement = AXUIElementCreateApplication(app.processIdentifier)
            var windowsRef: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef)

            if result == .success, let windowList = windowsRef as? [AXUIElement] {
                windows += windowList
            }
        }

        return windows
    }

    private func getApplicationsSortedByZIndex() -> [NSRunningApplication] {
        let apps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }

        // Get window list in front-to-back order
        guard let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return apps
        }

        // Map PID to lowest (frontmost) window index
        var pidToZIndex: [pid_t: Int] = [:]

        for (index, windowInfo) in windowList.enumerated() {
            if let pid = windowInfo[kCGWindowOwnerPID as String] as? pid_t {
                // Only store the first (frontmost) window for each PID
                if pidToZIndex[pid] == nil {
                    pidToZIndex[pid] = index
                }
            }
        }

        return apps
            // Filter apps with nil zIndex, likely on different screen
            .filter { pidToZIndex[$0.processIdentifier] != nil }
            // Sort apps by their frontmost window's z-index
            .sorted { app1, app2 in
            let z1 = pidToZIndex[app1.processIdentifier] ?? Int.max
            let z2 = pidToZIndex[app2.processIdentifier] ?? Int.max
            return z1 < z2  // Lower index = more in front
        }
    }
}
