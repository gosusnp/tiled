// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Jimmy Ma

import Cocoa
import Testing
@testable import Tiled

@Suite("WindowManager Tests")
@MainActor
struct WindowManagerTests {
    let logger: Logger

    init() {
        self.logger = Logger()
    }

    @Test("windowDisappeared removes window from map and frame")
    func testWindowDisappeared() async throws {
        let windowManager = WindowManager(logger: logger)
        let config = ConfigController()
        let testFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)

        // Set up FrameManager with a test frame
        let frameManager = FrameManager(config: config)
        frameManager.rootFrame = FrameController(rect: testFrame, config: config, axHelper: MockAccessibilityAPIHelper())
        frameManager.activeFrame = frameManager.rootFrame
        windowManager.frameManager = frameManager

        guard let frame = windowManager.activeFrame else {
            Issue.record("No active frame after setup")
            return
        }

        // Create WindowIds for test windows
        let windowId1 = WindowId(appPID: 1234, registry: windowManager.registry)
        let window1 = MockWindowController(windowId: windowId1)
        let windowId2 = WindowId(appPID: 1235, registry: windowManager.registry)
        let window2 = MockWindowController(windowId: windowId2)

        // TODO This shouldn't be called manually
        frameManager.windowControllerMap[windowId1.asKey()] = window1
        frameManager.windowControllerMap[windowId2.asKey()] = window2

        // Add windows to frame (through addWindow API)
        try frameManager.assignWindow(window1)
        try frameManager.assignWindow(window2)

        #expect(frame.windowStack.count == 2)
        #expect(frameManager.windowControllerMap.count == 2)

        // Enqueue windowDisappeared command for window1
        frameManager.enqueueCommand(.windowDisappeared(windowId2))
        // Give command queue time to process
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms

        // Verify window1 is removed
        #expect(frameManager.windowControllerMap[windowId2.asKey()] == nil)
        #expect(frame.windowStack.count == 1)
    }

    @Test("windowDisappeared focuses new active window when active window closes")
    func testWindowDisappearedFocusesNext() async throws {
        let windowManager = WindowManager(logger: logger)
        let config = ConfigController()
        let testFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)

        // Set up FrameManager with a test frame
        let frameManager = FrameManager(config: config)
        frameManager.rootFrame = FrameController(rect: testFrame, config: config, axHelper: MockAccessibilityAPIHelper())
        frameManager.activeFrame = frameManager.rootFrame
        windowManager.frameManager = frameManager

        guard let frame = windowManager.activeFrame else {
            Issue.record("No active frame after setup")
            return
        }

        // Create WindowIds for test windows
        let windowId1 = WindowId(appPID: 1234, registry: windowManager.registry)
        let window1 = MockWindowController(windowId: windowId1)
        let windowId2 = WindowId(appPID: 1235, registry: windowManager.registry)
        let window2 = MockWindowController(windowId: windowId2)

        // Register windows
        frameManager.windowControllerMap[windowId1.asKey()] = window1
        frameManager.windowControllerMap[windowId2.asKey()] = window2

        // Add windows to frame (through addWindow API)
        try frameManager.assignWindow(window1)
        try frameManager.assignWindow(window2)

        // Navigate to second window
        _ = frame.nextWindow()
        #expect(frame.windowStack.activeIndex == 1)

        // Close the active window by enqueuing command
        frameManager.enqueueCommand(.windowDisappeared(windowId2))
        // Give command queue time to process
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms

        // Verify window1 is now active
        #expect(frameManager.windowControllerMap[windowId2.asKey()] == nil)
        #expect(frame.windowStack.activeIndex == 0)
    }
}
