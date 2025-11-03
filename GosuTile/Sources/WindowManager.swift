// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Jimmy Ma

import Cocoa
import ApplicationServices

// MARK: - WindowManager
@MainActor
class WindowManager {
    var config: ConfigController = ConfigController()
    var frameManager: FrameManager?
    let logger: Logger
    let tracker: WindowTracker

    // Map of AXUIElement to WindowController for quick lookup
    var windowControllerMap: [AXUIElement: WindowController] = [:]

    // Computed properties that delegate to frameManager
    var activeFrame: FrameController? {
        frameManager?.activeFrame
    }

    var rootFrame: FrameController? {
        frameManager?.rootFrame
    }

    init(logger: Logger) {
        self.logger = logger
        self.tracker = WindowTracker(logger: logger)
    }

    func initialize() {
        self.logger.debug("Initializing WindowManager")

        // Initialize frame manager
        guard let screen = NSScreen.main else { return }
        self.frameManager = FrameManager(config: config, logger: logger)
        self.frameManager?.initializeFromScreen(screen)

        inspectLayout()

        // Start tracking to discover existing windows
        self.tracker.startTracking()

        // Manually add existing windows without focus
        for window in self.tracker.getWindows() {
            let windowController = WindowController.fromElement(window)
            windowControllerMap[window] = windowController
            do {
                try assignWindow(windowController, shouldFocus: false)
            } catch {
                self.logger.warning("Failed to assign initial window: \(error)")
                windowControllerMap.removeValue(forKey: window)
            }
        }

        self.rootFrame?.refreshOverlay()

        // Now register callback for new windows
        tracker.onWindowOpened = { [weak self] element in
            self?.onWindowOpened(element)
        }

        tracker.onWindowClosed = { [weak self] element in
            self?.onWindowClosed(element)
        }
    }

    func assignWindow(_ window: WindowController, shouldFocus: Bool) throws {
        guard let frame = self.activeFrame else { return }
        try frame.addWindow(window, shouldFocus: shouldFocus)
        frame.refreshOverlay()
        if shouldFocus {
            // Give the window a moment to settle after resize/move before focusing
            usleep(50_000)  // 50ms delay
            window.raise()
        }
    }

    func nextWindow() {
        self.activeFrame?.nextWindow()
    }

    func previousWindow() {
        self.activeFrame?.previousWindow()
    }

    func splitHorizontally() throws {
        try frameManager?.splitHorizontally()
    }

    func splitVertically() throws {
        try frameManager?.splitVertically()
    }

    // MARK: - Navigation Operations

    func navigateLeft() {
        frameManager?.navigateLeft()
    }

    func navigateRight() {
        frameManager?.navigateRight()
    }

    func navigateUp() {
        frameManager?.navigateUp()
    }

    func navigateDown() {
        frameManager?.navigateDown()
    }

    // MARK: - Window Event Handlers

    private func onWindowOpened(_ element: AXUIElement) {
        let window = WindowController.fromElement(element)
        windowControllerMap[element] = window  // Register in map
        do {
            // Runtime windows (new windows created after initialization)
            try assignWindow(window, shouldFocus: true)
        } catch {
            self.logger.warning("Failed to assign window: \(error)")
            windowControllerMap.removeValue(forKey: element)
        }
    }

    func onWindowClosed(_ element: AXUIElement) {
        guard let windowController = windowControllerMap[element] else {
            self.logger.warning("Closed window not found")
            return
        }

        guard let frame = windowController.frame else {
            self.logger.debug("Window has no frame (floating window)")
            windowControllerMap.removeValue(forKey: element)
            return
        }

        let wasActive = frame.activeWindow === windowController

        frame.removeWindow(windowController)
        windowControllerMap.removeValue(forKey: element)
        frame.refreshOverlay()

        if wasActive, let newActive = frame.activeWindow {
            newActive.raise()
        }

        self.logger.debug("Window removed, total windows: \(self.tracker.getWindows().count)")
    }

    // MARK: - Layout

    private func inspectLayout() {
        if let frame = self.rootFrame {
            self.logger.debug("RootFrame: \(frame.toString())")
        } else {
            self.logger.debug("Unable to detect rootFrame")
        }
    }
}
