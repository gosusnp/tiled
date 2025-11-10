// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Jimmy Ma

import Cocoa
@testable import Tiled

// MARK: - Accessibility API Helper Mock

class TestAccessibilityAPIHelper: AccessibilityAPIHelper {
    var returnWindows: [AXUIElement] = []
    var windowIDMap: [ObjectIdentifier: CGWindowID] = [:]

    // MARK: - Element Information
    func getAppPID(_ element: AXUIElement) -> pid_t? {
        return 1234
    }

    func getWindowID(_ element: AXUIElement) -> CGWindowID? {
        return windowIDMap[ObjectIdentifier(element)]
    }

    func getWindowID(_ element: AXUIElement, cachedWindowList: [[String: Any]]) -> CGWindowID? {
        return windowIDMap[ObjectIdentifier(element)]
    }

    func getWindowTitle(_ element: AXUIElement) -> String {
        return "Test Window"
    }

    func isElementValid(_ element: AXUIElement) -> Bool {
        return true
    }

    // MARK: - Window Discovery
    func getWindowsForApplication(_ app: NSRunningApplication) -> [AXUIElement] {
        return returnWindows
    }

    func getFocusedWindowForApplication(_ app: NSRunningApplication) -> AXUIElement? {
        return returnWindows.first
    }

    func getWindowZOrder() -> [[String: Any]]? {
        return nil
    }

    func isWindowOnCurrentDesktop(_ window: AXUIElement) -> Bool {
        return true
    }

    // MARK: - Window Operations
    func move(_ element: AXUIElement, to: CGPoint) throws {
        // Mock: no-op
    }

    func raise(_ element: AXUIElement) {
        // Mock: no-op
    }

    func resize(_ element: AXUIElement, size: CGSize) throws {
        // Mock: no-op
    }
}

// MARK: - Workspace Provider Mock

class TestWorkspaceProvider: WorkspaceProvider {
    var runningApplications: [NSRunningApplication] {
        return NSWorkspace.shared.runningApplications
    }

    var frontmostApplication: NSRunningApplication? {
        return NSWorkspace.shared.frontmostApplication
    }
}
