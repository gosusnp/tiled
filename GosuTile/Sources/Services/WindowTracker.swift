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

    // MARK: - Phase 3 Integration: Step 1
    /// Observer for real-time window events (lazy to prevent early initialization)
    private var observer: WindowEventObserver!

    init(logger: Logger) {
        self.logger = logger
        // MARK: - Phase 3 Integration: Step 1
        /// Observer will be initialized in startTracking() to ensure proper lifecycle
    }

    deinit {
        // Critical: Stop observer when tracker is deallocated
        // This prevents callbacks from firing on a deallocated object
        if observer != nil {
            observer.stopObserving()
        }
    }

    func startTracking() {
        self.logger.debug("Starting window tracking")

        // MARK: - Phase 3 Integration: Step 2
        /// Initialize observer on first call (lazy initialization)
        if observer == nil {
            self.observer = WindowEventObserver(logger: self.logger)
        }

        // Initial discovery - returns windows sorted by z-index (most recent first)
        self.windows = getAllWindows()

        self.logger.debug("Discovered \(self.windows.count) windows")

        // Notify subscribers about existing windows in order
        for window in self.windows {
            self.onWindowOpened?(window)
        }

        // MARK: - Phase 3 Integration: Step 2
        /// Wire observer callbacks and start observing
        self.observer.onWindowCreated = { [weak self] element in
            self?.handleWindowCreated(element)
        }

        self.observer.onWindowClosed = { [weak self] element in
            self?.handleWindowClosed(element)
        }

        self.observer.onWindowFocused = { [weak self] element in
            self?.handleWindowFocused(element)
        }

        // Start the observer to begin real-time event detection
        self.observer.startObserving()

        self.logger.debug("Window event observer started")
    }

    func getWindows() -> [AXUIElement] {
        return self.windows
    }

    // MARK: - Phase 3 Integration: Step 3
    /// Stop tracking window events
    func stopTracking() {
        self.logger.debug("Stopping window tracking")

        // Safety check: only stop if observer was initialized
        if observer != nil {
            // Clear callbacks BEFORE stopping observer to prevent any pending calls
            self.observer.onWindowCreated = nil
            self.observer.onWindowClosed = nil
            self.observer.onWindowFocused = nil

            // Stop the observer and clean up resources
            self.observer.stopObserving()
        }

        // Clear the cached windows list
        self.windows.removeAll()

        self.logger.debug("Window event observer stopped")
    }

    // MARK: - Phase 3 Integration: Step 4
    /// Event handler methods for observer callbacks

    /// Handle a window creation event
    /// - Parameter element: The newly created window
    private func handleWindowCreated(_ element: AXUIElement) {
        // TODO: Implementation
        // 1. Check if already tracked (deduplication)
        // 2. Add to self.windows if new
        // 3. Emit self.onWindowOpened?(element)
        // 4. Update polling cache (Phase 2)

        // Safety check: ensure we're still in a valid state
        guard !self.windows.isEmpty || self.windows.count >= 0 else {
            self.logger.warning("handleWindowCreated called in invalid state")
            return
        }

        self.logger.debug("Window created event received")

        // For now, check if already in list before adding
        guard !self.windows.contains(where: { $0 == element }) else {
            self.logger.debug("Window already tracked, skipping duplicate")
            return
        }

        // Add to windows list
        self.windows.append(element)

        // Emit callback to subscribers (safe to call on nil)
        self.onWindowOpened?(element)

        self.logger.debug("Window added to tracker, total windows: \(self.windows.count)")
    }

    /// Handle a window closure event
    /// - Parameter element: The window that was closed
    private func handleWindowClosed(_ element: AXUIElement) {
        // TODO: Implementation
        // 1. Remove from self.windows
        // 2. Emit self.onWindowClosed?(element)
        // 3. Update polling cache (Phase 2)
        self.logger.debug("Window closed event received")

        // Remove from windows list
        self.windows.removeAll { $0 == element }

        // Emit callback to subscribers
        self.onWindowClosed?(element)

        self.logger.debug("Window removed from tracker, total windows: \(self.windows.count)")
    }

    /// Handle a window focus change event
    /// - Parameter element: The window that gained focus
    private func handleWindowFocused(_ element: AXUIElement) {
        // TODO: Implementation
        // 1. Verify element is tracked (safety check)
        // 2. Emit self.onWindowFocused?(element)
        // 3. Update polling cache (Phase 2)
        self.logger.debug("Window focused event received")

        // Verify the window is tracked
        guard self.windows.contains(where: { $0 == element }) else {
            self.logger.warning("Focused window is not in tracked windows list")
            return
        }

        // Emit callback to subscribers
        self.onWindowFocused?(element)

        self.logger.debug("Window focus callback emitted")
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
