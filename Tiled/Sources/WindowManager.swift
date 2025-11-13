// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Jimmy Ma

import Cocoa

// MARK: - WindowManager
@MainActor
class WindowManager {
    var config: ConfigController = ConfigController()
    let logger: Logger
    let tracker: WindowTracker
    let registry: WindowRegistry
    let axHelper: AccessibilityAPIHelper
    let spaceManager: SpaceManager

    // Computed properties that delegate to spaceManager
    var activeFrame: FrameController? {
        spaceManager.activeFrameManager?.activeFrame
    }

    var rootFrame: FrameController? {
        spaceManager.activeFrameManager?.rootFrame
    }

    var frameManager: FrameManager? {
        spaceManager.activeFrameManager
    }

    init(logger: Logger, registry: WindowRegistry = DefaultWindowRegistry(), axHelper: AccessibilityAPIHelper = DefaultAccessibilityAPIHelper()) {
        self.logger = logger
        self.registry = registry
        self.axHelper = axHelper
        self.tracker = WindowTracker(logger: logger, registry: registry)
        self.spaceManager = SpaceManager(logger: logger, config: ConfigController(), axHelper: axHelper)
    }

    func initialize() {
        self.logger.debug("Initializing WindowManager")

        // Start space change detection (creates initial FrameManager)
        self.spaceManager.startTracking()

        inspectLayout()

        // Start tracking to discover existing windows
        self.tracker.startTracking()

        // Startup phase: Synchronously discover and register existing windows
        // Note: We use registerExistingWindow() here (direct registration) rather than enqueueCommand()
        // because this is one-time discovery at initialization before callbacks are registered.
        // New windows that arrive during normal operation are enqueued through the command queue.
        // Only assign windows that are on the active Space to prevent cross-Space pollution.
        // Windows on other Spaces will be discovered when those Spaces become active.
        for element in self.tracker.getWindows() {
            // Skip windows that are on other Spaces
            guard self.spaceManager.isWindowOnActiveSpace(element) else {
                continue
            }

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

            // Only assign windows that are on the active Space
            // Windows on other Spaces will be discovered when those Spaces become active
            guard self.spaceManager.isWindowOnActiveSpace(element) else {
                self.logger.debug("Window is on a different Space, deferring assignment")
                return
            }

            // Register in active space's window registry with cgWindowID
            guard let activeSpaceId = self.spaceManager.activeSpaceId else {
                self.logger.warning("No active space set")
                return
            }

            let spaceRegistry = self.spaceManager.getOrCreateRegistry(for: activeSpaceId)

            // Get cgWindowID (system authority on window identity)
            guard let cgWindowID = self.axHelper.getWindowID(element) else {
                self.logger.warning("Unable to get cgWindowID for new window")
                return
            }

            // Extract window's application PID
            guard let appPID = self.axHelper.getAppPID(element) else {
                self.logger.warning("Unable to get app PID for new window")
                return
            }

            // Create WindowId and register in space registry
            let windowId = WindowId(appPID: appPID, registry: self.registry)
            windowId._upgrade(cgWindowID: cgWindowID)
            spaceRegistry.register(windowId, withCGWindowID: cgWindowID)

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

    // MARK: - Shift Window Operations

    func shiftActiveWindowLeft() throws {
        frameManager?.enqueueCommand(.shiftWindowLeft)
    }

    func shiftActiveWindowRight() throws {
        frameManager?.enqueueCommand(.shiftWindowRight)
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
