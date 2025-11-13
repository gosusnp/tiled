// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Jimmy Ma

import Cocoa
import ApplicationServices

// MARK: - SpaceManager

/// Manages detection of macOS Space/Desktop changes.
/// Detects when the user switches between Spaces and provides hooks for lazy FrameManager creation.
@MainActor
class SpaceManager {
    let logger: Logger
    let axHelper: AccessibilityAPIHelper
    let config: ConfigController

    private var spaceChangeObserver: NSObjectProtocol?
    private var currentMarkerWindow: NSWindow?

    /// Track all Spaces we've discovered
    /// Key: marker window number, Value: Space entity
    private var knownSpaces: [Int: Space] = [:]

    /// The currently active Space
    private var activeSpace: Space?

    /// FrameManager per Space
    /// Key: Space ID, Value: FrameManager
    private var spaceFrameManagers: [UUID: FrameManager] = [:]

    /// WindowRegistry per Space
    /// Key: Space ID, Value: SpaceWindowRegistry
    private var spaceWindowRegistries: [UUID: SpaceWindowRegistry] = [:]

    /// The ID of the currently active Space
    private var _activeSpaceId: UUID?

    /// Callback fired when the active space changes
    var onSpaceChanged: (() -> Void)?

    init(logger: Logger, config: ConfigController, axHelper: AccessibilityAPIHelper = DefaultAccessibilityAPIHelper()) {
        self.logger = logger
        self.config = config
        self.axHelper = axHelper
    }

    /// Get the ID of the currently active Space
    var activeSpaceId: UUID? {
        return _activeSpaceId
    }

    /// Get the FrameManager for the currently active Space
    var activeFrameManager: FrameManager? {
        guard let activeSpaceId = _activeSpaceId else { return nil }
        return spaceFrameManagers[activeSpaceId]
    }

    /// Get the WindowRegistry for the currently active Space
    var activeWindowRegistry: SpaceWindowRegistry? {
        guard let activeSpaceId = _activeSpaceId else { return nil }
        return spaceWindowRegistries[activeSpaceId]
    }

    /// Check if a window is currently visible on the active Space
    /// Uses axHelper for CGWindow API queries (allows mocking in tests).
    /// Returns true if window appears in current Space's window list, false otherwise.
    func isWindowOnActiveSpace(_ element: AXUIElement) -> Bool {
        guard let windowID = axHelper.getWindowID(element) else { return false }
        return axHelper.isWindowOnCurrentSpace(windowID)
    }

    /// Get or create WindowRegistry for the given Space
    func getOrCreateRegistry(for spaceId: UUID) -> SpaceWindowRegistry {
        if let existing = spaceWindowRegistries[spaceId] {
            return existing
        }

        let registry = SpaceWindowRegistry(logger: logger)
        spaceWindowRegistries[spaceId] = registry
        logger.debug("Created WindowRegistry for Space '\(spaceId)'")

        return registry
    }

    /// Start listening for space change notifications.
    func startTracking() {
        let center = NSWorkspace.shared.notificationCenter

        spaceChangeObserver = center.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Ensure we're on the MainActor before calling handleSpaceChange
            Task { @MainActor [weak self] in
                self?.handleSpaceChange()
            }
        }

        logger.debug("SpaceManager: Started tracking space changes")

        // Create marker for the initial Space
        createMarkerForCurrentSpace()
    }

    /// Stop listening for space change notifications.
    func stopTracking() {
        if let observer = spaceChangeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            spaceChangeObserver = nil
        }
        logger.debug("SpaceManager: Stopped tracking space changes")
    }

    // MARK: - Private

    /// Get or create a FrameManager for the given Space
    private func getOrCreateFrameManager(for spaceId: UUID) -> FrameManager {
        if let existing = spaceFrameManagers[spaceId] {
            return existing
        }

        // Create new FrameManager
        let manager = FrameManager(config: config, logger: logger)
        guard let screen = NSScreen.main else {
            logger.warning("No main screen available for FrameManager initialization")
            spaceFrameManagers[spaceId] = manager
            return manager
        }

        manager.initializeFromScreen(screen)
        spaceFrameManagers[spaceId] = manager
        logger.debug("Created FrameManager for Space '\(spaceId)'")

        return manager
    }

    private func handleSpaceChange() {
        // Find which Space we're currently on by looking for marker windows
        let currentSpaceMarkers = axHelper.getWindowNumbersOnCurrentSpace(withNameContaining: "Tiled-SpaceMarker")

        if let markerWindowNumber = currentSpaceMarkers.first, let space = knownSpaces[markerWindowNumber] {
            // Recognized existing Space
            activeSpace = space
            _activeSpaceId = space.id
            logger.debug("Space '\(space.id)' detected (marker: \(markerWindowNumber))")
        } else {
            // New Space - create a marker for it
            logger.debug("New Space detected, creating marker")
            createMarkerForCurrentSpace()
        }

        // Ensure we have a FrameManager for the active Space
        if let activeSpaceId = activeSpaceId {
            _ = getOrCreateFrameManager(for: activeSpaceId)
        }

        // Notify listeners that the space has changed
        // This gives FrameManager a chance to refresh UI if needed
        onSpaceChanged?()
    }

    private func createMarkerForCurrentSpace() {
        // Create an invisible window to mark the current Space
        // Window is hidden but detectable via CGWindow API
        let window = NSWindow(
            contentRect: NSRect(x: -10000, y: -10000, width: 1, height: 1),
            styleMask: [],
            backing: .buffered,
            defer: false
        )
        window.title = "Tiled-SpaceMarker"
        window.isReleasedWhenClosed = false
        window.alphaValue = 0.0
        window.ignoresMouseEvents = true
        window.setFrame(NSRect(x: -10000, y: -10000, width: 1, height: 1), display: false)
        window.orderBack(nil)

        // Create Space entity and register it
        let space = Space(markerWindowNumber: window.windowNumber)
        knownSpaces[window.windowNumber] = space
        activeSpace = space
        _activeSpaceId = space.id
        currentMarkerWindow = window

        // Create FrameManager for this Space
        _ = getOrCreateFrameManager(for: space.id)

        logger.debug("Space '\(space.id)' created (marker: \(window.windowNumber))")
    }

    // MARK: - Testing

    /// Test helper: Set active space directly (for unit tests)
    /// Mirrors handleSpaceChange() by creating FrameManager for the space
    func _setActiveSpace(id spaceId: UUID) {
        _activeSpaceId = spaceId
        logger.debug("Test helper: Set active space to '\(spaceId)'")

        // Mirror handleSpaceChange() by creating FrameManager
        _ = getOrCreateFrameManager(for: spaceId)
    }

}
