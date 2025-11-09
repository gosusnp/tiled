// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Jimmy Ma

import Cocoa
import ApplicationServices

/// Performs periodic validation of window state to detect changes.
///
/// This service acts as a fallback/validation mechanism for window tracking:
/// - Polls every 5-10 seconds to check current window state
/// - Compares with cached state to find opened/closed/focused changes
/// - Emits callbacks for detected CGWindowID changes
/// - Complements real-time observer for robustness
///
/// Hybrid Strategy:
/// - Observer (real-time): ~10ms latency, may miss events
/// - Polling (fallback): 5-10s latency, catches everything
/// - Result: Responsive + Robust
///
/// Pure Polling:
/// - Detects changes in CGWindowID state only (stable system identifier)
/// - Local cache of what was seen last poll
/// - Fires callbacks for new/closed windows detected via CGWindowID comparison
/// - Caller (WindowTracker) responsible for deduplication and registry integration
/// - No knowledge of WindowId or WindowRegistry
///
/// Dependencies:
/// - WorkspaceProvider: For accessing running applications
/// - AccessibilityAPIHelper: For querying window information via Accessibility API
class WindowPollingService: @unchecked Sendable {
    let logger: Logger
    let workspaceProvider: WorkspaceProvider
    let axHelper: AccessibilityAPIHelper

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
    /// Maps CGWindowID to AXUIElement
    /// Used to detect which windows opened/closed since last poll
    /// This is pure polling state - what did we see in the last poll cycle?
    private var cachedWindowState: [CGWindowID: AXUIElement] = [:]

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
        axHelper: AccessibilityAPIHelper = DefaultAccessibilityAPIHelper()
    ) {
        self.logger = logger
        self.workspaceProvider = workspaceProvider
        self.axHelper = axHelper
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
    /// This performs pure CGWindowID state comparison:
    /// 1. Get current windows via Accessibility API
    /// 2. Compare with cachedWindowState to find:
    ///    - Windows that were closed (in cache, not in current)
    ///    - Windows that were opened (in current, not in cache)
    ///    - Focus changes (if different from lastFocusedWindow)
    /// 3. Emit appropriate callbacks (caller deduplicates)
    /// 4. Update cache with new state
    ///
    /// Deduplication:
    /// - Caller (WindowTracker.handleWindowCreated) deduplicates via local tracking
    /// - Same handler processes both observer and polling events
    /// - Registry integration happens in Tracker, not here
    ///
    /// - Note: This runs on the main thread (timer callback)
    private func performPollingValidation() {
        // Get current windows
        let currentWindows = getAllWindowsForPolling()

        // Get current focus
        let currentFocus = getFocusedWindowForPolling()

        // Build map of current windows by CGWindowID (pure state comparison)
        var currentWindowMap: [CGWindowID: AXUIElement] = [:]
        for window in currentWindows {
            if let windowID = axHelper.getWindowID(window) {
                currentWindowMap[windowID] = window
            }
        }

        // Find closed windows (in cache, not in current)
        for (cachedWindowID, cachedWindow) in cachedWindowState {
            if currentWindowMap[cachedWindowID] == nil {
                // Window was closed - fire callback
                onWindowClosed?(cachedWindow)
            }
        }

        // Find opened windows (in current, not in cache)
        for (windowID, window) in currentWindowMap {
            if cachedWindowState[windowID] == nil {
                // Window is new - fire callback, let caller deduplicate
                onWindowOpened?(window)
            }
        }

        // Check for focus changes
        if currentFocus != lastFocusedWindow {
            if let focusedWindow = currentFocus {
                onWindowFocused?(focusedWindow)
                lastFocusedWindow = focusedWindow
            }
        }

        // Update cache with current state for next poll
        cachedWindowState = currentWindowMap
    }

    /// Get all currently visible windows on the system
    /// Note: Order doesn't matter for polling - we only detect what opened/closed.
    /// Z-index sorting is only needed for initial discovery in WindowTracker.
    /// Does not filter multi-desktop windows - relies on initial filtered state from WindowTracker.
    ///
    /// - Returns: Array of AXUIElement representing all visible windows
    private func getAllWindowsForPolling() -> [AXUIElement] {
        var windows: [AXUIElement] = []

        for app in workspaceProvider.runningApplications {
            guard app.activationPolicy == .regular && !app.isHidden else { continue }

            let appWindows = axHelper.getWindowsForApplication(app)
            windows += appWindows
        }

        return windows
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

        return axHelper.getFocusedWindowForApplication(frontmostApp)
    }

}
