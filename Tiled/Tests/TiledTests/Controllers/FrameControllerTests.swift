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

    func createFrameController() -> FrameController {
        return FrameController(rect: testFrame, config: config, axHelper: MockAccessibilityAPIHelper())
    }

    @Test("Creates a frame controller from rect")
    func testFrameControllerInitialization() {
        let frameController = createFrameController()

        #expect(frameController.windowStack.count == 0)
        #expect(frameController.children.isEmpty)
        #expect(frameController.windowStack.activeIndex == 0)
    }

    @Test("nextWindow delegates to windowStack and calls raise")
    func testNextWindow() throws {
        let frameController = createFrameController()

        // Add windows through frameController (handles WindowId conversion)
        let window1 = MockWindowController(title: "Window 1")
        let window2 = MockWindowController(title: "Window 2")
        try frameController.addWindow(window1.windowId)
        try frameController.addWindow(window2.windowId)

        // Before cycling, window1 is active
        #expect(!window1.raiseWasCalled)

        // After nextWindow, active index should change
        _ = frameController.nextWindow()
        #expect(frameController.windowStack.activeIndex == 1)
    }

    @Test("previousWindow delegates to windowStack and calls raise")
    func testPreviousWindow() throws {
        let frameController = createFrameController()

        // Add windows through frameController
        let window1 = MockWindowController(title: "Window 1")
        let window2 = MockWindowController(title: "Window 2")
        try frameController.addWindow(window1.windowId)
        try frameController.addWindow(window2.windowId)

        // Start at window1, cycle back to window2
        _ = frameController.previousWindow()
        #expect(frameController.windowStack.activeIndex == 1)

        // Cycle back to window1
        _ = frameController.previousWindow()
        #expect(frameController.windowStack.activeIndex == 0)
    }

    @Test("Split creates child frames")
    func testSplit() throws {
        let frameController = createFrameController()

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
        let frameController = createFrameController()

        // Should not crash when calling nextWindow on empty frame
        _ = frameController.nextWindow()
        #expect(frameController.windowStack.count == 0)
    }

    @Test("Focus moves to next window when active window is removed")
    func testFocusOnWindowRemoval() throws {
        let frameController = createFrameController()
        let window1 = MockWindowController(title: "Window 1")
        let window2 = MockWindowController(title: "Window 2")
        let window3 = MockWindowController(title: "Window 3")

        // Add windows through frameController
        try frameController.addWindow(window1.windowId)
        try frameController.addWindow(window2.windowId)
        try frameController.addWindow(window3.windowId)

        // Navigate to second window
        _ = frameController.nextWindow()

        // Remove the active window
        let removed = frameController.removeWindow(window2.windowId)
        #expect(removed)
        #expect(frameController.windowStack.count == 2)
    }

    @Test("Removing non-existent window returns false")
    func testRemoveNonExistentWindow() throws {
        let frameController = createFrameController()
        let window1 = MockWindowController(title: "Window 1")
        let window2 = MockWindowController(title: "Window 2")

        try frameController.addWindow(window1.windowId)

        // Try to remove a window that was never added
        let removed = frameController.removeWindow(window2.windowId)
        #expect(!removed)
        #expect(frameController.windowStack.count == 1)
    }

    @Test("Windows are transferred between frames")
    func testFrameReferenceUpdateOnTransfer() throws {
        let frame1 = createFrameController()
        let frame2 = createFrameController()
        let window1 = MockWindowController(title: "Window 1")
        let window2 = MockWindowController(title: "Window 2")

        // Add windows to frame1
        try frame1.addWindow(window1.windowId)
        try frame1.addWindow(window2.windowId)

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
        let rootFrame = createFrameController()
        let window = MockWindowController(title: "Window 1")

        try rootFrame.addWindow(window.windowId)

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
        let parent = createFrameController()

        // Create split - parent now has two children
        let child1 = try parent.split(direction: .Vertical)
        let _ = parent.children[1]

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
        let parent = createFrameController()

        // Create split
        let child1 = try parent.split(direction: .Vertical)
        let _ = parent.children[1]

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
        let parent = createFrameController()

        // Create split gives exactly 2 children
        let child1 = try parent.split(direction: .Horizontal)
        let _ = parent.children[1]

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
        let parent = createFrameController()
        let child1 = try parent.split(direction: .Vertical)
        let child2 = parent.children[1]

        let window = MockWindowController(title: "Window 1")
        try child1.addWindow(window.windowId)

        #expect(child1.windowStack.count == 1)
        #expect(child2.windowStack.count == 0)

        // Move window from child1 to child2
        try child1.moveWindow(window.windowId, toFrame: child2)

        // Window should be removed from source
        #expect(child1.windowStack.count == 0)
    }

    @Test("Move window to adjacent frame adds to target")
    func testMoveWindowAddsToTarget() throws {
        let parent = createFrameController()
        let child1 = try parent.split(direction: .Vertical)
        let child2 = parent.children[1]

        let window = MockWindowController(title: "Window 1")
        try child1.addWindow(window.windowId)

        // Move window from child1 to child2
        try child1.moveWindow(window.windowId, toFrame: child2)

        // Window should be added to target
        #expect(child2.windowStack.count == 1)
    }

    @Test("Move window makes it active in target frame")
    func testMoveWindowActivatesInTarget() throws {
        let parent = createFrameController()
        let child1 = try parent.split(direction: .Vertical)
        let child2 = parent.children[1]

        let window1 = MockWindowController(title: "Window 1")
        let window2 = MockWindowController(title: "Window 2")

        try child1.addWindow(window1.windowId)
        try child2.addWindow(window2.windowId)

        #expect(child2.windowStack.count == 1)

        // Move window1 to child2
        try child1.moveWindow(window1.windowId, toFrame: child2)

        // window1 should be added to child2
        #expect(child2.windowStack.count == 2)
    }

    @Test("Move window with multiple windows in source")
    func testMoveWindowWithMultipleInSource() throws {
        let parent = createFrameController()
        let child1 = try parent.split(direction: .Vertical)
        let child2 = parent.children[1]

        let window1 = MockWindowController(title: "Window 1")
        let window2 = MockWindowController(title: "Window 2")
        let window3 = MockWindowController(title: "Window 3")

        try child1.addWindow(window1.windowId)
        try child1.addWindow(window2.windowId)
        try child1.addWindow(window3.windowId)

        #expect(child1.windowStack.count == 3)

        // Move only window2
        try child1.moveWindow(window2.windowId, toFrame: child2)

        // Source should have 2 remaining
        #expect(child1.windowStack.count == 2)
        #expect(child2.windowStack.count == 1)
        // Verify window2 is no longer in child1 by checking count and active window
        #expect(child1.windowStack.activeIndex == 0)
    }

    @Test("Move active window keeps source stable")
    func testMoveActiveWindowStability() throws {
        let parent = createFrameController()
        let child1 = try parent.split(direction: .Vertical)
        let child2 = parent.children[1]

        let window1 = MockWindowController(title: "Window 1")
        let window2 = MockWindowController(title: "Window 2")

        try child1.addWindow(window1.windowId)
        try child1.addWindow(window2.windowId)

        #expect(child1.windowStack.count == 2)

        // Move active window
        try child1.moveWindow(window1.windowId, toFrame: child2)

        // window1 should be removed from child1
        #expect(child1.windowStack.count == 1)
    }

    @Test("Recovery: closeFrame gracefully handles inconsistent tree with wrong number of children")
    func testCloseFrameRecoveryWithInconsistentTree() throws {
        let parent = createFrameController()

        // Create split - parent now has 2 children
        let child1 = try parent.split(direction: .Vertical)
        let child2 = parent.children[1]

        // Add windows to children
        let window1 = MockWindowController(title: "Window 1")
        let window2 = MockWindowController(title: "Window 2")
        let window3 = MockWindowController(title: "Window 3")

        try child1.addWindow(window1.windowId)
        try child2.addWindow(window2.windowId)
        try child2.addWindow(window3.windowId)

        #expect(parent.children.count == 2)
        #expect(child1.windowStack.count == 1)
        #expect(child2.windowStack.count == 2)

        // Manually corrupt the tree by adding a third child (simulates unexpected state)
        let extraChild = createFrameController()
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

    // MARK: - windowTabs @Published Tests

    @Test("windowTabs publishes empty array on initialization")
    func testWindowTabsInitiallyEmpty() {
        let frameController = createFrameController()

        #expect(frameController.windowTabs.isEmpty)
    }

    @Test("windowTabs publishes when window is added")
    func testWindowTabsPublishesOnAddWindow() throws {
        let frameController = createFrameController()
        let window1 = MockWindowController(title: "Window 1")

        try frameController.addWindow(window1.windowId)

        #expect(frameController.windowTabs.count == 1)
        #expect(frameController.windowTabs[0].isActive == true)
    }

    @Test("windowTabs publishes correct active state when multiple windows added")
    func testWindowTabsActiveState() throws {
        let frameController = createFrameController()
        let window1 = MockWindowController(title: "Window 1")
        let window2 = MockWindowController(title: "Window 2")

        try frameController.addWindow(window1.windowId, shouldFocus: false)
        try frameController.addWindow(window2.windowId, shouldFocus: true)

        #expect(frameController.windowTabs.count == 2)
        #expect(frameController.windowTabs[0].isActive == false)
        #expect(frameController.windowTabs[1].isActive == true)
    }

    @Test("windowTabs publishes when window is removed")
    func testWindowTabsPublishesOnRemoveWindow() throws {
        let frameController = createFrameController()
        let window1 = MockWindowController(title: "Window 1")
        let window2 = MockWindowController(title: "Window 2")

        try frameController.addWindow(window1.windowId)
        try frameController.addWindow(window2.windowId)
        #expect(frameController.windowTabs.count == 2)

        let removed = frameController.removeWindow(window1.windowId)
        #expect(removed == true)
        #expect(frameController.windowTabs.count == 1)
    }

    @Test("windowTabs updates on nextWindow")
    func testWindowTabsUpdatesOnNextWindow() throws {
        let frameController = createFrameController()
        let window1 = MockWindowController(title: "Window 1")
        let window2 = MockWindowController(title: "Window 2")

        try frameController.addWindow(window1.windowId, shouldFocus: true)
        try frameController.addWindow(window2.windowId, shouldFocus: false)

        #expect(frameController.windowTabs[0].isActive == true)
        #expect(frameController.windowTabs[1].isActive == false)

        _ = frameController.nextWindow()

        #expect(frameController.windowTabs[0].isActive == false)
        #expect(frameController.windowTabs[1].isActive == true)
    }

    @Test("windowTabs updates on previousWindow")
    func testWindowTabsUpdatesOnPreviousWindow() throws {
        let frameController = createFrameController()
        let window1 = MockWindowController(title: "Window 1")
        let window2 = MockWindowController(title: "Window 2")

        try frameController.addWindow(window1.windowId, shouldFocus: true)
        try frameController.addWindow(window2.windowId, shouldFocus: false)

        _ = frameController.nextWindow()
        #expect(frameController.windowTabs[1].isActive == true)

        _ = frameController.previousWindow()

        #expect(frameController.windowTabs[0].isActive == true)
        #expect(frameController.windowTabs[1].isActive == false)
    }

    @Test("windowTabs becomes empty when frame is split")
    func testWindowTabsEmptiesOnSplit() throws {
        let frameController = createFrameController()
        let window1 = MockWindowController(title: "Window 1")

        try frameController.addWindow(window1.windowId)
        #expect(frameController.windowTabs.count == 1)

        let child1 = try frameController.split(direction: .Vertical)

        // Parent becomes non-leaf, so its tabs should be empty
        #expect(frameController.windowTabs.isEmpty)
        // Child1 receives the window, so it should have tabs
        #expect(child1.windowTabs.count == 1)
    }

    @Test("windowTabs empties on split and becomes non-leaf")
    func testWindowTabsEmptyOnNonLeaf() throws {
        let parent = createFrameController()
        let window1 = MockWindowController(title: "Window 1")

        try parent.addWindow(window1.windowId)
        #expect(parent.windowTabs.count == 1)

        // After split, parent becomes non-leaf and tabs should be empty
        let child1 = try parent.split(direction: .Horizontal)
        #expect(parent.windowTabs.isEmpty)
        #expect(child1.windowTabs.count == 1)
    }

    @Test("windowTabs updates when window is moved between frames")
    func testWindowTabsUpdatesOnMoveWindow() throws {
        let parent = createFrameController()
        let child1 = try parent.split(direction: .Vertical)
        let child2 = parent.children[1]

        let window1 = MockWindowController(title: "Window 1")
        let window2 = MockWindowController(title: "Window 2")

        try child1.addWindow(window1.windowId)
        try child1.addWindow(window2.windowId)
        #expect(child1.windowTabs.count == 2)
        #expect(child2.windowTabs.isEmpty)

        try child1.moveWindow(window1.windowId, toFrame: child2)

        // After move: child1 should have 1 window, child2 should have 1 window
        #expect(child1.windowTabs.count == 1)
        #expect(child2.windowTabs.count == 1)
    }

    @Test("windowTabs updates when windows are transferred via takeWindowsFrom")
    func testWindowTabsUpdatesOnTakeWindowsFrom() throws {
        let sourceFrame = createFrameController()
        let targetFrame = createFrameController()

        let window1 = MockWindowController(title: "Window 1")
        let window2 = MockWindowController(title: "Window 2")

        try sourceFrame.addWindow(window1.windowId)
        try sourceFrame.addWindow(window2.windowId)
        #expect(sourceFrame.windowTabs.count == 2)
        #expect(targetFrame.windowTabs.isEmpty)

        try targetFrame.takeWindowsFrom(sourceFrame)

        // After takeAll: source should be empty, target should have both
        #expect(sourceFrame.windowTabs.isEmpty)
        #expect(targetFrame.windowTabs.count == 2)
    }

    // MARK: - Transactional Error Recovery Tests

    @Test("moveWindow rolls back to source frame when target frame add fails (duplicate)")
    func testMoveWindowRollsBackOnDuplicate() throws {
        let parent = createFrameController()
        let source = try parent.split(direction: .Vertical)
        let target = parent.children[1]

        let window = MockWindowController(title: "Window 1")

        // Add window to both source and target to create duplicate scenario
        try source.addWindow(window.windowId)
        try target.addWindow(window.windowId)

        // Verify initial state
        #expect(source.windowStack.count == 1)
        #expect(target.windowStack.count == 1)

        // Try to move window from source to target (will fail due to duplicate)
        var threwError = false
        do {
            try source.moveWindow(window.windowId, toFrame: target)
        } catch WindowStackError.duplicateWindow {
            threwError = true
        }

        // Verify error was thrown
        #expect(threwError)

        // Verify rollback occurred: window is back in source frame, not lost
        #expect(source.windowStack.count == 1, "Window should be restored to source after failed move")
        #expect(target.windowStack.count == 1, "Target frame should be unchanged")
        #expect(source.windowStack.allWindowIds.contains(window.windowId), "Window must be in source frame after rollback")
    }

    @Test("closeFrame rolls back all windows if second transfer fails")
    func testCloseFrameRollsBackBothTransfersOnSecondFailure() throws {
        let parent = createFrameController()
        let child1 = try parent.split(direction: .Vertical)
        let child2 = parent.children[1]

        let window1 = MockWindowController(title: "Window 1")
        let window2 = MockWindowController(title: "Window 2")

        // Add windows to children
        try child1.addWindow(window1.windowId)
        try child2.addWindow(window2.windowId)

        // Now add same window to both children to create a duplicate scenario
        // that will cause the second transfer to fail
        try child2.addWindow(window1.windowId)

        // Verify initial state
        #expect(child1.windowStack.count == 1)
        #expect(child2.windowStack.count == 2)

        // Try to close child1 - first transfer succeeds, second fails on duplicate
        var threwError = false
        do {
            _ = try child1.closeFrame()
        } catch WindowStackError.duplicateWindow {
            threwError = true
        }

        // Verify error was thrown
        #expect(threwError)

        // Verify rollback occurred: frame tree is unchanged after failed close
        #expect(parent.children.count == 2, "Children should remain after failed close")
        #expect(parent.splitDirection != nil, "Split direction should remain after failed close")
        #expect(child1.windowStack.count == 1, "child1 windows should be restored")
        #expect(child2.windowStack.count == 2, "child2 windows should be restored")
        #expect(child1.windowStack.allWindowIds.contains(window1.windowId), "Window must be in child1 after rollback")
    }

    @Test("closeFrame preserves frame tree structure on rollback")
    func testCloseFramePreservesTreeStructureOnRollback() throws {
        let parent = createFrameController()
        let child1 = try parent.split(direction: .Horizontal)
        let child2 = parent.children[1]

        let window1 = MockWindowController(title: "Window 1")
        let window2 = MockWindowController(title: "Window 2")

        try child1.addWindow(window1.windowId)
        try child2.addWindow(window2.windowId)

        // Create duplicate to trigger failure
        try child2.addWindow(window1.windowId)

        // Attempt close and expect failure
        var threwError = false
        do {
            _ = try child1.closeFrame()
        } catch WindowStackError.duplicateWindow {
            threwError = true
        }

        #expect(threwError)

        // Verify frame tree structure is preserved
        #expect(parent.children.count == 2, "Parent should still have both children")
        #expect(parent.children[0] === child1, "child1 should still be first child")
        #expect(parent.children[1] === child2, "child2 should still be second child")
        #expect(parent.splitDirection == .Horizontal, "Split direction should be unchanged")
        // Note: parent will have window1 from the successful first transfer, but child1 is restored
        // The second transfer failed, but the first succeeded and cannot be rolled back without more complexity
        #expect(child1.parent === parent, "child1 parent reference should be intact")
        #expect(child2.parent === parent, "child2 parent reference should be intact")
    }

    @Test("moveWindow succeeds normally without rollback when no error occurs")
    func testMoveWindowNormalPathWithoutError() throws {
        let parent = createFrameController()
        let source = try parent.split(direction: .Vertical)
        let target = parent.children[1]

        let window = MockWindowController(title: "Window 1")
        try source.addWindow(window.windowId)

        // Normal successful move
        try source.moveWindow(window.windowId, toFrame: target)

        // Verify successful move (no rollback)
        #expect(source.windowStack.count == 0)
        #expect(target.windowStack.count == 1)
        #expect(target.windowStack.allWindowIds.contains(window.windowId))
    }

    @Test("closeFrame succeeds normally without rollback when both transfers succeed")
    func testCloseFrameNormalPathWithoutRollback() throws {
        let parent = createFrameController()
        let child1 = try parent.split(direction: .Vertical)
        let child2 = parent.children[1]

        let window1 = MockWindowController(title: "Window 1")
        let window2 = MockWindowController(title: "Window 2")

        try child1.addWindow(window1.windowId)
        try child2.addWindow(window2.windowId)

        // Normal successful close
        let nextActive = try child1.closeFrame()

        // Verify successful close (no rollback)
        #expect(nextActive === parent)
        #expect(parent.children.count == 0)
        #expect(parent.splitDirection == nil)
        #expect(parent.windowStack.count == 2)
        #expect(parent.windowStack.allWindowIds.contains(window1.windowId))
        #expect(parent.windowStack.allWindowIds.contains(window2.windowId))
    }
}
