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

    // MARK: - Services

    /// Observer for real-time window events (lazy to prevent early initialization)
    private var observer: WindowEventObserver!

    /// Polling service for periodic window state validation (lazy initialization)
    private var pollingService: WindowPollingService!

    init(logger: Logger) {
        self.logger = logger
        // MARK: - Phase 3 Integration: Step 1
        /// Observer will be initialized in startTracking() to ensure proper lifecycle
    }

    deinit {
        // Critical: Stop all services when tracker is deallocated
        // This prevents callbacks from firing on a deallocated object
        if observer != nil {
            observer.stopObserving()
        }
        if pollingService != nil {
            pollingService.stopPolling()
        }
    }

    func startTracking() {
        self.logger.debug("Starting window tracking")

        // Initialize observer on first call (lazy initialization)
        if observer == nil {
            self.observer = WindowEventObserver(logger: self.logger)
        }

        // Initialize polling service on first call (lazy initialization)
        if pollingService == nil {
            self.pollingService = WindowPollingService(logger: self.logger)
        }

        // Initial discovery - returns windows sorted by z-index (most recent first)
        self.windows = getAllWindows()

        self.logger.debug("Discovered \(self.windows.count) windows")

        // Note: onWindowOpened callback is NOT called here
        // The app will manually handle initial windows via getWindows()

        // Wire observer callbacks for real-time detection
        self.observer.onWindowCreated = { [weak self] element in
            self?.handleWindowCreated(element)
        }

        self.observer.onWindowClosed = { [weak self] element in
            self?.handleWindowClosed(element)
        }

        self.observer.onWindowFocused = { [weak self] element in
            self?.handleWindowFocused(element)
        }

        // Wire polling service callbacks for periodic validation
        self.pollingService.onWindowOpened = { [weak self] element in
            self?.handleWindowCreated(element)
        }

        self.pollingService.onWindowClosed = { [weak self] element in
            self?.handleWindowClosed(element)
        }

        self.pollingService.onWindowFocused = { [weak self] element in
            self?.handleWindowFocused(element)
        }

        // Start the observer to begin real-time event detection
        self.observer.startObserving()

        self.logger.debug("Window event observer started")

        // Start the polling service for periodic validation
        self.pollingService.startPolling()

        self.logger.debug("Window polling service started (7-second interval)")
    }

    func getWindows() -> [AXUIElement] {
        return self.windows
    }

    /// Stop tracking window events
    func stopTracking() {
        self.logger.debug("Stopping window tracking")

        // Stop observer - clear callbacks BEFORE stopping to prevent pending calls
        if observer != nil {
            self.observer.onWindowCreated = nil
            self.observer.onWindowClosed = nil
            self.observer.onWindowFocused = nil
            self.observer.stopObserving()
            self.logger.debug("Window event observer stopped")
        }

        // Stop polling service - clear callbacks BEFORE stopping to prevent pending calls
        if pollingService != nil {
            self.pollingService.onWindowOpened = nil
            self.pollingService.onWindowClosed = nil
            self.pollingService.onWindowFocused = nil
            self.pollingService.stopPolling()
            self.logger.debug("Window polling service stopped")
        }

        // Clear the cached windows list
        self.windows.removeAll()

        self.logger.debug("All window tracking services stopped")
    }

    // MARK: - Event Handlers

    /// Handle a window creation event from observer or polling service
    /// - Parameter element: The newly created window
    private func handleWindowCreated(_ element: AXUIElement) {
        // Check if already tracked (deduplication for observer + polling)
        guard !self.windows.contains(where: { $0 == element }) else {
            return
        }

        // Add to windows list
        self.windows.append(element)

        // Emit callback to subscribers
        self.onWindowOpened?(element)
    }

    /// Handle a window closure event from observer or polling service
    /// - Parameter element: The window that was closed
    private func handleWindowClosed(_ element: AXUIElement) {
        self.logger.debug("Window closed event received")

        // Remove from windows list
        self.windows.removeAll { $0 == element }

        // Emit callback to subscribers
        self.onWindowClosed?(element)

        self.logger.debug("Window removed from tracker, total windows: \(self.windows.count)")
    }

    /// Handle a window focus change event from observer or polling service
    /// - Parameter element: The window that gained focus
    private func handleWindowFocused(_ element: AXUIElement) {
        self.logger.debug("Window focused event received")

        // Verify the window is tracked (safety check)
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
                // Filter out windows on other desktops (multi-desktop support not yet implemented)
                let onCurrentDesktop = windowList.filter { window in
                    // Get window position to check if it's on current desktop
                    var posRef: CFTypeRef?
                    let posResult = AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &posRef)
                    guard posResult == .success, let posValue = posRef as! AXValue? else {
                        return false
                    }

                    var position = CGPoint.zero
                    AXValueGetValue(posValue, .cgPoint, &position)

                    // Check if window is within any screen's visible area
                    return NSScreen.screens.contains { screen in
                        screen.visibleFrame.contains(CGPoint(x: position.x + 1, y: position.y + 1))
                    }
                }
                windows += onCurrentDesktop
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
