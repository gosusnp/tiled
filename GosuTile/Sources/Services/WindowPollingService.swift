// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Jimmy Ma

import Cocoa
import ApplicationServices

/// Performs periodic validation of window state to detect changes.
///
/// This service acts as a fallback/validation mechanism for window tracking:
/// - Polls every 5-10 seconds to check current window state
/// - Compares with cached state to find opened/closed/focused changes
/// - Emits callbacks for detected changes (with deduplication)
/// - Complements real-time observer for robustness
///
/// Hybrid Strategy:
/// - Observer (real-time): ~10ms latency, may miss events
/// - Polling (fallback): 5-10s latency, catches everything
/// - Result: Responsive + Robust
///
/// Dependencies:
/// - WorkspaceProvider: For accessing running applications
/// - WindowProvider: For querying window information via Accessibility API
class WindowPollingService: @unchecked Sendable {
    let logger: Logger
    let workspaceProvider: WorkspaceProvider
    let windowProvider: WindowProvider

    /// Called when polling detects a new window
    var onWindowOpened: ((AXUIElement) -> Void)?

    /// Called when polling detects a window closure
    var onWindowClosed: ((AXUIElement) -> Void)?

    /// Called when polling detects a focus change
    var onWindowFocused: ((AXUIElement) -> Void)?

    // MARK: - Private Properties

    /// Timer for periodic window state validation
    /// Fires every 5-10 seconds to detect missed events
    private var pollingTimer: DispatchSourceTimer?

    /// Cache of currently known windows for state comparison
    /// Maps window key (e.g., "Safari:0x7f1234abcd") to AXUIElement
    /// Used to detect which windows opened/closed since last poll
    private var cachedWindowState: [String: AXUIElement] = [:]

    /// Last known focused window
    /// Used to detect focus changes
    private var lastFocusedWindow: AXUIElement?

    /// Queue for synchronizing polling state
    private let stateQueue = DispatchQueue(
        label: "com.tiled.window-polling.state",
        attributes: .concurrent
    )

    /// Flag to track if polling is currently active
    private var pollingRunning: Bool = false

    // MARK: - Initialization

    init(
        logger: Logger,
        workspaceProvider: WorkspaceProvider = RealWorkspaceProvider(),
        windowProvider: WindowProvider = RealWindowProvider()
    ) {
        self.logger = logger
        self.workspaceProvider = workspaceProvider
        self.windowProvider = windowProvider
    }

    deinit {
        stopPolling()
    }

    // MARK: - Public API

    /// Start polling for window changes
    func startPolling() {
        stateQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }

            guard !self.pollingRunning else {
                self.logger.debug("Polling already running")
                return
            }

            self.logger.info("Starting window polling...")

            // Create DispatchSourceTimer (independent of run loop mode)
            let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
            timer.schedule(wallDeadline: .now() + 7.0, repeating: 7.0)
            timer.setEventHandler { [weak self] in
                self?.performPollingValidation()
            }
            timer.resume()
            self.pollingTimer = timer

            self.pollingRunning = true

