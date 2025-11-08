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
        frameManager.rootFrame = FrameController(rect: testFrame, config: config)
        frameManager.activeFrame = frameManager.rootFrame
        windowManager.frameManager = frameManager

        guard let frame = windowManager.activeFrame else {
            Issue.record("No active frame after setup")
            return
        }

        let window1 = MockWindowController(title: "Window 1")
        let window2 = MockWindowController(title: "Window 2")

        // Create WindowIds for test windows
        let windowId1 = WindowId(appPID: 1234, registry: windowManager.registry)
        let windowId2 = WindowId(appPID: 1235, registry: windowManager.registry)

        // Manually register windows like lifecycle events would
        frameManager.windowControllerMap[windowId1.asKey()] = window1
        frameManager.windowControllerMap[windowId2.asKey()] = window2

        // Add windows to frame (bypassing AX calls)
        try frame.windowStack.add(window1, shouldFocus: false)
        try frame.windowStack.add(window2, shouldFocus: false)
        window1.frame = frame
        window2.frame = frame

        #expect(frame.windowStack.count == 2)
        #expect(frameManager.windowControllerMap.count == 2)

        // Enqueue windowDisappeared command for window1
        frameManager.enqueueCommand(.windowDisappeared(windowId1))
        // Give command queue time to process
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms

        // Verify window1 is removed
        #expect(frameManager.windowControllerMap[windowId1.asKey()] == nil)
        #expect(frame.windowStack.count == 1)
        #expect(frame.windowStack.getActiveWindow() === window2)
    }

    @Test("windowDisappeared focuses new active window when active window closes")
    func testWindowDisappearedFocusesNext() async throws {
        let windowManager = WindowManager(logger: logger)
        let config = ConfigController()
        let testFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)

        // Set up FrameManager with a test frame
        let frameManager = FrameManager(config: config)
        frameManager.rootFrame = FrameController(rect: testFrame, config: config)
        frameManager.activeFrame = frameManager.rootFrame
        windowManager.frameManager = frameManager

        guard let frame = windowManager.activeFrame else {
            Issue.record("No active frame after setup")
            return
        }

        let window1 = MockWindowController(title: "Window 1")
        let window2 = MockWindowController(title: "Window 2")

        // Create WindowIds for test windows
        let windowId1 = WindowId(appPID: 1234, registry: windowManager.registry)
        let windowId2 = WindowId(appPID: 1235, registry: windowManager.registry)

        // Register windows
        frameManager.windowControllerMap[windowId1.asKey()] = window1
        frameManager.windowControllerMap[windowId2.asKey()] = window2

        // Add windows to frame (bypassing AX calls)
        try frame.windowStack.add(window1, shouldFocus: false)
        try frame.windowStack.add(window2, shouldFocus: false)
        window1.frame = frame
        window2.frame = frame

        // Navigate to second window
        frame.nextWindow()
        #expect(frame.windowStack.getActiveWindow() === window2)

        // Close the active window by enqueuing command
        frameManager.enqueueCommand(.windowDisappeared(windowId2))
        // Give command queue time to process
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms

        // Verify window1 is now active
        #expect(frameManager.windowControllerMap[windowId2.asKey()] == nil)
        #expect(frame.windowStack.getActiveWindow() === window1)
    }
}
