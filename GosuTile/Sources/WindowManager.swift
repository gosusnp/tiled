// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Jimmy Ma

import Cocoa
import ApplicationServices

// MARK: - WindowManager
class WindowManager {
    var activeFrame: Frame? = nil
    var rootFrame: Frame? = nil
    var windows: [AppWindow] = []
    let logger: Logger

    init(logger: Logger) {
        self.logger = logger
    }

    func initialize() {
        self.logger.debug("Initializing WindowManager")
        self.windows = getAllWindows()

        for w in self.windows {
            logger.debug("Found window: \(w.appName): \(w.title)")
        }

        self.initializeLayout()
    }

    func assignWindow(_ window: AppWindow) throws {
        if let frame = self.activeFrame {
            try frame.addWindow(window)
        }
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
        let bounds = screen.visibleFrame
        self.rootFrame = Frame(rect: CGRect(
            x: bounds.minX,
            y: bounds.minY,
            width: bounds.width,
            height: bounds.height,
        ))
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

    private func getAllWindows() -> [AppWindow] {
        var windows: [AppWindow] = []

        for app in NSWorkspace.shared.runningApplications {
            guard app.activationPolicy == .regular else { continue }

            let appElement = AXUIElementCreateApplication(app.processIdentifier)
            var windowsRef: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef)

            if result == .success, let windowList = windowsRef as? [AXUIElement] {
                windows += windowList.compactMap { AppWindow($0) }
            }
        }

        return windows
    }
}
