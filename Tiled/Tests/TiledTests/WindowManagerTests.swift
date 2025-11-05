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

    @Test("onWindowClosed removes window from map and frame")
    func testOnWindowClosed() throws {
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

        // Manually register windows like onWindowOpened would
        windowManager.windowControllerMap[window1.window.element] = window1
        windowManager.windowControllerMap[window2.window.element] = window2

        // Add windows to frame (bypassing AX calls)
        try frame.windowStack.add(window1, shouldFocus: false)
        try frame.windowStack.add(window2, shouldFocus: false)
        window1.frame = frame
        window2.frame = frame

        #expect(frame.windowStack.count == 2)
        #expect(windowManager.windowControllerMap.count == 2)

        // Close first window by calling onWindowClosed
        windowManager.onWindowClosed(window1.window.element)

        // Verify window1 is removed
        #expect(windowManager.windowControllerMap[window1.window.element] == nil)
        #expect(frame.windowStack.count == 1)
        #expect(frame.windowStack.activeWindow === window2)
    }

    @Test("onWindowClosed focuses new active window when active window closes")
    func testOnWindowClosedFocusesNext() throws {
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

        // Register windows
        windowManager.windowControllerMap[window1.window.element] = window1
        windowManager.windowControllerMap[window2.window.element] = window2

        // Add windows to frame (bypassing AX calls)
        try frame.windowStack.add(window1, shouldFocus: false)
        try frame.windowStack.add(window2, shouldFocus: false)
        window1.frame = frame
        window2.frame = frame

        // Navigate to second window
        frame.nextWindow()
        #expect(frame.activeWindow === window2)

        // Close the active window
        windowManager.onWindowClosed(window2.window.element)

        // Verify window1 is now active
        #expect(windowManager.windowControllerMap[window2.window.element] == nil)
        #expect(frame.activeWindow === window1)
    }
}
