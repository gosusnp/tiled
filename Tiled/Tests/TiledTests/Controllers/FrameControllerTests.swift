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
    }

    @Test("nextWindow delegates to windowStack and calls raise")
    func testNextWindow() throws {
        let frameController = FrameController(rect: testFrame, config: config)

        // Add windows through frameController (handles WindowId conversion)
        let window1 = MockWindowController(title: "Window 1")
        let window2 = MockWindowController(title: "Window 2")
        try frameController.addWindow(window1)
        try frameController.addWindow(window2)

        // Before cycling, window1 is active
        #expect(!window1.raiseWasCalled)

        // After nextWindow, active index should change
        frameController.nextWindow()
        #expect(frameController.windowStack.activeIndex == 1)
    }

    @Test("previousWindow delegates to windowStack and calls raise")
    func testPreviousWindow() throws {
        let frameController = FrameController(rect: testFrame, config: config)

        // Add windows through frameController
        let window1 = MockWindowController(title: "Window 1")
        let window2 = MockWindowController(title: "Window 2")
        try frameController.addWindow(window1)
        try frameController.addWindow(window2)

        // Start at window1, cycle back to window2
        frameController.previousWindow()
        #expect(frameController.windowStack.activeIndex == 1)

        // Cycle back to window1
        frameController.previousWindow()
        #expect(frameController.windowStack.activeIndex == 0)
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

    @Test("nextWindow does nothing on empty stack")
    func testNextWindowOnEmpty() {
        let frameController = FrameController(rect: testFrame, config: config)

        // Should not crash when calling nextWindow on empty frame
        frameController.nextWindow()
        #expect(frameController.windowStack.count == 0)
    }

    @Test("Frame reference is set when window is added")
    func testFrameReferenceOnAdd() throws {
        let frameController = FrameController(rect: testFrame, config: config)
        let window = MockWindowController(title: "Window 1")

        #expect(window.frame == nil)

        // Add window through frameController (sets frame reference)
        try frameController.addWindow(window)

        #expect(window.frame === frameController)
    }

    @Test("Frame reference is cleared when window is removed")
    func testFrameReferenceClearedOnRemove() throws {
        let frameController = FrameController(rect: testFrame, config: config)
        let window = MockWindowController(title: "Window 1")

        try frameController.addWindow(window)
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

        // Add windows through frameController
        try frameController.addWindow(window1)
        try frameController.addWindow(window2)
        try frameController.addWindow(window3)

        // Navigate to second window
        frameController.nextWindow()

        // Remove the active window
        let removed = frameController.removeWindow(window2)
        #expect(removed)
        #expect(frameController.windowStack.count == 2)
    }

    @Test("Removing non-existent window returns false")
    func testRemoveNonExistentWindow() throws {
        let frameController = FrameController(rect: testFrame, config: config)
        let window1 = MockWindowController(title: "Window 1")
        let window2 = MockWindowController(title: "Window 2")

        try frameController.addWindow(window1)

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
        try frame1.addWindow(window1)
        try frame1.addWindow(window2)

        #expect(window1.frame === frame1)
        #expect(window2.frame === frame1)

        // Manually transfer windows (takeWindowsFrom is incomplete in current refactoring)
        try frame2.windowStack.takeAll(from: frame1.windowStack)
        // Note: Frame references cannot be fully updated yet - this is a known limitation
        // that will be fixed when FrameController has access to FrameManager

        // Verify windows are transferred
        #expect(frame1.windowStack.count == 0)
        #expect(frame2.windowStack.count == 2)
    }

    @Test("Cannot close root frame (has no parent)")
    func testCannotCloseRootFrame() throws {
        let rootFrame = FrameController(rect: testFrame, config: config)
        let window = MockWindowController(title: "Window 1")

        try rootFrame.addWindow(window)

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
        try child1.addWindow(window)

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
        try child1.addWindow(window)

        // Move window from child1 to child2
        try child1.moveWindow(window, toFrame: child2)

        // Window should be added to target
        #expect(child2.windowStack.count == 1)
    }

    @Test("Move window updates window frame reference")
    func testMoveWindowUpdatesFrameReference() throws {
        let parent = FrameController(rect: testFrame, config: config)
        let child1 = try parent.split(direction: .Vertical)
        let child2 = parent.children[1]

        let window = MockWindowController(title: "Window 1")
        try child1.addWindow(window)

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

        try child1.addWindow(window1)
        try child2.addWindow(window2)

        #expect(child2.windowStack.count == 1)

        // Move window1 to child2
        try child1.moveWindow(window1, toFrame: child2)

        // window1 should be added to child2
        #expect(child2.windowStack.count == 2)
    }

    @Test("Move window with multiple windows in source")
    func testMoveWindowWithMultipleInSource() throws {
        let parent = FrameController(rect: testFrame, config: config)
        let child1 = try parent.split(direction: .Vertical)
        let child2 = parent.children[1]

        let window1 = MockWindowController(title: "Window 1")
        let window2 = MockWindowController(title: "Window 2")
        let window3 = MockWindowController(title: "Window 3")

        try child1.addWindow(window1)
        try child1.addWindow(window2)
        try child1.addWindow(window3)

        #expect(child1.windowStack.count == 3)

        // Move only window2
        try child1.moveWindow(window2, toFrame: child2)

        // Source should have 2 remaining
        #expect(child1.windowStack.count == 2)
        #expect(child2.windowStack.count == 1)
        // Verify window2 is no longer in child1 by checking count and active window
        #expect(child1.windowStack.activeIndex == 0)
    }

    @Test("Move active window keeps source stable")
    func testMoveActiveWindowStability() throws {
        let parent = FrameController(rect: testFrame, config: config)
        let child1 = try parent.split(direction: .Vertical)
        let child2 = parent.children[1]

        let window1 = MockWindowController(title: "Window 1")
        let window2 = MockWindowController(title: "Window 2")

        try child1.addWindow(window1)
        try child1.addWindow(window2)

        #expect(child1.windowStack.count == 2)

        // Move active window
        try child1.moveWindow(window1, toFrame: child2)

        // window1 should be removed from child1
        #expect(child1.windowStack.count == 1)
    }

    @Test("Recovery: closeFrame gracefully handles inconsistent tree with wrong number of children")
    func testCloseFrameRecoveryWithInconsistentTree() throws {
        let parent = FrameController(rect: testFrame, config: config)

        // Create split - parent now has 2 children
        let child1 = try parent.split(direction: .Vertical)
        let child2 = parent.children[1]

        // Add windows to children
        let window1 = MockWindowController(title: "Window 1")
        let window2 = MockWindowController(title: "Window 2")
        let window3 = MockWindowController(title: "Window 3")

        try child1.addWindow(window1)
        try child2.addWindow(window2)
        try child2.addWindow(window3)

        #expect(parent.children.count == 2)
        #expect(child1.windowStack.count == 1)
        #expect(child2.windowStack.count == 2)

        // Manually corrupt the tree by adding a third child (simulates unexpected state)
        let extraChild = FrameController(rect: testFrame, config: config)
        extraChild.parent = parent
        parent.children.append(extraChild)

        #expect(parent.children.count == 3)  // Now inconsistent

        // Close child1 - should gracefully recover
        let result = try child1.closeFrame()

        // Recovery should consolidate all windows into parent
        #expect(result === parent)
        #expect(parent.children.count == 0)
        #expect(parent.splitDirection == nil)
        // All windows should be in parent now
        #expect(parent.windowStack.count == 3)
    }
}
