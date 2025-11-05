// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Jimmy Ma

import Cocoa
@testable import GosuTile

// MARK: - Window Provider Mock

class TestWindowProvider: WindowProvider {
    var returnWindows: [AXUIElement] = []
    var windowIDMap: [ObjectIdentifier: CGWindowID] = [:]

    func getWindowsForApplication(_ app: NSRunningApplication) -> [AXUIElement] {
        return returnWindows
    }

    func getFocusedWindowForApplication(_ app: NSRunningApplication) -> AXUIElement? {
        return returnWindows.first
    }

    func getTitleForWindow(_ window: AXUIElement) -> String {
        return "Test Window"
    }

    func getWindowZOrder() -> [[String: Any]]? {
        return nil
    }

    func isWindowOnCurrentDesktop(_ window: AXUIElement) -> Bool {
        return true
    }

    func getWindowID(for element: AXUIElement) -> CGWindowID? {
        return windowIDMap[ObjectIdentifier(element)]
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
