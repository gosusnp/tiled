// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Jimmy Ma

import Cocoa
@testable import Tiled

/// Comprehensive mock AccessibilityAPIHelper for testing
/// Supports tracking calls, simulating errors, and customizing return values
@MainActor
class MockAccessibilityAPIHelper: @preconcurrency AccessibilityAPIHelper {
    // MARK: - Call Tracking
    private(set) var raiseCallCount = 0
    private(set) var moveCallCount = 0
    private(set) var resizeCallCount = 0

    // MARK: - Call Details
    private(set) var lastMovePosition: CGPoint?
    private(set) var lastResizeSize: CGSize?

    // MARK: - Error Injection
    var moveError: Error?
    var resizeError: Error?

    // MARK: - Return Value Configuration
    var getWindowTitleResult: String = "Test Window"
    var getAppPIDResult: pid_t? = 1234
    var getWindowIDResult: CGWindowID?
    var isElementValidResult: Bool = true

    // MARK: - Implementation

    func raise(_ element: AXUIElement) {
        raiseCallCount += 1
    }

    func move(_ element: AXUIElement, to position: CGPoint) throws {
        if let error = moveError { throw error }
        moveCallCount += 1
        lastMovePosition = position
    }

    func resize(_ element: AXUIElement, size: CGSize) throws {
        if let error = resizeError { throw error }
        resizeCallCount += 1
        lastResizeSize = size
    }

    func getWindowTitle(_ element: AXUIElement) -> String {
        getWindowTitleResult
    }

    func getAppPID(_ element: AXUIElement) -> pid_t? {
        getAppPIDResult
    }

    func getWindowID(_ element: AXUIElement) -> CGWindowID? {
        getWindowIDResult
    }

    func isElementValid(_ element: AXUIElement) -> Bool {
        isElementValidResult
    }

    // MARK: - Window Discovery

    func getWindowsForApplication(_ app: NSRunningApplication) -> [AXUIElement] {
        []
    }

    func getFocusedWindowForApplication(_ app: NSRunningApplication) -> AXUIElement? {
        nil
    }

    func getWindowZOrder() -> [[String: Any]]? {
        nil
    }

    func isWindowOnCurrentDesktop(_ window: AXUIElement) -> Bool {
        true
    }

    // MARK: - Test Helpers

    func resetCallCounts() {
        raiseCallCount = 0
        moveCallCount = 0
        resizeCallCount = 0
    }
}
