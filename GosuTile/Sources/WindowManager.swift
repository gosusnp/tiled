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
    let logger: Logger
    let tracker: WindowTracker

    init(logger: Logger) {
        self.logger = logger
        self.tracker = WindowTracker(logger: logger)
    }

    func initialize() {
        self.logger.debug("Initializing WindowManager")

        self.initializeLayout()

        // Start tracking to discover existing windows
        self.tracker.startTracking()

        // Manually add existing windows without focus
        for window in self.tracker.getWindows() {
            let windowController = WindowController.fromElement(window)
            do {
                try assignWindow(windowController, shouldFocus: false)
            } catch {
                self.logger.warning("Failed to assign initial window: \(error)")
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
        if let frame = self.activeFrame {
            try frame.split(direction: Direction.Horizontal)
        }
    }

    func splitVertically() throws {
        if let frame = self.activeFrame {
            try frame.split(direction: Direction.Vertical)
        }
    }

    // MARK: - Window Event Handlers

    private func onWindowOpened(_ element: AXUIElement) {
        let window = WindowController.fromElement(element)
        do {
            // Runtime windows (new windows created after initialization)
            try assignWindow(window, shouldFocus: true)
        } catch {
            self.logger.warning("Failed to assign window: \(error)")
        }
    }

    private func onWindowClosed(_ element: AXUIElement) {
        self.logger.debug("Window closed")
        // TODO: Remove window from frame
    }

    // MARK: - Layout

    private func initializeLayout() {
        guard let screen = NSScreen.main else { return }
        self.rootFrame = FrameController.fromScreen(screen, config: self.config)
        self.activeFrame = self.rootFrame

        inspectLayout()
    }

    private func inspectLayout() {
        if let frame = self.rootFrame {
            self.logger.debug("RootFrame: \(frame.toString())")
        } else {
            self.logger.debug("Unable to detect rootFrame")
        }
    }
}
