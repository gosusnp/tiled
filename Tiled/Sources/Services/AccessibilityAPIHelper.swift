// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Jimmy Ma

import Cocoa

/// Protocol for Accessibility API interactions.
/// Enables testing by allowing mocking of AX API calls.
protocol AccessibilityAPIHelper {
    /// Extract application PID from an AXUIElement
    func getAppPID(_ element: AXUIElement) -> pid_t?

    /// Extract CGWindowID from an AXUIElement by geometry matching
    func getWindowID(_ element: AXUIElement) -> CGWindowID?

    // Extract Window Title from AXUIElement
    func getWindowTitle(_ element: AXUIElement) -> String

    /// Check if an element is still valid
    func isElementValid(_ element: AXUIElement) -> Bool

    func move(_ element: AXUIElement, to: CGPoint) throws

    func raise(_ element: AXUIElement)

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

        // Search CGWindowList for a window matching this PID and bounds
        guard let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return nil
        }

        for windowInfo in windowList {
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
}
