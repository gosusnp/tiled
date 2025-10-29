// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Jimmy Ma

import Cocoa
import ApplicationServices

// MARK: - WindowManager
@MainActor
class WindowManager {
    var config: ConfigController = ConfigController()
    var activeFrame: FrameController? = nil
    var rootFrame: FrameController? = nil
    var windows: [WindowController] = []
    let logger: Logger

    init(logger: Logger) {
        self.logger = logger
    }

    func initialize() {
        self.logger.debug("Initializing WindowManager")
        self.windows = getAllWindows()

        for w in self.windows {
            logger.debug("Found window: [\(w.size)] \(w.appName): \(w.title)")
        }

        self.initializeLayout()
        self.rootFrame?.refreshOverlay()
    }

    func assignWindow(_ window: WindowController) throws {
        if let frame = self.activeFrame {
            try frame.addWindow(window)
        }
    }

    func nextWindow() {
        self.activeFrame?.nextWindow()
    }

    func previousWindow() {
        self.activeFrame?.previousWindow()
    }

    func splitHorizontally() throws {
        if let frame = self.activeFrame {
            try frame.split(direction: Direction.Horizontal)
        }
    }

    func splitVertically() throws {
        if let frame = self.activeFrame {
            try frame.split(direction: Direction.Vertical)
        }
    }

    private func initializeLayout() {
        guard let screen = NSScreen.main else { return }
        self.rootFrame = FrameController.fromScreen(screen, config: self.config)
        self.activeFrame = self.rootFrame

        inspectLayout()

        for w in self.windows {
            do {
                try assignWindow(w)
            } catch {
                self.logger.warning("Failed to assign \(w.title)")
            }
        }
    }

    private func inspectLayout() {
        if let frame = self.rootFrame {
            self.logger.debug("RootFrame: \(frame.toString())")
        } else {
            self.logger.debug("Unable to detect rootFrame")
        }
    }

    private func getAllWindows() -> [WindowController] {
        var windows: [WindowController] = []

        for app in getApplicationsSortedByZIndex() {
            guard app.activationPolicy == .regular && !app.isHidden else { continue }

            let appElement = AXUIElementCreateApplication(app.processIdentifier)
            var windowsRef: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef)

            if result == .success, let windowList = windowsRef as? [AXUIElement] {
                windows += windowList.compactMap { return WindowController.fromElement($0) }
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
