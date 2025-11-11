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

    private var spaceChangeObserver: NSObjectProtocol?
    private var currentMarkerWindow: NSWindow?

    /// Track all Spaces we've discovered
    /// Key: marker window number, Value: Space entity
    private var knownSpaces: [Int: Space] = [:]

    /// The currently active Space
    private var activeSpace: Space?

    init(logger: Logger, axHelper: AccessibilityAPIHelper = DefaultAccessibilityAPIHelper()) {
        self.logger = logger
        self.axHelper = axHelper
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

    private func handleSpaceChange() {
        // Find which Space we're currently on by looking for marker windows
        let currentSpaceMarkers = axHelper.getWindowNumbersOnCurrentSpace(withNameContaining: "Tiled-SpaceMarker")

        if let markerWindowNumber = currentSpaceMarkers.first, let space = knownSpaces[markerWindowNumber] {
            // Recognized existing Space
            activeSpace = space
            logger.debug("Space '\(space.id)' detected (marker: \(markerWindowNumber))")
        } else {
            // New Space - create a marker for it
            logger.debug("New Space detected, creating marker")
            createMarkerForCurrentSpace()
        }
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
        currentMarkerWindow = window

        logger.debug("Space '\(space.id)' created (marker: \(window.windowNumber))")
    }

}