            self.logger.info("Window polling started with 7-second interval")
        }
    }

    /// Stop polling for window changes
    func stopPolling() {
        stateQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }

            guard self.pollingRunning else {
                self.logger.debug("Polling already stopped")
                return
            }

            self.logger.info("Stopping window polling...")

            // Cancel timer if it exists
            if let timer = self.pollingTimer {
                timer.cancel()
                self.pollingTimer = nil
            }

            // Clear cached window state
            self.cachedWindowState.removeAll()
            self.lastFocusedWindow = nil

            self.pollingRunning = false

            self.logger.info("Window polling stopped")
        }
    }

    /// Check if polling is currently running
    var isPolling: Bool {
        stateQueue.sync {
            pollingRunning
        }
    }

    // MARK: - Private: Polling Implementation

    /// Perform periodic validation of window state
    /// Called by polling timer every 5-10 seconds
    ///
    /// This should:
    /// 1. Get current windows via Accessibility API
    /// 2. Compare with cachedWindowState to find:
    ///    - Windows that were closed (in cache, not in current)
    ///    - Windows that were opened (in current, not in cache)
    ///    - Focus changes (if different from lastFocusedWindow)
    /// 3. Emit appropriate callbacks (with deduplication to avoid duplicates from observer)
    /// 4. Update cache with new state
    ///
    /// - Note: This runs on the main thread (timer callback)
    private func performPollingValidation() {
        // Get current windows
        let currentWindows = getAllWindowsForPolling()

        // Get current focus
        let currentFocus = getFocusedWindowForPolling()

        // Build set of current window keys
        var currentWindowKeys = Set<String>()
        for window in currentWindows {
            let key = getWindowKey(window)
            currentWindowKeys.insert(key)
        }

        // Find closed windows (in cache, not in current)
        for (cachedKey, cachedWindow) in cachedWindowState {
            if !currentWindowKeys.contains(cachedKey) {
                // Window was closed
                emitWindowClosedWithDeduplication(cachedWindow)
            }
        }

        // Find opened windows (in current, not in cache)
        for window in currentWindows {
            let key = getWindowKey(window)
            if cachedWindowState[key] == nil {
                // Window is new
                emitWindowOpenedWithDeduplication(window, key: key)
            }
        }

        // Check for focus changes
        if currentFocus != lastFocusedWindow {
            if let focusedWindow = currentFocus {
                onWindowFocused?(focusedWindow)
                lastFocusedWindow = focusedWindow
            }
        }

        // Update cache with current state
        cachedWindowState.removeAll()
        for window in currentWindows {
            let key = getWindowKey(window)
            cachedWindowState[key] = window
        }

        self.logger.debug("Polling validation complete: \(currentWindows.count) windows in cache")
    }

    /// Get all currently visible windows on the system
    /// This should mirror the logic from WindowTracker.getAllWindows()
    /// Returns windows sorted by z-index (front-to-back)
    ///
    /// - Returns: Array of AXUIElement representing all visible windows
    private func getAllWindowsForPolling() -> [AXUIElement] {
        var windows: [AXUIElement] = []

        for app in getApplicationsSortedByZIndex() {
            guard app.activationPolicy == .regular && !app.isHidden else { continue }

            let appWindows = windowProvider.getWindowsForApplication(app)
            windows += appWindows
        }

        return windows
    }

    /// Get applications sorted by z-index (front-to-back order)
    ///
    /// - Returns: Array of NSRunningApplication sorted by their frontmost window's z-index
    private func getApplicationsSortedByZIndex() -> [NSRunningApplication] {
        let apps = workspaceProvider.runningApplications
            .filter { $0.activationPolicy == .regular }

        // Get window list in front-to-back order
        guard let windowList = windowProvider.getWindowZOrder() else {
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

    /// Get the currently focused window
    ///
    /// Strategy:
    /// 1. Get the frontmost application
    /// 2. Get its focused window
    /// 3. Return the focused window or nil if none
    ///
    /// - Returns: The AXUIElement of the focused window, or nil if none
    private func getFocusedWindowForPolling() -> AXUIElement? {
        // Get the frontmost (focused) application
        guard let frontmostApp = workspaceProvider.frontmostApplication else {
            return nil
        }

        return windowProvider.getFocusedWindowForApplication(frontmostApp)
    }

    /// Create a unique key for a window for deduplication
    /// Used to identify windows across observer and polling mechanisms
    ///
    /// Strategy:
    /// - Combine window title with its memory address (stable during a poll cycle)
    /// - Create identifier like "Safari:Window#0x7f1234abcd"
    /// - Must be consistent within polling cycles for deduplication
    ///
    /// - Parameter element: The AXUIElement to create a key for
    /// - Returns: A stable unique identifier for this poll cycle
    private func getWindowKey(_ element: AXUIElement) -> String {
        // Create a stable key based on intrinsic window properties
        // PID + title is unique and stable across polling cycles
        let title = windowProvider.getTitleForWindow(element)
        var pid: pid_t = 0
        AXUIElementGetPid(element, &pid)

        // Stable key: process ID + window title
        let key = "\(pid):\(title)"
        return key
    }

    /// Emit window closed event with deduplication
    /// Only emit if not already emitted by observer
    ///
    /// Strategy:
    /// - Check if window is in cachedWindowState
    /// - Only call onWindowClosed if observer hasn't already notified
    /// - This prevents duplicate events
    ///
    /// - Parameter element: The window that was closed
    private func emitWindowClosedWithDeduplication(_ element: AXUIElement) {
        // Check if this window is in the cache (i.e., was previously known)
        let key = getWindowKey(element)
        if cachedWindowState[key] != nil {
            // It was in cache, so we haven't emitted yet
            self.logger.debug("Polling detected window closed")
            onWindowClosed?(element)
        } else {
            // Window was already removed from cache (likely by observer)
            self.logger.debug("Polling detected window closed but already in cache, skipping")
        }
    }

    /// Emit window opened event with deduplication
    /// Only emit if not already emitted by observer
    ///
    /// Strategy:
    /// - Check if window is already in cachedWindowState
    /// - Only call onWindowCreated if observer hasn't already notified
    /// - This prevents duplicate events
    ///
    /// - Parameters:
    ///   - element: The window that was opened
    ///   - key: The unique identifier for this window (for efficiency)
    private func emitWindowOpenedWithDeduplication(_ element: AXUIElement, key: String) {
        // Check if this window is already in the cache
        if cachedWindowState[key] == nil {
            // It's not in cache, so observer hasn't notified yet
            self.logger.debug("Polling detected window opened")
            onWindowOpened?(element)
        } else {
            // Window is already in cache (observer already notified)
            self.logger.debug("Polling detected window opened but already in cache, skipping")
        }
    }
}
