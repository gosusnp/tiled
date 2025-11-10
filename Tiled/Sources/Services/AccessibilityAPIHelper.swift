// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Jimmy Ma

import Cocoa

/// Protocol for Accessibility API interactions and window operations.
/// Abstracts all AX API calls and window queries/operations for testing and dependency injection.
protocol AccessibilityAPIHelper {
    // MARK: - Element Information

    /// Extract application PID from an AXUIElement
    func getAppPID(_ element: AXUIElement) -> pid_t?

    /// Extract CGWindowID from an AXUIElement by geometry matching
    func getWindowID(_ element: AXUIElement) -> CGWindowID?

    /// Extract CGWindowID from an AXUIElement using a pre-fetched window list
    /// This avoids repeated CGWindowListCopyWindowInfo calls during polling
    func getWindowID(_ element: AXUIElement, cachedWindowList: [[String: Any]]) -> CGWindowID?

    /// Extract Window Title from AXUIElement
    func getWindowTitle(_ element: AXUIElement) -> String

    /// Check if an element is still valid
    func isElementValid(_ element: AXUIElement) -> Bool

    // MARK: - Window Discovery

    /// Get all windows for a given application
    func getWindowsForApplication(_ app: NSRunningApplication) -> [AXUIElement]

    /// Get the focused window of an application
    func getFocusedWindowForApplication(_ app: NSRunningApplication) -> AXUIElement?

    /// Get the z-index order of windows
    func getWindowZOrder() -> [[String: Any]]?

    /// Check if a window is on the current desktop (on-screen)
    /// Returns false for windows on other desktops or minimized
    func isWindowOnCurrentDesktop(_ window: AXUIElement) -> Bool

    // MARK: - Window Operations

    /// Move the window to a specific position
    func move(_ element: AXUIElement, to: CGPoint) throws

    /// Raise the window to the front and focus it
    func raise(_ element: AXUIElement)

    /// Resize the window to a specific size
    func resize(_ element: AXUIElement, size: CGSize) throws
}

// MARK: - Default Implementation

/// Real implementation using Accessibility API
class DefaultAccessibilityAPIHelper: AccessibilityAPIHelper {
    func getAppPID(_ element: AXUIElement) -> pid_t? {
        var pid: pid_t = 0
        AXUIElementGetPid(element, &pid)
        return pid != 0 ? pid : nil
    }

    func getWindowID(_ element: AXUIElement) -> CGWindowID? {
        // Get the CGWindowList (this is the expensive operation)
        guard let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return nil
        }

        // Use the cached version
        return getWindowID(element, cachedWindowList: windowList)
    }

    func getWindowID(_ element: AXUIElement, cachedWindowList: [[String: Any]]) -> CGWindowID? {
        // Get the PID of the window
        var pid: pid_t = 0
        AXUIElementGetPid(element, &pid)

        // Get the window's position
        var posRef: CFTypeRef?
        let posResult = AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &posRef)
        guard posResult == .success, let posValue = posRef else {
            return nil
        }

        var position = CGPoint.zero
        AXValueGetValue(posValue as! AXValue, .cgPoint, &position)

        // Get the window's size
        var sizeRef: CFTypeRef?
        let sizeResult = AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeRef)
        guard sizeResult == .success, let sizeValue = sizeRef else {
            return nil
        }

        var size = CGSize.zero
        AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)

        // Search provided CGWindowList for a window matching this PID and bounds
        for windowInfo in cachedWindowList {
            // Check PID
            if let windowPID = windowInfo[kCGWindowOwnerPID as String] as? pid_t, windowPID == pid {
                // PID matches, continue to check bounds
            } else {
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

    func getWindowTitle(_ element: AXUIElement) -> String {
        var titleRef: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleRef)
        return titleRef as? String ?? "Unknown"
    }


    func isElementValid(_ element: AXUIElement) -> Bool {
        // Check if element is still valid by attempting to get a basic attribute
        var roleRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef)
        return result == .success
    }

    func move(_ element: AXUIElement, to: CGPoint) throws {
        var position = to
        guard let axPosition = AXValueCreate(.cgPoint, &position) else {
            throw WindowError.invalidWindow
        }

        let result = AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, axPosition)

        guard result == .success else {
            throw WindowError.moveFailed(result)
        }
    }

    func raise(_ element: AXUIElement) {
        var pid: pid_t = 0
        AXUIElementGetPid(element, &pid)

        // 1. First, activate the application
        if let app = NSRunningApplication(processIdentifier: pid) {
            if #available(macOS 14.0, *) {
                app.activate(options: .activateAllWindows)
            } else {
                app.activate(options: [.activateIgnoringOtherApps])
            }
        }

        // 2. Longer delay after app switcher usage
        usleep(100_000) // 100ms - increased delay

        // 3. Set as main window BEFORE raise action
        let appElement = AXUIElementCreateApplication(pid)
        AXUIElementSetAttributeValue(appElement, kAXMainWindowAttribute as CFString, element as CFTypeRef)

        // 4. Another small delay
        usleep(50_000) // 50ms

        // 5. Try the raise action
        AXUIElementPerformAction(element, kAXRaiseAction as CFString)

        // 6. Set focused attribute
        AXUIElementSetAttributeValue(element, kAXFocusedAttribute as CFString, kCFBooleanTrue)

        // 7. Force frontmost (this helps after app switcher)
        AXUIElementSetAttributeValue(appElement, kAXFrontmostAttribute as CFString, kCFBooleanTrue)

        // 8. Set main window again (helps with stubborn windows)
        AXUIElementSetAttributeValue(appElement, kAXMainWindowAttribute as CFString, element as CFTypeRef)
    }

    func resize(_ element: AXUIElement, size: CGSize) throws {
        var targetSize = size
        guard let axSize = AXValueCreate(.cgSize, &targetSize) else {
            throw WindowError.invalidWindow
        }

        let result = AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, axSize)

        guard result == .success else {
            throw WindowError.resizeFailed(result)
        }
    }

    // MARK: - Window Discovery Methods

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

        if result == .success {
            return (focusedRef as! AXUIElement)
        }
        return nil
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
}
