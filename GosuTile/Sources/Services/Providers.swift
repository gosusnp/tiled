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
}
