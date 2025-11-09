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
    let registry: WindowRegistry
    let axHelper: AccessibilityAPIHelper

    // Computed properties that delegate to frameManager
    var activeFrame: FrameController? {
        frameManager?.activeFrame
    }

    var rootFrame: FrameController? {
        frameManager?.rootFrame
    }

    init(logger: Logger, registry: WindowRegistry = DefaultWindowRegistry(), axHelper: AccessibilityAPIHelper = DefaultAccessibilityAPIHelper()) {
        self.logger = logger
        self.registry = registry
        self.axHelper = axHelper
        self.tracker = WindowTracker(logger: logger, registry: registry)
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

        // Startup phase: Synchronously discover and register existing windows
        // Note: We use registerExistingWindow() here (direct registration) rather than enqueueCommand()
        // because this is one-time discovery at initialization before callbacks are registered.
        // New windows that arrive during normal operation are enqueued through the command queue.
        // TODO: Consider unifying to always use enqueueCommand() if startup completeness becomes critical.
        // Currently the timing window between discovery and callback registration is negligible.
        for element in self.tracker.getWindows() {
            guard let windowId = self.registry.getOrRegister(element: element) else {
                self.logger.warning("Failed to register window with registry")
                continue
            }
            let windowController = WindowController(windowId: windowId, axHelper: axHelper)
            self.frameManager?.registerExistingWindow(windowController, windowId: windowId)
            do {
                try assignWindow(windowController, shouldFocus: false)
            } catch {
                self.logger.warning("Failed to assign initial window: \(error)")
                self.frameManager?.unregisterWindow(windowId: windowId)
            }
        }

        // Observer automatically syncs UI as windows are assigned. No manual refresh needed.

        // Register callbacks for window lifecycle events
        // New windows are enqueued as commands, ensuring atomic processing with frame operations
        tracker.onWindowOpened = { [weak self] element in
            guard let self = self else { return }
            guard let windowId = self.registry.getOrRegister(element: element) else {
                self.logger.warning("Failed to register window with registry on open")
                return
            }
            let windowController = WindowController(windowId: windowId, axHelper: axHelper)
            self.frameManager?.enqueueCommand(.windowAppeared(windowController, windowId))
        }

        tracker.onWindowClosed = { [weak self] element in
            guard let self = self else { return }
            guard let windowId = self.registry.getWindowId(for: element) else {
                self.logger.debug("Window closed but not found in registry")
                return
            }
            self.frameManager?.enqueueCommand(.windowDisappeared(windowId))
            // Unregister from registry to invalidate the WindowId and trigger cleanup.
            // This ensures stale WindowIds don't linger in frames with "Unknown" tabs.
            self.registry.unregister(windowId)
        }
    }

    func assignWindow(_ window: WindowController, shouldFocus: Bool) throws {
        try frameManager?.assignWindow(window, shouldFocus: shouldFocus)
        if shouldFocus {
            // Give the window a moment to settle after resize/move before focusing
            usleep(50_000)  // 50ms delay
            window.raise()
        }
    }

    func nextWindow() {
        frameManager?.enqueueCommand(.cycleWindowForward)
    }

    func previousWindow() {
        frameManager?.enqueueCommand(.cycleWindowBackward)
    }

    func splitHorizontally() throws {
        frameManager?.enqueueCommand(.splitHorizontally)
    }

    func splitVertically() throws {
        frameManager?.enqueueCommand(.splitVertically)
    }

    func closeActiveFrame() throws {
        frameManager?.enqueueCommand(.closeFrame)
    }

    // MARK: - Navigation Operations

    func navigateLeft() {
        frameManager?.enqueueCommand(.navigateLeft)
    }

    func navigateRight() {
        frameManager?.enqueueCommand(.navigateRight)
    }

    func navigateUp() {
        frameManager?.enqueueCommand(.navigateUp)
    }

    func navigateDown() {
        frameManager?.enqueueCommand(.navigateDown)
    }

    // MARK: - Move Window Operations

    func moveActiveWindowLeft() throws {
        frameManager?.enqueueCommand(.moveWindowLeft)
    }

    func moveActiveWindowRight() throws {
        frameManager?.enqueueCommand(.moveWindowRight)
    }

    func moveActiveWindowUp() throws {
        frameManager?.enqueueCommand(.moveWindowUp)
    }

    func moveActiveWindowDown() throws {
        frameManager?.enqueueCommand(.moveWindowDown)
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
