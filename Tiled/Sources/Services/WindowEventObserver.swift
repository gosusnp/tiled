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

    /// Workspace observers for app launches and terminations
    private var workspaceLaunchObserver: NSObjectProtocol?
    private var workspaceTerminationObserver: NSObjectProtocol?

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
                    self.logger.debug(
                        "Failed to set up observer for \(app.localizedName ?? "Unknown") (pid: \(pid)): \(error)"
                    )
                }
            }

            // Listen for application launches and terminations
            self.setupWorkspaceObserver()

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

            // Remove workspace observers
            if let observer = self.workspaceLaunchObserver {
                NSWorkspace.shared.notificationCenter.removeObserver(observer)
                self.workspaceLaunchObserver = nil
            }
            if let observer = self.workspaceTerminationObserver {
                NSWorkspace.shared.notificationCenter.removeObserver(observer)
                self.workspaceTerminationObserver = nil
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
                // Silently skip system processes that don't support accessibility observers
                // (widget extensions, system services, etc.)
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
    }

    /// Create an AXObserver for a specific process
    ///
    /// - Parameter processID: The process ID to observe
    /// - Returns: AXObserver instance
    /// - Throws: ObserverError if creation fails
    private func createAXObserver(forProcessID processID: pid_t) throws -> AXObserver {
        var observer: AXObserver?

        // Set up observer callback
        // NOTE: Callback is intentionally empty due to Swift 6 strict concurrency restrictions
        // on passing AXUIElement across thread boundaries. WindowPollingService handles
        // all window detection via periodic polling instead.
        let result = AXObserverCreate(
            processID,
            { (_: AXObserver, _: AXUIElement, _: CFString?, _: UnsafeMutableRawPointer?) in
                // Observer is registered but callback is handled by polling service
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
    }

    // MARK: - Private: Observer Lifecycle

    /// Add observer to the main run loop
    /// Uses nonisolated because AXObserver is a CoreFoundation opaque type
    /// - Parameter observer: The AXObserver to add to the run loop
    nonisolated private func addObserverToRunLoop(_ observer: AXObserver) {
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
    /// Uses nonisolated because AXObserver is a CoreFoundation opaque type
    /// - Parameter observer: The AXObserver to remove from the run loop
    nonisolated private func removeObserverFromRunLoop(_ observer: AXObserver) {
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
        stateQueue.async { [weak self] in
            guard let self = self else { return }
            guard self.observersRunning else {
                return
            }

            self.logger.info("Application launched with pid \(pid), setting up observer...")

            do {
                try self.setupObserverForApplication(pid: pid)
            } catch {
                self.logger.error("Failed to observe new app (pid \(pid)): \(error)")
            }
        }
    }

    /// Handle an application terminating
    private func onApplicationTerminated(pid: pid_t) {
        logger.info("Application terminated with pid \(pid), removing observer...")

        stateQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }

            guard let observer = self.appObservers[pid] else {
                self.logger.debug("No observer found for terminated app (pid \(pid))")
                return
            }

            self.removeObserverFromRunLoop(observer)
            self.appObservers.removeValue(forKey: pid)
            self.observerSubscriptions.removeValue(forKey: pid)

            self.logger.info("Observer removed for terminated app (pid \(pid))")
        }
    }

    /// Set up workspace observer for app launches/terminations
    private func setupWorkspaceObserver() {
        let center = NSWorkspace.shared.notificationCenter

        // Observe for app launches
        workspaceLaunchObserver = center.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
                let pid = Int32(app.processIdentifier)
                self?.onApplicationLaunched(pid: pid)
            }
        }

        // Observe for app termination
        workspaceTerminationObserver = center.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
                let pid = Int32(app.processIdentifier)
                self?.onApplicationTerminated(pid: pid)
            }
        }

        logger.debug("Workspace observers set up for app launches and terminations")
    }

    // MARK: - Private: Event Handling
    // NOTE: Event handling deferred to WindowPollingService (Phase 2).
    // The AXObserver callback is intentionally empty to avoid Swift 6 concurrency issues.
    // WindowTracker coordinates both observer and polling service for complete coverage.

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
