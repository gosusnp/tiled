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

    /// Check if an element is still valid
    func isElementValid(_ element: AXUIElement) -> Bool
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

    func isElementValid(_ element: AXUIElement) -> Bool {
        // Check if element is still valid by attempting to get a basic attribute
        var roleRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef)
        return result == .success
    }
}
