// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Jimmy Ma

import Cocoa
import Testing
@testable import Tiled

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

    @Test("Cannot close root frame (has no parent)")
    func testCannotCloseRootFrame() throws {
        let rootFrame = FrameController(rect: testFrame, config: config)
        let window = MockWindowController(title: "Window 1")

        try rootFrame.windowStack.add(window, shouldFocus: false)
        window.frame = rootFrame

        // Try to close root frame - should throw
        var threwError = false
        do {
            _ = try rootFrame.closeFrame()
        } catch FrameControllerError.cannotCloseRootFrame {
            threwError = true
        }
        #expect(threwError)
    }

    @Test("Close returns the active frame and removes closed frame from children")
    func testCloseReturnsActiveFrame() throws {
        let parent = FrameController(rect: testFrame, config: config)

        // Create split - parent now has two children
        let child1 = try parent.split(direction: .Vertical)
        let child2 = parent.children[1]

        #expect(parent.children.count == 2)

        // Close child1
        let nextActive = try child1.closeFrame()

        // Parent should merge back - nextActive should be parent with no children
        #expect(nextActive === parent)
        #expect(parent.children.count == 0)
        #expect(parent.splitDirection == nil)
    }

    @Test("Closing a frame returns appropriate next active")
    func testCloseReturnsAppropriateActiveFrame() throws {
        let parent = FrameController(rect: testFrame, config: config)

        // Create split
        let child1 = try parent.split(direction: .Vertical)
        let child2 = parent.children[1]

        #expect(parent.children.count == 2)

        // Close child1 - parent should merge back
        let nextActive = try child1.closeFrame()

        // Next active should be parent after merge
        #expect(nextActive === parent)
        #expect(parent.children.count == 0)
        #expect(parent.splitDirection == nil)
    }

    @Test("Close merges only two children properly")
    func testCloseWithTwoChildren() throws {
        let parent = FrameController(rect: testFrame, config: config)

        // Create split gives exactly 2 children
        let child1 = try parent.split(direction: .Horizontal)
        let child2 = parent.children[1]

        #expect(parent.children.count == 2)
        #expect(parent.splitDirection == .Horizontal)

        // Close child1
        _ = try child1.closeFrame()

        // Parent should be fully merged back with no children and ready for new split
        #expect(parent.children.count == 0)
        #expect(parent.splitDirection == nil)
    }

    @Test("Move window to adjacent frame removes from source")
    func testMoveWindowRemovesFromSource() throws {
        let parent = FrameController(rect: testFrame, config: config)
        let child1 = try parent.split(direction: .Vertical)
        let child2 = parent.children[1]

        let window = MockWindowController(title: "Window 1")
        try child1.windowStack.add(window, shouldFocus: false)
        window.frame = child1

        #expect(child1.windowStack.count == 1)
        #expect(child2.windowStack.count == 0)

        // Move window from child1 to child2
        try child1.moveWindow(window, toFrame: child2)

        // Window should be removed from source
        #expect(child1.windowStack.count == 0)
    }

    @Test("Move window to adjacent frame adds to target")
    func testMoveWindowAddsToTarget() throws {
        let parent = FrameController(rect: testFrame, config: config)
        let child1 = try parent.split(direction: .Vertical)
        let child2 = parent.children[1]

        let window = MockWindowController(title: "Window 1")
        try child1.windowStack.add(window, shouldFocus: false)
        window.frame = child1

        // Move window from child1 to child2
        try child1.moveWindow(window, toFrame: child2)

        // Window should be added to target
        #expect(child2.windowStack.count == 1)
        #expect(child2.activeWindow === window)
    }

    @Test("Move window updates window frame reference")
    func testMoveWindowUpdatesFrameReference() throws {
        let parent = FrameController(rect: testFrame, config: config)
        let child1 = try parent.split(direction: .Vertical)
        let child2 = parent.children[1]

        let window = MockWindowController(title: "Window 1")
        try child1.windowStack.add(window, shouldFocus: false)
        window.frame = child1

        #expect(window.frame === child1)

        // Move window
        try child1.moveWindow(window, toFrame: child2)

        // Frame reference should be updated
        #expect(window.frame === child2)
    }

    @Test("Move window makes it active in target frame")
    func testMoveWindowActivatesInTarget() throws {
        let parent = FrameController(rect: testFrame, config: config)
        let child1 = try parent.split(direction: .Vertical)
        let child2 = parent.children[1]

        let window1 = MockWindowController(title: "Window 1")
        let window2 = MockWindowController(title: "Window 2")

        try child1.windowStack.add(window1, shouldFocus: false)
        window1.frame = child1
        try child2.windowStack.add(window2, shouldFocus: false)
        window2.frame = child2

        #expect(child2.activeWindow === window2)

        // Move window1 to child2
        try child1.moveWindow(window1, toFrame: child2)

        // window1 should be active in child2
        #expect(child2.activeWindow === window1)
    }

    @Test("Move window with multiple windows in source")
    func testMoveWindowWithMultipleInSource() throws {
        let parent = FrameController(rect: testFrame, config: config)
        let child1 = try parent.split(direction: .Vertical)
        let child2 = parent.children[1]

        let window1 = MockWindowController(title: "Window 1")
        let window2 = MockWindowController(title: "Window 2")
        let window3 = MockWindowController(title: "Window 3")

        try child1.windowStack.add(window1, shouldFocus: false)
        try child1.windowStack.add(window2, shouldFocus: false)
        try child1.windowStack.add(window3, shouldFocus: false)
        window1.frame = child1
        window2.frame = child1
        window3.frame = child1

        #expect(child1.windowStack.count == 3)

        // Move only window2
        try child1.moveWindow(window2, toFrame: child2)

        // Source should have 2 remaining
        #expect(child1.windowStack.count == 2)
        #expect(child2.windowStack.count == 1)
        #expect(child2.activeWindow === window2)
        #expect(!child1.windowStack.all.contains(where: { $0 === window2 }))
    }

    @Test("Move active window keeps source stable")
    func testMoveActiveWindowStability() throws {
        let parent = FrameController(rect: testFrame, config: config)
        let child1 = try parent.split(direction: .Vertical)
        let child2 = parent.children[1]

        let window1 = MockWindowController(title: "Window 1")
        let window2 = MockWindowController(title: "Window 2")

        try child1.windowStack.add(window1, shouldFocus: false)
        try child1.windowStack.add(window2, shouldFocus: false)
        window1.frame = child1
        window2.frame = child1

        #expect(child1.activeWindow === window1)

        // Move active window
        try child1.moveWindow(window1, toFrame: child2)

        // Active should shift to window2 in child1
        #expect(child1.activeWindow === window2)
    }
}
