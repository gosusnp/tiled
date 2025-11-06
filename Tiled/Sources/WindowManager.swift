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

        // Bootstrap phase: Synchronously discover and register existing windows
        // Note: We use registerExistingWindow() here (direct registration) rather than enqueueCommand()
        // because this is one-time startup discovery, not ongoing event handling. After this phase,
        // new windows arrive via callbacks and are enqueued through the command queue.
        // TODO: Consider unifying to always use enqueueCommand() if we need guaranteed serialization
        // between bootstrap discovery and runtime events. Currently the risk window is negligible.
        for window in self.tracker.getWindows() {
            let windowController = WindowController.fromElement(window)
            self.frameManager?.registerExistingWindow(windowController, element: window)
            do {
                try assignWindow(windowController, shouldFocus: false)
            } catch {
                self.logger.warning("Failed to assign initial window: \(error)")
                self.frameManager?.unregisterWindow(element: window)
            }
        }

        self.rootFrame?.refreshOverlay()

        // Runtime phase: New windows arrive via callbacks and are queued through command processor
        // This ensures new windows are processed serially with frame operations
        tracker.onWindowOpened = { [weak self] element in
            let windowController = WindowController.fromElement(element)
            self?.frameManager?.enqueueCommand(.windowAppeared(windowController, element))
        }

        tracker.onWindowClosed = { [weak self] element in
            self?.frameManager?.enqueueCommand(.windowDisappeared(element))
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
