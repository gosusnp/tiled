// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Jimmy Ma

import Cocoa
import ApplicationServices

/// Observes window-related events from the Accessibility framework.
///
/// Listens for window creation, closing, and focus changes across all applications
/// using the AXObserver API. Manages observer lifecycle and automatically handles
/// application launches and terminations.
///
/// Uses a shared instance pattern to safely bridge between the AXObserver callback
/// (which may be called from a system thread) and the main actor-isolated state.
class WindowEventObserver: @unchecked Sendable {
    let logger: Logger

    /// Called when a window is created
    var onWindowCreated: ((AXUIElement) -> Void)?

    /// Called when a window is closed
    var onWindowClosed: ((AXUIElement) -> Void)?

    /// Called when the focused window changes
    var onWindowFocused: ((AXUIElement) -> Void)?

    // MARK: - Private Properties

    /// Shared instance for use in AXObserver callbacks
    /// We use a weak reference to avoid keeping the instance alive if it's deallocated elsewhere
    /// Marked as unsafe because:
    /// - This is mutable global state, but only accessed from callbacks routed through DispatchQueue.main.async
    /// - The weak reference ensures thread-safe access (returns nil if instance is deallocated)
    /// - All mutations happen on the main thread via startObserving() / stopObserving()
    nonisolated(unsafe) private static weak var sharedInstance: WindowEventObserver?

    /// Per-application observers (one observer per running app)
    /// Key: ProcessID (pid), Value: AXObserver instance
    private var appObservers: [pid_t: AXObserver] = [:]

    /// Tracks which notifications each app is subscribed to
    /// Key: ProcessID, Value: array of notification strings
    private var observerSubscriptions: [pid_t: [NSString]] = [:]

    /// Flag to track if observers are currently active
    private var observersRunning: Bool = false

    /// Queue for synchronizing observer state changes
    private let stateQueue = DispatchQueue(
        label: "com.tiled.window-event-observer.state",
        attributes: .concurrent
    )

    /// Workspace observer for app launches/terminations
    private var workspaceObserver: NSObjectProtocol?

    // MARK: - TODO: Polling Properties
    // These properties will be added in Phase 2 (Polling Implementation)

    /// TODO: Timer for periodic window state validation
    /// Should fire every 5-10 seconds to detect missed events
    /// private var pollingTimer: Timer?

    /// TODO: Cache of currently known windows for state comparison
    /// Maps AXUIElement to window metadata (title, app, etc)
    /// Used by polling to detect which windows opened/closed since last poll
    /// private var cachedWindowState: [String: WindowMetadata] = [:]

    /// TODO: Last known focused window
    /// Used by polling to detect focus changes
    /// private var lastFocusedWindow: AXUIElement?

    // MARK: - Initialization

    init(logger: Logger) {
        self.logger = logger
    }

    deinit {
        stopObserving()
    }

    // MARK: - Public API

    /// Start observing window events across all applications
    func startObserving() {
        stateQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }

            guard !self.observersRunning else {
                self.logger.debug("Observers already running")
                return
            }

            self.logger.info("Starting window event observer...")

            // Store shared instance for use in AXObserver callbacks
            WindowEventObserver.sharedInstance = self

            // Set up observers for all currently running applications
            let runningApps = NSWorkspace.shared.runningApplications
            var successCount = 0

            for app in runningApps {
                let pid = Int32(app.processIdentifier)

                do {
                    try self.setupObserverForApplication(pid: pid)
                    successCount += 1
                } catch {
                    self.logger.warning(
                        "Failed to set up observer for \(app.localizedName ?? "Unknown") (pid: \(pid)): \(error)"
                    )
                }
            }

            // Listen for application launches and terminations
            self.setupWorkspaceObserver()

            // TODO: Start polling timer
            // - Create a Timer that fires every 5-10 seconds
            // - Call self.performPollingValidation() on each fire
            // - Ensure timer runs on main thread (use Timer, not DispatchSourceTimer)
            // - Store timer in self.pollingTimer for later cleanup

            self.observersRunning = true

