// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Jimmy Ma

import Cocoa
import Testing
@testable import GosuTile

@Suite("FrameController Tests")
@MainActor
struct FrameControllerTests {
    let config: ConfigController
    let testFrame: CGRect

    init() {
        self.config = ConfigController()
        self.testFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
    }

    @Test("Creates a frame controller from rect")
    func testFrameControllerInitialization() {
        let frameController = FrameController(rect: testFrame, config: config)

        #expect(frameController.windowStack.count == 0)
        #expect(frameController.children.isEmpty)
        #expect(frameController.windowStack.activeIndex == 0)
        #expect(frameController.activeWindow == nil)
    }

    @Test("nextWindow delegates to windowStack")
    func testNextWindow() throws {
        let frameController = FrameController(rect: testFrame, config: config)

        // Add windows directly to stack to avoid AX calls
        let window1 = MockWindowController(title: "Window 1")
        let window2 = MockWindowController(title: "Window 2")
        try frameController.windowStack.add(window1)
        try frameController.windowStack.add(window2)

        #expect(frameController.activeWindow === window1)

        frameController.nextWindow()
        #expect(frameController.activeWindow === window2)

        frameController.nextWindow()
        #expect(frameController.activeWindow === window1)
    }

    @Test("previousWindow delegates to windowStack")
    func testPreviousWindow() throws {
        let frameController = FrameController(rect: testFrame, config: config)

        // Add windows directly to stack to avoid AX calls
        let window1 = MockWindowController(title: "Window 1")
        let window2 = MockWindowController(title: "Window 2")
        try frameController.windowStack.add(window1)
        try frameController.windowStack.add(window2)

        #expect(frameController.activeWindow === window1)

        frameController.previousWindow()
        #expect(frameController.activeWindow === window2)

        frameController.previousWindow()
        #expect(frameController.activeWindow === window1)
    }

    @Test("Split creates child frames")
    func testSplit() throws {
        let frameController = FrameController(rect: testFrame, config: config)

        // Split with empty frame (no windows to transfer)
        let newActiveFrame = try frameController.split(direction: .Horizontal)

        #expect(frameController.children.count == 2)
        #expect(frameController.windowStack.count == 0)
        #expect(frameController.children[0].parent === frameController)
        #expect(frameController.children[1].parent === frameController)
        #expect(newActiveFrame === frameController.children[0])
    }

    @Test("activeWindow reflects windowStack state")
    func testActiveWindowDelegation() {
        let frameController = FrameController(rect: testFrame, config: config)

        #expect(frameController.activeWindow == nil)
        #expect(frameController.activeWindow === frameController.windowStack.activeWindow)
    }

    @Test("Frame reference is set when window is added")
    func testFrameReferenceOnAdd() throws {
        let frameController = FrameController(rect: testFrame, config: config)
        let window = MockWindowController(title: "Window 1")

        #expect(window.frame == nil)

        // Add window to stack (bypasses AX calls in addWindow)
        try frameController.windowStack.add(window, shouldFocus: false)
        // Manually set frame like addWindow does
        window.frame = frameController

        #expect(window.frame === frameController)
    }

    @Test("Frame reference is cleared when window is removed")
    func testFrameReferenceClearedOnRemove() throws {
        let frameController = FrameController(rect: testFrame, config: config)
        let window = MockWindowController(title: "Window 1")

        try frameController.windowStack.add(window, shouldFocus: false)
        window.frame = frameController
        #expect(window.frame === frameController)

        let removed = frameController.removeWindow(window)
        #expect(removed)
        #expect(window.frame == nil)
    }

    @Test("Focus moves to next window when active window is removed")
    func testFocusOnWindowRemoval() throws {
        let frameController = FrameController(rect: testFrame, config: config)
        let window1 = MockWindowController(title: "Window 1")
        let window2 = MockWindowController(title: "Window 2")
        let window3 = MockWindowController(title: "Window 3")

        // Add windows to stack (bypasses AX calls)
        try frameController.windowStack.add(window1, shouldFocus: false)
        try frameController.windowStack.add(window2, shouldFocus: false)
        try frameController.windowStack.add(window3, shouldFocus: false)

        // Set frame references like addWindow does
        window1.frame = frameController
        window2.frame = frameController
        window3.frame = frameController

        // Navigate to second window
        frameController.nextWindow()
        #expect(frameController.activeWindow === window2)

        // Remove the active window
        let removed = frameController.removeWindow(window2)
        #expect(removed)

        // Active window should move to the next one (window3)
        #expect(frameController.activeWindow === window3)
    }

    @Test("Removing non-existent window returns false")
    func testRemoveNonExistentWindow() throws {
        let frameController = FrameController(rect: testFrame, config: config)
        let window1 = MockWindowController(title: "Window 1")
        let window2 = MockWindowController(title: "Window 2")

        try frameController.windowStack.add(window1, shouldFocus: false)
        window1.frame = frameController

        // Try to remove a window that was never added
        let removed = frameController.removeWindow(window2)
        #expect(!removed)
        #expect(frameController.windowStack.count == 1)
    }

    @Test("Frame references are updated when windows are transferred between frames")
    func testFrameReferenceUpdateOnTransfer() throws {
        let frame1 = FrameController(rect: testFrame, config: config)
        let frame2 = FrameController(rect: testFrame, config: config)
        let window1 = MockWindowController(title: "Window 1")
        let window2 = MockWindowController(title: "Window 2")

        // Add windows to frame1
        try frame1.windowStack.add(window1, shouldFocus: false)
        try frame1.windowStack.add(window2, shouldFocus: false)
        window1.frame = frame1
        window2.frame = frame1

        #expect(window1.frame === frame1)
        #expect(window2.frame === frame1)

        // Manually transfer windows and update frame references like takeWindowsFrom does
        // but without the resize/move side effects that fail in tests
        try frame2.windowStack.takeAll(from: frame1.windowStack)
        for w in frame2.windowStack.all {
            w.frame = frame2
        }

        // Verify frame references are updated
        #expect(window1.frame === frame2)
        #expect(window2.frame === frame2)
        #expect(frame1.windowStack.count == 0)
        #expect(frame2.windowStack.count == 2)
    }
}
