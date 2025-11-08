// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Jimmy Ma

import Cocoa
import ApplicationServices

class WindowTracker: @unchecked Sendable {
    let logger: Logger
    let registry: WindowRegistry

    // MARK: - Thread Safety

    /// Lock protecting windows array and trackedWindowIDs set access
    /// Prevents data corruption from concurrent access:
    /// - Polling loop iterates over windows every 7 seconds
    /// - Observer and polling callbacks append/remove windows and IDs concurrently
    /// - getAllWindows() bulk inserts during discovery
    /// Single lock eliminates deadlock risk and simplifies synchronization
    private let trackerLock = NSLock()

    private(set) var windows: [AXUIElement] = []

    /// Track window IDs (CGWindowID) to handle sleep/wake deduplication
    /// CGWindowID is stable across sleep/wake cycles unlike AXUIElement references
    private var trackedWindowIDs: Set<CGWindowID> = []

    var onWindowOpened: ((AXUIElement) -> Void)?
    var onWindowClosed: ((AXUIElement) -> Void)?
    var onWindowFocused: ((AXUIElement) -> Void)?

    // MARK: - Services

    /// Observer for real-time window events (lazy to prevent early initialization)
    private var observer: WindowEventObserver!

    /// Polling service for periodic window state validation (lazy initialization)
    private var pollingService: WindowPollingService!

    /// Window provider for getting stable window IDs
    private let windowProvider: WindowProvider

    init(
        logger: Logger,
        registry: WindowRegistry,
        windowProvider: WindowProvider = RealWindowProvider()
    ) {
        self.logger = logger
        self.registry = registry
        self.windowProvider = windowProvider
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
        trackerLock.lock()
        defer { trackerLock.unlock() }
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
        trackerLock.lock()
        defer { trackerLock.unlock() }
        return self.windows.map { $0 }  // Return copy to prevent caller from mutating shared state
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
        trackerLock.lock()
        defer { trackerLock.unlock() }
        self.windows.removeAll()

        self.logger.debug("All window tracking services stopped")
    }

    // MARK: - Locked State Operations

    /// Check if window should be tracked (not already tracked)
    /// Returns true if window is new and should be registered
    private func shouldTrackWindow(_ windowID: CGWindowID) -> Bool {
        trackerLock.lock()
        defer { trackerLock.unlock() }
        return !self.trackedWindowIDs.contains(windowID)
    }

    /// Register a new window in tracking state
    /// Caller must verify window is not already tracked
    private func registerWindow(_ element: AXUIElement, windowID: CGWindowID) {
        trackerLock.lock()
        defer { trackerLock.unlock() }
        self.windows.append(element)
        self.trackedWindowIDs.insert(windowID)
    }

    /// Unregister a window from tracking state
    /// Returns true if window was found and removed, false otherwise
    private func unregisterWindow(_ element: AXUIElement) -> Bool {
        trackerLock.lock()
        defer { trackerLock.unlock() }

        // Try to find by reference first
        if let index = self.windows.firstIndex(where: { $0 == element }) {
            let window = self.windows[index]
            if let windowID = self.windowProvider.getWindowID(for: window) {
                self.trackedWindowIDs.remove(windowID)
            }
            self.windows.remove(at: index)
            return true
        }

        // Fallback: try by ID matching
        if let windowID = self.windowProvider.getWindowID(for: element) {
            self.trackedWindowIDs.remove(windowID)
            self.windows.removeAll { window in
                if let wID = self.windowProvider.getWindowID(for: window), wID == windowID {
                    return true
                }
                return false
            }
            return true
        }

        // Last resort: reference comparison
        if let index = self.windows.firstIndex(where: { $0 == element }) {
            self.windows.remove(at: index)
            return true
        }

        return false
    }

    /// Check if a window is currently tracked
    private func isWindowTracked(_ element: AXUIElement) -> Bool {
        trackerLock.lock()
        defer { trackerLock.unlock() }
        return self.windows.contains(where: { $0 == element })
    }

    /// Get current window count
    private func getWindowCount() -> Int {
        trackerLock.lock()
        defer { trackerLock.unlock() }
        return self.windows.count
    }

    // MARK: - Event Handlers

    /// Handle a window creation event from observer or polling service
    /// - Parameter element: The newly created window
    private func handleWindowCreated(_ element: AXUIElement) {
        self.logger.debug("Window created event received")

        // Get stable window ID (persists across sleep/wake)
        guard let windowID = self.windowProvider.getWindowID(for: element) else {
            self.logger.warning("Unable to get window ID for new window")
            return
        }

        // Check if already tracked (lock-free check)
        guard shouldTrackWindow(windowID) else {
            self.logger.debug("Window already tracked by ID: \(windowID)")
            return
        }

        // Register window (narrow critical section)
        registerWindow(element, windowID: windowID)

        // Emit callback to subscribers (no lock held)
        self.onWindowOpened?(element)
    }

    /// Handle a window closure event from observer or polling service
    /// - Parameter element: The window that was closed
    private func handleWindowClosed(_ element: AXUIElement) {
        self.logger.debug("Window closed event received")

        // Unregister from tracking state (narrow critical section)
        guard unregisterWindow(element) else {
            self.logger.debug("Window not found in tracker")
            return
        }

        let windowCount = getWindowCount()

        // Emit callback to subscribers (no lock held)
        self.onWindowClosed?(element)
        self.logger.debug("Window removed from tracker, total windows: \(windowCount)")
    }

    /// Handle a window focus change event from observer or polling service
    /// - Parameter element: The window that gained focus
    private func handleWindowFocused(_ element: AXUIElement) {
        self.logger.debug("Window focused event received")

        // Verify the window is tracked (safety check, narrow critical section)
        guard isWindowTracked(element) else {
            self.logger.warning("Focused window is not in tracked windows list")
            return
        }

        // Emit callback to subscribers (no lock held)
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

                // Track windows by stable ID (lock held by caller)
                for window in onCurrentDesktop {
                    if let windowID = self.windowProvider.getWindowID(for: window) {
                        self.trackedWindowIDs.insert(windowID)
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
