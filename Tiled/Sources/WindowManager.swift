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
        discoverWindowsForActiveSpace()

        // Observer automatically syncs UI as windows are assigned. No manual refresh needed.

        // Single handler for both observer and poller
        // Observer: just register, don't assign yet (windows not ready to snap)
        tracker.onWindowOpenedByObserver = { [weak self] element in
            guard let self = self else { return }

            // Register in global registry as ephemeral (no cgWindowID yet)
            guard let windowId = self.registry.getOrRegister(element: element) else {
                self.logger.debug("Observer: failed to register window")
                return
            }

            // Register in space registry as ephemeral
            guard let activeSpaceId = self.spaceManager.activeSpaceId else {
                return
            }
            let spaceRegistry = self.spaceManager.getOrCreateRegistry(for: activeSpaceId)
            spaceRegistry.registerEphemeral(windowId, forElement: element)

            self.logger.debug("Observer: registered ephemeral window \(windowId.id)")
        }

        // Poller: assign window (has cgWindowID, ready to snap)
        let windowOpenedHandler: (AXUIElement) -> Void = { [weak self] element in
            guard let self = self else { return }

            // For space detection: assume window is on active space
            guard self.spaceManager.isWindowOnActiveSpace(element) else {
                self.logger.debug("Window is on a different Space, deferring assignment")
                return
            }

            // Register or reuse WindowId (poller has cgWindowID, creates permanent)
            guard let windowId = self.registry.getOrRegister(element: element) else {
                self.logger.warning("Failed to register window with registry on open")
                return
            }

            // CRITICAL: Skip if window is already assigned to active frame
            if let frameManager = self.frameManager, frameManager.frameContaining(windowId) != nil {
                self.logger.debug("Window \(windowId.id) already in frame, skipping")
                return
            }

            self.logger.debug("Poller: window \(windowId.id) ready for assignment, enqueuing")

            let windowController = WindowController(windowId: windowId, axHelper: axHelper)
            self.frameManager?.enqueueCommand(.windowAppeared(windowController, windowId))
        }

        tracker.onWindowOpened = windowOpenedHandler

        tracker.onWindowClosed = { [weak self] element in
            guard let self = self else { return }
            guard let windowId = self.registry.getWindowId(for: element) else {
                self.logger.debug("Window closed but not found in registry")
                return
            }

            // Remove from space registry (permanent or ephemeral)
            if let activeSpaceId = self.spaceManager.activeSpaceId {
                let spaceRegistry = self.spaceManager.getOrCreateRegistry(for: activeSpaceId)
                if let cgWindowID = windowId.cgWindowID {
                    // Remove permanent window
                    spaceRegistry.unregister(by: cgWindowID)
                }
                // Ephemeral cleanup is handled via element-based removal
            }

            // Remove from global registry
            self.frameManager?.enqueueCommand(.windowDisappeared(windowId))
            self.registry.unregister(windowId)
        }

        // Hook into space changes
        // When space changes, we need to ensure windows on the new space are discovered quickly
        // Note: We don't call discoverWindowsForActiveSpace() directly because:
        // 1. Elements in tracker.getWindows() may become stale over time
        // 2. Stale elements can cause false positives with isWindowOnActiveSpace()
        // 3. Observer/poller callbacks handle discovery more reliably
        // However, we should enqueue a discovery task to find windows faster
        spaceManager.onSpaceChanged = { [weak self] in
            guard let self = self else { return }
            self.logger.debug("Space changed - enqueuing window discovery for new space")

            // Refresh active frame's UI
            if let frameManager = self.frameManager, let activeFrame = frameManager.activeFrame {
                activeFrame.refreshOverlay()
            }

            // Enqueue window discovery on space change for faster window assignment
            // Use a small delay to let the space settle
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.discoverWindowsForActiveSpace()
            }
        }
    }

    /// Discover and assign all windows that are on the currently active Space
    /// Called during initialization and when switching to a new Space
    ///
    /// Note: Only assigns windows that:
    /// 1. Are actually on the active space (verified by isWindowOnActiveSpace)
    /// 2. Are not already assigned to this space's frame (checked via frameMap)
    /// 3. Are successfully registered in the global registry
    /// 4. Have valid, retrievable window IDs (defensive against stale elements)
    private func discoverWindowsForActiveSpace() {
        for element in self.tracker.getWindows() {
            // Defensive: Try to get window ID first to verify element is valid/fresh
            // Tracker only returns windows on active space, so assume on active space
            // Bounds matching unreliable for stale elements anyway
            guard self.spaceManager.isWindowOnActiveSpace(element) else {
                continue
            }

            // Register window without bounds matching
            // cgWindowID will be discovered by poller if available
            guard let windowId = self.registry.getOrRegister(element: element) else {
                self.logger.warning("Failed to register window with registry")
                continue
            }

            // Skip windows already assigned to a frame in the active space
            if let frameManager = self.frameManager, frameManager.frameContaining(windowId) != nil {
                self.logger.debug("Window already assigned to frame in active space, skipping")
                continue
            }

            let windowController = WindowController(windowId: windowId, axHelper: axHelper)
            self.frameManager?.registerExistingWindow(windowController, windowId: windowId)
            do {
                try assignWindow(windowController, shouldFocus: false)
            } catch {
                self.logger.warning("Failed to assign window for active space: \(error)")
                self.frameManager?.unregisterWindow(windowId: windowId)
            }
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
