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
            logger.debug("Found window: \(w.appName): \(w.title)")
        }

        self.initializeLayout()
        self.rootFrame?.refreshOverlay()
    }

    func assignWindow(_ window: WindowController) throws {
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

        for app in NSWorkspace.shared.runningApplications {
            guard app.activationPolicy == .regular else { continue }

            let appElement = AXUIElementCreateApplication(app.processIdentifier)
            var windowsRef: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef)

            if result == .success, let windowList = windowsRef as? [AXUIElement] {
                windows += windowList.compactMap { WindowController.fromElement($0) }
            }
        }

        return windows
    }
}