            self.logger.info(
                "Window event observer started. \(successCount) of \(runningApps.count) apps observed"
            )
        }
    }

    /// Stop observing all window events
    func stopObserving() {
        stateQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }

            guard self.observersRunning else {
                self.logger.debug("Observers already stopped")
                return
            }

            self.logger.info("Stopping window event observer...")

            // TODO: Stop polling timer
            // - Invalidate self.pollingTimer if it exists
            // - Set self.pollingTimer = nil
            // - Clear cached window state (self.cachedWindowState.removeAll())

            // Remove workspace observer
            if let observer = self.workspaceObserver {
                NSWorkspace.shared.notificationCenter.removeObserver(observer)
                self.workspaceObserver = nil
            }

            // Remove all application observers
            for (pid, observer) in self.appObservers {
                self.removeObserverFromRunLoop(observer)
                self.unsubscribeFromAllNotifications(observer: observer, pid: pid)
            }

            self.appObservers.removeAll()
            self.observerSubscriptions.removeAll()
            self.observersRunning = false

            // Clear shared instance
            WindowEventObserver.sharedInstance = nil

            self.logger.info("Window event observer stopped")
        }
    }

    /// Check if observers are currently running
    var isObserving: Bool {
        stateQueue.sync {
            observersRunning
        }
    }

    /// Get count of active observers
    var activeObserverCount: Int {
        stateQueue.sync {
            appObservers.count
        }
    }

    /// Get list of all observed process IDs
    var observedProcessIDs: [pid_t] {
        stateQueue.sync {
            Array(appObservers.keys)
        }
    }

    // MARK: - Private: Observer Setup

    /// Set up AXObserver for a specific application
    ///
    /// - Parameter pid: Process ID of the application
    /// - Throws: ObserverError if setup fails
    private func setupObserverForApplication(pid: pid_t) throws {
        // Check if observer already exists
        if appObservers[pid] != nil {
            logger.debug("Observer already exists for pid \(pid)")
            return
        }

        // Create observer for this process
        let observer = try createAXObserver(forProcessID: pid)

        // Subscribe to relevant notifications
        let notificationsToSubscribe: [NSString] = [
            kAXWindowCreatedNotification as NSString,
            kAXFocusedWindowChangedNotification as NSString,
            kAXApplicationActivatedNotification as NSString,
        ]

        var successCount = 0
        for notification in notificationsToSubscribe {
            do {
                try subscribeToNotification(
                    observer: observer,
                    notification: notification,
                    forApp: pid
                )
                successCount += 1
            } catch {
                logger.warning(
                    "Failed to subscribe to \(notification) for pid \(pid): \(error)"
                )
            }
        }

        // Verify we subscribed to at least some notifications
        if successCount == 0 {
            throw ObserverError.noNotificationsSubscribed(pid: pid)
        }

        // Add observer to run loop
        addObserverToRunLoop(observer)

        // Store reference
        appObservers[pid] = observer
        observerSubscriptions[pid] = notificationsToSubscribe

        logger.info("Observer set up for pid \(pid) with \(successCount) notifications")
    }

    /// Create an AXObserver for a specific process
    ///
    /// - Parameter processID: The process ID to observe
    /// - Returns: AXObserver instance
    /// - Throws: ObserverError if creation fails
    private func createAXObserver(forProcessID processID: pid_t) throws -> AXObserver {
        var observer: AXObserver?

        // The callback captures no state. It just signals that something happened.
        let result = AXObserverCreate(
            processID,
            { (_: AXObserver, element: AXUIElement, notification: CFString?, _: UnsafeMutableRawPointer?) in
                // Called by AccessibilityAPI from a system thread.
                // We store the element reference and notification in a thread-safe wrapper.
                let elementPtr = unsafeBitCast(element, to: UInt64.self)
                let notificationString = notification.map { $0 as String }

                // Dispatch with only Sendable types (pointers are safe to send)
                DispatchQueue.main.async {
                    if let instance = WindowEventObserver.sharedInstance {
                        // Reconstruct element from pointer
                        let elementRestored = unsafeBitCast(elementPtr, to: AXUIElement.self)
                        instance.handleObserverCallbackWithNotificationString(
                            element: elementRestored,
                            notificationString: notificationString
                        )
                    }
                }
            },
            &observer
        )

        guard result == .success, let observer = observer else {
            let error = NSError(
                domain: "AXError",
                code: Int(result.rawValue),
                userInfo: [
                    NSLocalizedDescriptionKey: "AXObserverCreate failed with code \(result)",
                ]
            )
            throw ObserverError.observerCreationFailed(pid: processID, error: error)
        }

        return observer
    }

    /// Subscribe to a specific notification for a process
    ///
    /// - Parameters:
    ///   - observer: The AXObserver to add subscription to
    ///   - notification: Notification key
    ///   - pid: Process ID for logging
    /// - Throws: ObserverError if subscription fails
    private func subscribeToNotification(
        observer: AXObserver,
        notification: NSString,
        forApp pid: pid_t
    ) throws {
        let appElement = AXUIElementCreateApplication(pid)

        let result = AXObserverAddNotification(
            observer,
            appElement,
            notification,
            nil
        )

        guard result == .success else {
            let error = NSError(
                domain: "AXError",
                code: Int(result.rawValue),
                userInfo: [
                    NSLocalizedDescriptionKey: "AXObserverAddNotification failed for \(notification)",
                ]
            )
            throw ObserverError.notificationSubscriptionFailed(notification: notification as String, error: error)
        }

        logger.debug("Subscribed to \(notification) for pid \(pid)")
    }

    // MARK: - Private: Observer Lifecycle

    /// Add observer to the main run loop
    /// Uses nonisolated(unsafe) because AXObserver is a CoreFoundation opaque type
    /// - Parameter observer: The AXObserver to add to the run loop
    nonisolated(unsafe) private func addObserverToRunLoop(_ observer: AXObserver) {
        // Use bitcast to convert observer to Sendable pointer for dispatch
        let observerPtr = unsafeBitCast(observer, to: UInt64.self)
        DispatchQueue.main.sync {
            let restoredObserver = unsafeBitCast(observerPtr, to: AXObserver.self)
            CFRunLoopAddSource(
                CFRunLoopGetMain(),
                AXObserverGetRunLoopSource(restoredObserver),
                CFRunLoopMode.defaultMode
            )
        }
    }

    /// Remove observer from the main run loop
    /// Uses nonisolated(unsafe) because AXObserver is a CoreFoundation opaque type
    /// - Parameter observer: The AXObserver to remove from the run loop
    nonisolated(unsafe) private func removeObserverFromRunLoop(_ observer: AXObserver) {
        // Use bitcast to convert observer to Sendable pointer for dispatch
        let observerPtr = unsafeBitCast(observer, to: UInt64.self)
        DispatchQueue.main.sync {
            let restoredObserver = unsafeBitCast(observerPtr, to: AXObserver.self)
            CFRunLoopRemoveSource(
                CFRunLoopGetMain(),
                AXObserverGetRunLoopSource(restoredObserver),
                CFRunLoopMode.defaultMode
            )
        }
    }

    /// Unsubscribe from all notifications for a process
    private func unsubscribeFromAllNotifications(observer: AXObserver, pid: pid_t) {
        guard let notifications = observerSubscriptions[pid] else {
            return
        }

        let appElement = AXUIElementCreateApplication(pid)

        for notification in notifications {
            let _ = AXObserverRemoveNotification(
                observer,
                appElement,
                notification as NSString
            )
        }

        logger.debug("Unsubscribed from all notifications for pid \(pid)")
    }

    // MARK: - Private: Application Lifecycle

    /// Handle a new application launching
    private func onApplicationLaunched(pid: pid_t) {
        guard observersRunning else {
            return
        }

        logger.info("Application launched with pid \(pid), setting up observer...")

        do {
            try setupObserverForApplication(pid: pid)
        } catch {
            logger.error("Failed to observe new app (pid \(pid)): \(error)")
        }
    }

    /// Handle an application terminating
    private func onApplicationTerminated(pid: pid_t) {
        logger.info("Application terminated with pid \(pid), removing observer...")

        guard let observer = appObservers[pid] else {
            logger.debug("No observer found for terminated app (pid \(pid))")
            return
        }

        removeObserverFromRunLoop(observer)
        appObservers.removeValue(forKey: pid)
        observerSubscriptions.removeValue(forKey: pid)

        logger.info("Observer removed for terminated app (pid \(pid))")
    }

    /// Set up workspace observer for app launches/terminations
    private func setupWorkspaceObserver() {
        let center = NSWorkspace.shared.notificationCenter

        workspaceObserver = center.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
                let pid = Int32(app.processIdentifier)
                self?.onApplicationLaunched(pid: pid)
            }
        }

        // Also observe for app termination
        let terminationObserver = center.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
                let pid = Int32(app.processIdentifier)
                self?.onApplicationTerminated(pid: pid)
            }
        }

        // Store both observers (we'll remove both on stop)
        if let existing = workspaceObserver {
            center.removeObserver(existing)
        }
        workspaceObserver = terminationObserver
    }

    // MARK: - Private: Event Handling

    /// Handle an AXObserver callback with the notification as a String
    ///
    /// Called on the main thread from the observer callback via DispatchQueue.main.async.
    /// The notification has been converted to a String (Sendable) before crossing thread boundaries.
    ///
    /// Uses nonisolated(unsafe) because:
    /// - We receive the non-Sendable AXUIElement directly (it's valid on this thread)
    /// - We're called on the main thread only (via DispatchQueue.main.async)
    /// - All accesses to instance callbacks happen directly (safe on main thread)
    ///
    /// - Parameters:
    ///   - element: The AXUIElement that the notification relates to
    ///   - notificationString: The notification type as a String (e.g., "AXWindowCreated")
    nonisolated(unsafe) private func handleObserverCallbackWithNotificationString(
        element: AXUIElement,
        notificationString: String?
    ) {
        guard let notificationString = notificationString else {
            return
        }

        logger.debug("Observer callback: \(notificationString)")

        switch notificationString {
        case kAXWindowCreatedNotification:
            // TODO: Update cache before calling callback
            // - Extract window metadata (title, app name, etc)
            // - Add to cachedWindowState with a unique key
            // - Use this to prevent duplicate events when polling also detects the same window
            onWindowCreated?(element)

        case kAXFocusedWindowChangedNotification:
            // TODO: Implement deduplication
            // - Check if lastFocusedWindow == element
            // - Only call callback if it's actually different from last known focus
            // - Update lastFocusedWindow = element
            onWindowFocused?(element)

        case kAXApplicationActivatedNotification:
            // TODO: This might also trigger a focus change
            // - Consider whether we need to trigger onWindowFocused here
            // - Or let polling handle it in the next validation cycle
            logger.debug("Application activated")

        default:
            logger.debug("Unknown notification: \(notificationString)")
        }
    }

    // MARK: - TODO: Polling Implementation
    // All methods in this section need to be implemented in Phase 2

    /// TODO: Perform periodic validation of window state
    /// Called by polling timer every 5-10 seconds
    ///
    /// This should:
    /// 1. Call WindowTracker.getAllWindows() to get current state
    /// 2. Compare with cachedWindowState to find:
    ///    - Windows that were closed (in cache, not in current)
    ///    - Windows that were opened (in current, not in cache)
    ///    - Focus changes (if different from lastFocusedWindow)
    /// 3. Emit appropriate callbacks (avoiding duplicates from observer)
    /// 4. Update cache with new state
    ///
    /// - Warning: Must handle non-Sendable types safely (use same pattern as observer)
    private func performPollingValidation() {
        // TODO: Implementation
        // 1. Get current windows: let currentWindows = getAllWindows()
        // 2. Get current focus: let currentFocus = getCurrentFocusedWindow()
        // 3. Compare state
        // 4. Emit missed events
        // 5. Update cache
    }

    /// TODO: Get all currently visible windows on the system
    /// This should mirror the logic from WindowTracker.getAllWindows()
    /// Returns windows sorted by z-index (front-to-back)
    ///
    /// - Returns: Array of AXUIElement representing all visible windows
    private func getAllWindowsForPolling() -> [AXUIElement] {
        // TODO: Implementation
        // Mirror WindowTracker.getAllWindows() logic
        return []
    }

    /// TODO: Get the currently focused window
    ///
    /// - Returns: The AXUIElement of the focused window, or nil if none
    private func getFocusedWindowForPolling() -> AXUIElement? {
        // TODO: Implementation
        // Use Accessibility API to get focused window
        return nil
    }

    /// TODO: Create a unique key for a window for deduplication
    /// Used to identify windows across observer and polling mechanisms
    ///
    /// - Parameter element: The AXUIElement to create a key for
    /// - Returns: A stable unique identifier (e.g., "Safari:0x7f1234abcd")
    private func getWindowKey(_ element: AXUIElement) -> String {
        // TODO: Implementation
        // Extract app name and window ID or PID
        // Format: "AppName:WindowID" or similar
        return ""
    }

    /// TODO: Emit window closed event with deduplication
    /// Only emit if not already emitted by observer
    ///
    /// - Parameter element: The window that was closed
    private func emitWindowClosedWithDeduplication(_ element: AXUIElement) {
        // TODO: Implementation
        // Check if this window is in cachedWindowState
        // Only call onWindowClosed if it hasn't already been notified
        // Remove from cache
    }

    /// TODO: Emit window opened event with deduplication
    /// Only emit if not already emitted by observer
    ///
    /// - Parameter element: The window that was opened
    private func emitWindowOpenedWithDeduplication(_ element: AXUIElement) {
        // TODO: Implementation
        // Check if this window is already in cachedWindowState
        // Only call onWindowCreated if it hasn't already been notified
        // Add to cache
    }

}

// MARK: - Error Types

enum ObserverError: LocalizedError {
    case observerCreationFailed(pid: pid_t, error: Error)
    case noNotificationsSubscribed(pid: pid_t)
    case notificationSubscriptionFailed(notification: String, error: Error)
    case observerNotFound(pid: pid_t)

    var errorDescription: String? {
        switch self {
        case let .observerCreationFailed(pid, error):
            return "Failed to create observer for process \(pid): \(error.localizedDescription)"
        case let .noNotificationsSubscribed(pid):
            return "Could not subscribe to any notifications for process \(pid)"
        case let .notificationSubscriptionFailed(notification, error):
            return "Failed to subscribe to \(notification): \(error.localizedDescription)"
        case let .observerNotFound(pid):
            return "No observer found for process \(pid)"
        }
    }
}
