// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Jimmy Ma

import Cocoa
import ApplicationServices

// MARK: - Workspace Provider Protocol

/// Protocol for accessing workspace and running applications
/// Allows mocking NSWorkspace for testing
protocol WorkspaceProvider {
    /// Get list of currently running applications
    var runningApplications: [NSRunningApplication] { get }

    /// Get the frontmost (currently focused) application
    var frontmostApplication: NSRunningApplication? { get }
}

// MARK: - Real Implementation

/// Default implementation using NSWorkspace
class RealWorkspaceProvider: WorkspaceProvider {
    var runningApplications: [NSRunningApplication] {
        NSWorkspace.shared.runningApplications
    }

    var frontmostApplication: NSRunningApplication? {
        NSWorkspace.shared.frontmostApplication
    }
}

// MARK: - Window Provider Protocol

/// Protocol for accessing window information via Accessibility API
/// Allows mocking AXUIElement queries for testing
protocol WindowProvider {
    /// Get all windows for a given application
    func getWindowsForApplication(_ app: NSRunningApplication) -> [AXUIElement]

    /// Get the focused window of an application
    func getFocusedWindowForApplication(_ app: NSRunningApplication) -> AXUIElement?

    /// Get the title of a window
    func getTitleForWindow(_ window: AXUIElement) -> String

    /// Get the z-index order of windows
    func getWindowZOrder() -> [[String: Any]]?

    /// Check if a window is on the current desktop (on-screen)
    /// Returns false for windows on other desktops or minimized
    func isWindowOnCurrentDesktop(_ window: AXUIElement) -> Bool

    /// Get the stable CGWindowID for a window
    /// CGWindowID persists across sleep/wake cycles and is more reliable than AXUIElement references
    func getWindowID(for element: AXUIElement) -> CGWindowID?
}

// MARK: - Real Implementation

/// Default implementation using Accessibility API
class RealWindowProvider: WindowProvider {
    func getWindowsForApplication(_ app: NSRunningApplication) -> [AXUIElement] {
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var windowsRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef)

        if result == .success, let windowList = windowsRef as? [AXUIElement] {
            return windowList
        }
        return []
    }

    func getFocusedWindowForApplication(_ app: NSRunningApplication) -> AXUIElement? {
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var focusedRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedWindowAttribute as CFString,
            &focusedRef
        )

        if result == .success, focusedRef != nil {
            return focusedRef as! AXUIElement
        }
        return nil
    }

    func getTitleForWindow(_ window: AXUIElement) -> String {
        var titleRef: CFTypeRef?
        AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleRef)
        return titleRef as? String ?? "Unknown"
    }

    func getWindowZOrder() -> [[String: Any]]? {
        return CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]]
    }

    func isWindowOnCurrentDesktop(_ window: AXUIElement) -> Bool {
        // Get the window's position
        var posRef: CFTypeRef?
        let posResult = AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &posRef)
        guard posResult == .success, let posValue = posRef as! AXValue? else {
            return false
        }

        var position = CGPoint.zero
        AXValueGetValue(posValue, .cgPoint, &position)

        // Get the current screen's visible frame
        // A window on a different desktop will have coordinates outside any screen's visible area
        for screen in NSScreen.screens {
            if screen.visibleFrame.contains(CGPoint(x: position.x + 1, y: position.y + 1)) {
                // Window's top-left corner is roughly within a screen's visible area
                return true
            }
        }

        return false
    }

    func getWindowID(for element: AXUIElement) -> CGWindowID? {
        // Get the PID of the window
        var pid: pid_t = 0
        AXUIElementGetPid(element, &pid)

        // Get the window's position
        var posRef: CFTypeRef?
        let posResult = AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &posRef)
        guard posResult == .success, let posValue = posRef as! AXValue? else {
            return nil
        }

        var position = CGPoint.zero
        AXValueGetValue(posValue, .cgPoint, &position)

        // Get the window's size
        var sizeRef: CFTypeRef?
        let sizeResult = AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeRef)
        guard sizeResult == .success, let sizeValue = sizeRef as! AXValue? else {
            return nil
        }

        var size = CGSize.zero
        AXValueGetValue(sizeValue, .cgSize, &size)

        // Search CGWindowList for a window matching this PID and bounds
        guard let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return nil
        }

        for windowInfo in windowList {
            // Check PID
            if let windowPID = windowInfo[kCGWindowOwnerPID as String] as? pid_t, windowPID != pid {
                continue
            }

            // Check position and size
            if let bounds = windowInfo[kCGWindowBounds as String] as? [String: Any],
               let x = bounds["X"] as? CGFloat,
               let y = bounds["Y"] as? CGFloat,
               let width = bounds["Width"] as? CGFloat,
               let height = bounds["Height"] as? CGFloat {

                // Match if position and size are close (allowing small differences due to rounding)
                let boundsRect = CGRect(x: x, y: y, width: width, height: height)
                let elementRect = CGRect(origin: position, size: size)

                // Allow 2-pixel tolerance for rounding differences
                if abs(boundsRect.origin.x - elementRect.origin.x) < 2,
                   abs(boundsRect.origin.y - elementRect.origin.y) < 2,
                   abs(boundsRect.size.width - elementRect.size.width) < 2,
                   abs(boundsRect.size.height - elementRect.size.height) < 2 {

                    if let windowID = windowInfo[kCGWindowNumber as String] as? CGWindowID {
                        return windowID
                    }
                }
            }
        }

        return nil
    }
}
