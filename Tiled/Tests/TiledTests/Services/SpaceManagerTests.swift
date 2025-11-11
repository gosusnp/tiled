// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Jimmy Ma

import Cocoa
import Testing
@testable import Tiled

@Suite("SpaceManager Tests")
@MainActor
struct SpaceManagerTests {
    let logger: Logger

    init() {
        self.logger = Logger()
    }

    @Test("isWindowOnActiveSpace returns true when window is on current Space")
    func testWindowOnActiveSpace() throws {
        let mockHelper = MockAccessibilityAPIHelper()
        let spaceManager = SpaceManager(logger: logger, config: ConfigController(), axHelper: mockHelper)

        // Create a test window element
        let testWindow = AXUIElementCreateApplication(ProcessInfo.processInfo.processIdentifier)

        // Mock: window is on current Space
        mockHelper.getWindowIDResult = 100

        // Verify window is detected as being on active Space
        let isOnActiveSpace = spaceManager.isWindowOnActiveSpace(testWindow)
        #expect(isOnActiveSpace == true)
    }

    @Test("isWindowOnActiveSpace uses axHelper to determine Space membership")
    func testWindowOnActiveSpaceUsesAxHelper() throws {
        let mockHelper = MockAccessibilityAPIHelper()
        let spaceManager = SpaceManager(logger: logger, config: ConfigController(), axHelper: mockHelper)

        let testWindow = AXUIElementCreateApplication(ProcessInfo.processInfo.processIdentifier)

        // Mock: window ID is available, helper returns true (on active Space)
        mockHelper.getWindowIDResult = 100

        let isOnActiveSpace = spaceManager.isWindowOnActiveSpace(testWindow)
        #expect(isOnActiveSpace == true, "Should delegate to axHelper for Space detection")
    }

    @Test("isWindowOnActiveSpace returns false when window ID cannot be obtained")
    func testWindowIdNotObtained() throws {
        let mockHelper = MockAccessibilityAPIHelper()
        let spaceManager = SpaceManager(logger: logger, config: ConfigController(), axHelper: mockHelper)

        let testWindow = AXUIElementCreateApplication(ProcessInfo.processInfo.processIdentifier)

        // Mock: getWindowID returns nil (window ID unavailable)
        mockHelper.getWindowIDResult = nil

        let isOnActiveSpace = spaceManager.isWindowOnActiveSpace(testWindow)
        #expect(isOnActiveSpace == false)
    }

    @Test("activeFrameManager returns nil when no active Space")
    func testActiveFrameManagerNilWhenNoActiveSpace() throws {
        let mockHelper = MockAccessibilityAPIHelper()
        let spaceManager = SpaceManager(logger: logger, config: ConfigController(), axHelper: mockHelper)

        // Before startTracking(), there's no active Space
        let frameManager = spaceManager.activeFrameManager
        #expect(frameManager == nil)
    }

    @Test("activeFrameManager returns FrameManager after startTracking")
    func testActiveFrameManagerAfterStartTracking() throws {
        let mockHelper = MockAccessibilityAPIHelper()
        let spaceManager = SpaceManager(logger: logger, config: ConfigController(), axHelper: mockHelper)

        // Start tracking creates initial Space and FrameManager
        spaceManager.startTracking()

        let frameManager = spaceManager.activeFrameManager
        #expect(frameManager != nil)
    }
}
