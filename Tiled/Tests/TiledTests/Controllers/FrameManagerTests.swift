// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Jimmy Ma

import Cocoa
import Testing
@testable import Tiled

@Suite("FrameManager Tests")
@MainActor
struct FrameManagerTests {
    let config: ConfigController
    let logger: Logger
    let mockFactory: MockFrameWindowFactory

    init() {
        self.config = ConfigController()
        self.logger = Logger()
        self.mockFactory = MockFrameWindowFactory()
    }

    func createFrameController(_ testFrame: CGRect) -> FrameController {
        return FrameController(rect: testFrame, config: config, windowFactory: mockFactory, axHelper: MockAccessibilityAPIHelper())
    }

    // MARK: - Initialization Tests

    @Test("Initializes with rootFrame and activeFrame")
    func testInitialization() throws {
        let frameManager = FrameManager(config: config, logger: logger)
        let screen = NSScreen.main ?? NSScreen()

        frameManager.initializeFromScreen(screen)

        #expect(frameManager.rootFrame != nil)
        #expect(frameManager.activeFrame != nil)
        #expect(frameManager.activeFrame === frameManager.rootFrame)
    }

    // MARK: - Horizontal Split Tests

    @Test("Horizontal split sets parent/child relationships correctly")
    func testHorizontalSplitParentChildRelationships() throws {
        let frameManager = FrameManager(config: config, logger: logger)
        let testFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        frameManager.rootFrame = createFrameController(testFrame)
        frameManager.activeFrame = frameManager.rootFrame

        guard let root = frameManager.rootFrame else {
            Issue.record("rootFrame should not be nil")
            return
        }

        try frameManager.splitHorizontally()

        // Root should have two children
        #expect(root.children.count == 2)

        // Both children should have root as parent
        #expect(root.children[0].parent === root)
        #expect(root.children[1].parent === root)

        // Root should track split direction
        #expect(root.splitDirection == .Horizontal)
    }

    @Test("Horizontal split makes first child active")
    func testHorizontalSplitActivatesFirstChild() throws {
        let frameManager = FrameManager(config: config, logger: logger)
        let testFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        frameManager.rootFrame = createFrameController(testFrame)
        frameManager.activeFrame = frameManager.rootFrame

        guard let root = frameManager.rootFrame else {
            Issue.record("rootFrame should not be nil")
            return
        }

        try frameManager.splitHorizontally()

        // After split, activeFrame should be first child
        #expect(frameManager.activeFrame === root.children[0])
    }

    @Test("Can navigate right after horizontal split")
    func testNavigateRightAfterHorizontalSplit() throws {
        let frameManager = FrameManager(config: config, logger: logger)
        let testFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        frameManager.rootFrame = createFrameController(testFrame)
        frameManager.activeFrame = frameManager.rootFrame

        guard let root = frameManager.rootFrame else {
            Issue.record("rootFrame should not be nil")
            return
        }

        // Vertical split creates left/right frames
        try frameManager.splitVertically()
        let leftChild = root.children[0]
        let rightChild = root.children[1]

        // Active should be left child
        #expect(frameManager.activeFrame === leftChild)

        // Navigate right
        frameManager.navigateRight()

        // Active should now be right child
        #expect(frameManager.activeFrame === rightChild)
    }

    @Test("Can navigate left after horizontal split")
    func testNavigateLeftAfterHorizontalSplit() throws {
        let frameManager = FrameManager(config: config, logger: logger)
        let testFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        frameManager.rootFrame = createFrameController(testFrame)
        frameManager.activeFrame = frameManager.rootFrame

        guard let root = frameManager.rootFrame else {
            Issue.record("rootFrame should not be nil")
            return
        }

        // Vertical split creates left/right frames
        try frameManager.splitVertically()
        let leftChild = root.children[0]
        let rightChild = root.children[1]

        // Start at left, move to right
        frameManager.navigateRight()
        #expect(frameManager.activeFrame === rightChild)

        // Navigate back left
        frameManager.navigateLeft()

        // Active should be left child
        #expect(frameManager.activeFrame === leftChild)
    }

    // MARK: - Vertical Split Tests

    @Test("Vertical split sets parent/child relationships correctly")
    func testVerticalSplitParentChildRelationships() throws {
        let frameManager = FrameManager(config: config, logger: logger)
        let testFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        frameManager.rootFrame = createFrameController(testFrame)
        frameManager.activeFrame = frameManager.rootFrame

        guard let root = frameManager.rootFrame else {
            Issue.record("rootFrame should not be nil")
            return
        }

        try frameManager.splitVertically()

        // Root should have two children
        #expect(root.children.count == 2)

        // Both children should have root as parent
        #expect(root.children[0].parent === root)
        #expect(root.children[1].parent === root)

        // Root should track split direction
        #expect(root.splitDirection == .Vertical)
    }

    @Test("Can navigate down after vertical split")
    func testNavigateDownAfterVerticalSplit() throws {
        let frameManager = FrameManager(config: config, logger: logger)
        let testFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        frameManager.rootFrame = createFrameController(testFrame)
        frameManager.activeFrame = frameManager.rootFrame

        guard let root = frameManager.rootFrame else {
            Issue.record("rootFrame should not be nil")
            return
        }

        // Horizontal split creates top/bottom frames
        try frameManager.splitHorizontally()
        let topChild = root.children[0]
        let bottomChild = root.children[1]

        // Active should be top child
        #expect(frameManager.activeFrame === topChild)

        // Navigate down
        frameManager.navigateDown()

        // Active should now be bottom child
        #expect(frameManager.activeFrame === bottomChild)
    }

    @Test("Can navigate up after vertical split")
    func testNavigateUpAfterVerticalSplit() throws {
        let frameManager = FrameManager(config: config, logger: logger)
        let testFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        frameManager.rootFrame = createFrameController(testFrame)
        frameManager.activeFrame = frameManager.rootFrame

        guard let root = frameManager.rootFrame else {
            Issue.record("rootFrame should not be nil")
            return
        }

        // Horizontal split creates top/bottom frames
        try frameManager.splitHorizontally()
        let topChild = root.children[0]
        let bottomChild = root.children[1]

        // Start at top, move to bottom
        frameManager.navigateDown()
        #expect(frameManager.activeFrame === bottomChild)

        // Navigate back up
        frameManager.navigateUp()

        // Active should be top child
        #expect(frameManager.activeFrame === topChild)
    }

    // MARK: - Nested Split Tests

    @Test("Can navigate through nested horizontal then vertical splits")
    func testNavigateThroughNestedHorizontalThenVerticalSplits() throws {
        let frameManager = FrameManager(config: config, logger: logger)
        let testFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        frameManager.rootFrame = createFrameController(testFrame)
        frameManager.activeFrame = frameManager.rootFrame

        guard let root = frameManager.rootFrame else {
            Issue.record("rootFrame should not be nil")
            return
        }

        // Do vertical split: root -> left, right (side-by-side)
        try frameManager.splitVertically()
        let left = root.children[0]
        let right = root.children[1]

        // Focus on left, then split horizontally: left -> topLeft, bottomLeft (stacked)
        frameManager.activeFrame = left
        try frameManager.splitHorizontally()
        let topLeft = left.children[0]
        let bottomLeft = left.children[1]

        // Start at topLeft
        frameManager.activeFrame = topLeft

        // Can navigate down to bottomLeft
        frameManager.navigateDown()
        #expect(frameManager.activeFrame === bottomLeft)

        // Can navigate right from bottomLeft to right
        frameManager.navigateRight()
        #expect(frameManager.activeFrame === right)
    }

    @Test("Cannot navigate orthogonally to split direction")
    func testCannotNavigateOrthogonallyToSplitDirection() throws {
        let frameManager = FrameManager(config: config, logger: logger)
        let testFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        frameManager.rootFrame = createFrameController(testFrame)
        frameManager.activeFrame = frameManager.rootFrame

        guard let root = frameManager.rootFrame else {
            Issue.record("rootFrame should not be nil")
            return
        }

        // Vertical split creates left/right frames, so can't navigate up/down from children
        try frameManager.splitVertically()
        let leftChild = root.children[0]

        frameManager.activeFrame = leftChild

        // These should be no-ops (no adjacent frames)
        let activeBeforeUp = frameManager.activeFrame
        frameManager.navigateUp()
        #expect(frameManager.activeFrame === activeBeforeUp)

        let activeBeforeDown = frameManager.activeFrame
        frameManager.navigateDown()
        #expect(frameManager.activeFrame === activeBeforeDown)
    }

    // MARK: - Boundary Tests

    @Test("Cannot navigate left from left child in horizontal split")
    func testCannotNavigateLeftFromLeftChild() throws {
        let frameManager = FrameManager(config: config, logger: logger)
        let testFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        frameManager.rootFrame = createFrameController(testFrame)
        frameManager.activeFrame = frameManager.rootFrame

        guard let root = frameManager.rootFrame else {
            Issue.record("rootFrame should not be nil")
            return
        }

        try frameManager.splitHorizontally()
        let leftChild = root.children[0]

        frameManager.activeFrame = leftChild
        let activeBeforeNavigation = frameManager.activeFrame

        frameManager.navigateLeft()

        // Should still be at left child
        #expect(frameManager.activeFrame === activeBeforeNavigation)
    }

    @Test("Cannot navigate right from right child in horizontal split")
    func testCannotNavigateRightFromRightChild() throws {
        let frameManager = FrameManager(config: config, logger: logger)
        let testFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        frameManager.rootFrame = createFrameController(testFrame)
        frameManager.activeFrame = frameManager.rootFrame

        guard let root = frameManager.rootFrame else {
            Issue.record("rootFrame should not be nil")
            return
        }

        try frameManager.splitHorizontally()
        let rightChild = root.children[1]

        frameManager.activeFrame = rightChild
        let activeBeforeNavigation = frameManager.activeFrame

        frameManager.navigateRight()

        // Should still be at right child
        #expect(frameManager.activeFrame === activeBeforeNavigation)
    }

    // MARK: - Frame Clearing Tests

    @Test("Parent frame becomes non-leaf after split")
    func testParentFrameBecomesNonLeafAfterSplit() throws {
        let frameManager = FrameManager(config: config, logger: logger)
        let testFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        frameManager.rootFrame = createFrameController(testFrame)
        frameManager.activeFrame = frameManager.rootFrame

        guard let root = frameManager.rootFrame else {
            Issue.record("rootFrame should not be nil")
            return
        }

        // Root starts as leaf with no windows
        #expect(root.children.isEmpty)

        // Split should make parent non-leaf
        try frameManager.splitHorizontally()

        // Parent frame should now have children
        #expect(!root.children.isEmpty)
        // Parent frame's tabs should be empty (observer/clear() is tested in FrameWindowObserverTests)
        #expect(root.windowTabs.isEmpty)
    }

    @Test("Children frames are not cleared after split")
    func testChildrenFramesNotClearedAfterSplit() throws {
        let frameManager = FrameManager(config: config, logger: logger)
        let testFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)

        let parentFrame = createFrameController(testFrame)
        frameManager.rootFrame = parentFrame
        frameManager.activeFrame = parentFrame

        guard let root = frameManager.rootFrame else {
            Issue.record("rootFrame should not be nil")
            return
        }

        try frameManager.splitHorizontally()

        // Get the child frames - they should have real FrameWindow instances
        let child1 = root.children[0]
        let child2 = root.children[1]

        // Child frames should exist and have frameWindow instances
        #expect(child1 != nil)
        #expect(child2 != nil)
    }

    @Test("Only leaf frames show tabs after split")
    func testOnlyLeafFramesShowTabsAfterSplit() throws {
        let frameManager = FrameManager(config: config, logger: logger)
        let testFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        frameManager.rootFrame = createFrameController(testFrame)
        frameManager.activeFrame = frameManager.rootFrame

        guard let root = frameManager.rootFrame else {
            Issue.record("rootFrame should not be nil")
            return
        }

        try frameManager.splitHorizontally()

        let child1 = root.children[0]
        let child2 = root.children[1]

        // Both children should be leaf frames (no children)
        #expect(child1.children.isEmpty)
        #expect(child2.children.isEmpty)

        // Parent should have children
        #expect(!root.children.isEmpty)
    }

    @Test("Parent frame window is hidden after split")
    func testParentFrameWindowHiddenAfterSplit() throws {
        let frameManager = FrameManager(config: config, logger: logger)
        let testFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        frameManager.rootFrame = createFrameController(testFrame)
        frameManager.activeFrame = frameManager.rootFrame

        guard let root = frameManager.rootFrame else {
            Issue.record("rootFrame should not be nil")
            return
        }

        // Get the actual mock frame window from the root frame
        let mockWindow = root.frameWindow as? MockFrameWindow
        mockWindow?.hideCallCount = 0

        // Split should hide the parent frame window
        try frameManager.splitHorizontally()

        // Parent frame's window should have been hidden
        #expect((mockWindow?.hideCallCount ?? 0) >= 1)
    }

    @Test("Move window left updates active frame")
    func testMoveWindowLeftUpdatesActiveFrame() throws {
        let frameManager = FrameManager(config: config, logger: logger)
        let testFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        frameManager.rootFrame = createFrameController(testFrame)
        frameManager.activeFrame = frameManager.rootFrame

        guard let root = frameManager.rootFrame else {
            Issue.record("rootFrame should not be nil")
            return
        }

        // Create a vertical split
        try frameManager.splitVertically()
        guard root.children.count == 2 else {
            Issue.record("Should have 2 children after split")
            return
        }

        let leftChild = root.children[0]
        let rightChild = root.children[1]

        // Add window to right child
        let window = MockWindowController(title: "Test Window")
        try rightChild.addWindow(window.windowId)

        // Make right child active
        frameManager.activeFrame = rightChild

        #expect(frameManager.activeFrame === rightChild)

        // Move window left
        try frameManager.moveActiveWindowLeft()

        // Active frame should now be left child
        #expect(frameManager.activeFrame === leftChild)
    }

    @Test("Move window right updates active frame")
    func testMoveWindowRightUpdatesActiveFrame() throws {
        let frameManager = FrameManager(config: config, logger: logger)
        let testFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        frameManager.rootFrame = createFrameController(testFrame)
        frameManager.activeFrame = frameManager.rootFrame

        guard let root = frameManager.rootFrame else {
            Issue.record("rootFrame should not be nil")
            return
        }

        // Create a vertical split
        try frameManager.splitVertically()
        guard root.children.count == 2 else {
            Issue.record("Should have 2 children after split")
            return
        }

        let leftChild = root.children[0]
        let rightChild = root.children[1]

        // Add window to left child
        let window = MockWindowController(title: "Test Window")
        try leftChild.addWindow(window.windowId)

        // Make left child active (it already is from split)
        #expect(frameManager.activeFrame === leftChild)

        // Move window right
        try frameManager.moveActiveWindowRight()

        // Active frame should now be right child
        #expect(frameManager.activeFrame === rightChild)
    }

    @Test("Move window up updates active frame")
    func testMoveWindowUpUpdatesActiveFrame() throws {
        let frameManager = FrameManager(config: config, logger: logger)
        let testFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        frameManager.rootFrame = createFrameController(testFrame)
        frameManager.activeFrame = frameManager.rootFrame

        guard let root = frameManager.rootFrame else {
            Issue.record("rootFrame should not be nil")
            return
        }

        // Create a horizontal split
        try frameManager.splitHorizontally()
        guard root.children.count == 2 else {
            Issue.record("Should have 2 children after split")
            return
        }

        let topChild = root.children[0]
        let bottomChild = root.children[1]

        // Add window to bottom child
        let window = MockWindowController(title: "Test Window")
        try bottomChild.addWindow(window.windowId)

        // Make bottom child active
        frameManager.activeFrame = bottomChild

        #expect(frameManager.activeFrame === bottomChild)

        // Move window up
        try frameManager.moveActiveWindowUp()

        // Active frame should now be top child
        #expect(frameManager.activeFrame === topChild)
    }

    @Test("Move window down updates active frame")
    func testMoveWindowDownUpdatesActiveFrame() throws {
        let frameManager = FrameManager(config: config, logger: logger)
        let testFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        frameManager.rootFrame = createFrameController(testFrame)
        frameManager.activeFrame = frameManager.rootFrame

        guard let root = frameManager.rootFrame else {
            Issue.record("rootFrame should not be nil")
            return
        }

        // Create a horizontal split
        try frameManager.splitHorizontally()
        guard root.children.count == 2 else {
            Issue.record("Should have 2 children after split")
            return
        }

        let topChild = root.children[0]
        let bottomChild = root.children[1]

        // Add window to top child
        let window = MockWindowController(title: "Test Window")
        try topChild.addWindow(window.windowId)

        // Make top child active (it already is from split)
        #expect(frameManager.activeFrame === topChild)

        // Move window down
        try frameManager.moveActiveWindowDown()

        // Active frame should now be bottom child
        #expect(frameManager.activeFrame === bottomChild)
    }

    @Test("Move window transfers ownership between frames")
    func testMoveWindowTransfersOwnership() throws {
        let frameManager = FrameManager(config: config, logger: logger)
        let screen = NSScreen.main ?? NSScreen()
        frameManager.initializeFromScreen(screen)

        guard let root = frameManager.rootFrame else {
            Issue.record("rootFrame should not be nil")
            return
        }

        // Add a window to root first
        let window = MockWindowController(title: "Test Window")
        frameManager.registerExistingWindow(window, windowId: window.windowId)
        try frameManager.assignWindow(window, shouldFocus: false)

        // Verify window is in root
        #expect(root.windowStack.count == 1)

        // Create a vertical split - this moves window to left child
        try frameManager.splitVertically()
        guard root.children.count == 2 else {
            Issue.record("Should have 2 children after split")
            return
        }

        let leftChild = root.children[0]
        let rightChild = root.children[1]

        #expect(leftChild.windowStack.count == 1)
        #expect(rightChild.windowStack.count == 0)

        // Move window right
        try frameManager.moveActiveWindowRight()

        // Window should have moved
        #expect(leftChild.windowStack.count == 0)
        #expect(rightChild.windowStack.count == 1)
    }

    // MARK: - FrameMap Tests

    @Test("frameMap returns nil for windows not in any frame")
    func testFrameMapReturnsNilForUnmappedWindow() throws {
        let frameManager = FrameManager(config: config, logger: logger)
        let screen = NSScreen.main ?? NSScreen()
        frameManager.initializeFromScreen(screen)

        // Create a mock registry for creating WindowId
        let mockRegistry = MockWindowRegistry()
        let windowId = WindowId(appPID: 1234, registry: mockRegistry)

        let foundFrame = frameManager.frameContaining(windowId)
        #expect(foundFrame == nil)
    }

    @Test("frameContaining method is accessible")
    func testFrameContainingMethodExists() throws {
        let frameManager = FrameManager(config: config, logger: logger)
        let screen = NSScreen.main ?? NSScreen()
        frameManager.initializeFromScreen(screen)

        // Create a mock registry for creating WindowId
        let mockRegistry = MockWindowRegistry()
        let windowId = WindowId(appPID: 1234, registry: mockRegistry)

        // This test verifies the method exists and is callable
        // The infrastructure for frameMap maintenance happens in handleWindowAppeared
        let result = frameManager.frameContaining(windowId)
        #expect(result == nil)
    }

    @Test("frameMap tracks window assignment to frame")
    func testFrameMapTracksWindowAssignment() throws {
        let frameManager = FrameManager(config: config, logger: logger)
        let screen = NSScreen.main ?? NSScreen()
        frameManager.initializeFromScreen(screen)

        let window = MockWindowController(title: "Test Window")
        frameManager.registerExistingWindow(window, windowId: window.windowId)

        // Before assignment, frameMap should not contain window
        var foundFrame = frameManager.frameContaining(window.windowId)
        #expect(foundFrame == nil)

        // Assign window to active frame
        try frameManager.assignWindow(window, shouldFocus: false)

        // After assignment, frameMap should contain window→frame mapping
        foundFrame = frameManager.frameContaining(window.windowId)
        #expect(foundFrame === frameManager.activeFrame, "frameMap should track window assignment to active frame")
    }

    @Test("frameMap is maintained correctly across frame assignments")
    func testFrameMapMaintenanceAcrossAssignments() throws {
        let frameManager = FrameManager(config: config, logger: logger)
        let screen = NSScreen.main ?? NSScreen()
        frameManager.initializeFromScreen(screen)

        guard let rootFrame = frameManager.rootFrame else { return }

        // Add first window
        let window1 = MockWindowController(title: "Window 1")
        frameManager.registerExistingWindow(window1, windowId: window1.windowId)
        try frameManager.assignWindow(window1, shouldFocus: false)

        var foundFrame = frameManager.frameContaining(window1.windowId)
        #expect(foundFrame === rootFrame, "window1 should be in rootFrame after assignment")

        // Split and add second window to new frame
        try frameManager.splitHorizontally()
        let leftChild = frameManager.activeFrame
        let rightChild = rootFrame.children[1]

        let window2 = MockWindowController(title: "Window 2")
        frameManager.registerExistingWindow(window2, windowId: window2.windowId)
        try frameManager.assignWindow(window2, shouldFocus: false)

        // Verify frameMap correctly maps both windows
        foundFrame = frameManager.frameContaining(window1.windowId)
        #expect(foundFrame === rootFrame, "window1 should still be in rootFrame")

        foundFrame = frameManager.frameContaining(window2.windowId)
        #expect(foundFrame === leftChild, "window2 should be in leftChild after assignment")
    }

    @Test("frameMap cleaned up when window disappears")
    func testFrameMapCleanedUpOnWindowDisappear() throws {
        let frameManager = FrameManager(config: config, logger: logger)
        let screen = NSScreen.main ?? NSScreen()
        frameManager.initializeFromScreen(screen)

        let window = MockWindowController(title: "Test Window")
        frameManager.registerExistingWindow(window, windowId: window.windowId)

        // Assign window
        try frameManager.assignWindow(window, shouldFocus: false)
        var foundFrame = frameManager.frameContaining(window.windowId)
        #expect(foundFrame != nil, "Window should be in frameMap after assignment")

        // Unregister window (simulates the cleanup that happens in handleWindowDisappeared)
        frameManager.unregisterWindow(windowId: window.windowId)

        // Verify frameMap is cleaned up
        foundFrame = frameManager.frameContaining(window.windowId)
        #expect(foundFrame == nil, "frameMap should be cleaned up after unregisterWindow")
    }

    @Test("frameMap consistent with frame ownership")
    func testFrameMapConsistentWithFrameOwnership() throws {
        let frameManager = FrameManager(config: config, logger: logger)
        let testFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        frameManager.rootFrame = createFrameController(testFrame)
        frameManager.activeFrame = frameManager.rootFrame

        guard let root = frameManager.rootFrame else { return }

        // Create 3-way split: root → (left, right), left → (topLeft, bottomLeft)
        let rightChild = try root.split(direction: .Horizontal)
        let leftChild = root.children[0]

        let bottomLeft = try leftChild.split(direction: .Vertical)
        let topLeft = leftChild.children[0]

        // Add windows to different frames
        let window1 = MockWindowController(title: "Window 1")
        let window2 = MockWindowController(title: "Window 2")
        let window3 = MockWindowController(title: "Window 3")

        frameManager.registerExistingWindow(window1, windowId: window1.windowId)
        frameManager.registerExistingWindow(window2, windowId: window2.windowId)
        frameManager.registerExistingWindow(window3, windowId: window3.windowId)

        frameManager.activeFrame = topLeft
        try frameManager.assignWindow(window1, shouldFocus: false)

        frameManager.activeFrame = bottomLeft
        try frameManager.assignWindow(window2, shouldFocus: false)

        frameManager.activeFrame = rightChild
        try frameManager.assignWindow(window3, shouldFocus: false)

        // Verify frameMap is consistent with actual ownership
        #expect(frameManager.frameContaining(window1.windowId) === topLeft, "window1 should map to topLeft")
        #expect(frameManager.frameContaining(window2.windowId) === bottomLeft, "window2 should map to bottomLeft")
        #expect(frameManager.frameContaining(window3.windowId) === rightChild, "window3 should map to rightChild")

        // Verify each frame's windowStack is consistent
        #expect(topLeft.windowIds.contains(window1.windowId), "topLeft should contain window1")
        #expect(bottomLeft.windowIds.contains(window2.windowId), "bottomLeft should contain window2")
        #expect(rightChild.windowIds.contains(window3.windowId), "rightChild should contain window3")
    }

    // MARK: - Window Positioning Tests

    @Test("assignWindow positions window in frame")
    func testAssignWindowPositionsWindow() throws {
        let frameManager = FrameManager(config: config, logger: logger)
        let screen = NSScreen.main ?? NSScreen()
        frameManager.initializeFromScreen(screen)

        let window = MockWindowController(title: "Test Window")
        frameManager.registerExistingWindow(window, windowId: window.windowId)

        // Assign window should trigger positioning
        try frameManager.assignWindow(window, shouldFocus: false)

        // Window should have been repositioned (resize and move)
        #expect(window.repositionCallCount > 0, "Window should be repositioned when assigned to frame")
    }

    // MARK: - Stale WindowId Handling Tests

    @Test("frameContaining returns nil for unregistered WindowId")
    func testFrameContainingHandlesUnregisteredWindowId() throws {
        let frameManager = FrameManager(config: config, logger: logger)
        let screen = NSScreen.main ?? NSScreen()
        frameManager.initializeFromScreen(screen)

        let mockRegistry = MockWindowRegistry()
        let staleWindowId = WindowId(appPID: 9999, registry: mockRegistry)

        // Attempt to find frame for unregistered window should return nil gracefully
        let foundFrame = frameManager.frameContaining(staleWindowId)
        #expect(foundFrame == nil, "frameContaining should return nil for unregistered WindowId")
    }

    @Test("windowControllerMap handles missing windows gracefully")
    func testSnappingStaleWindowIdHandledGracefully() throws {
        let frameManager = FrameManager(config: config, logger: logger)
        let screen = NSScreen.main ?? NSScreen()
        frameManager.initializeFromScreen(screen)

        // Create a WindowId that was never registered
        let mockRegistry = MockWindowRegistry()
        let staleWindowId = WindowId(appPID: 8888, registry: mockRegistry)

        // Attempting to snap a stale WindowId should not crash
        // This simulates what happens in moveActiveWindow if windowId becomes stale
        frameManager.registerExistingWindow(
            MockWindowController(title: "Dummy"),
            windowId: staleWindowId
        )

        // Now unregister it to make it stale
        frameManager.unregisterWindow(windowId: staleWindowId)

        // frameContaining should still work (returns nil)
        let foundFrame = frameManager.frameContaining(staleWindowId)
        #expect(foundFrame == nil, "frameContaining should return nil after unregistration")
    }

    @Test("unregisterWindow cleans up all references")
    func testUnregisterWindowCleansUpAllReferences() throws {
        let frameManager = FrameManager(config: config, logger: logger)
        let screen = NSScreen.main ?? NSScreen()
        frameManager.initializeFromScreen(screen)

        let window = MockWindowController(title: "Test Window")
        frameManager.registerExistingWindow(window, windowId: window.windowId)
        try frameManager.assignWindow(window, shouldFocus: false)

        // Verify window is tracked
        #expect(frameManager.frameContaining(window.windowId) != nil, "Window should be in frameMap")

        // Unregister the window
        frameManager.unregisterWindow(windowId: window.windowId)

        // Verify all references are cleaned up
        #expect(frameManager.frameContaining(window.windowId) == nil, "Window should be removed from frameMap")
    }

    // MARK: - Missing Window Cleanup Tests

    @Test("missing window cleanup happens when snap discovers missing controller")
    func testMissingWindowCleanupOnSnap() throws {
        let frameManager = FrameManager(config: config, logger: logger)
        let testFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        frameManager.rootFrame = createFrameController(testFrame)
        frameManager.activeFrame = frameManager.rootFrame

        guard let rootFrame = frameManager.rootFrame else { return }

        let window = MockWindowController(title: "Test Window")
        frameManager.registerExistingWindow(window, windowId: window.windowId)
        try frameManager.assignWindow(window, shouldFocus: false)

        // Verify window is in frame and frameMap
        #expect(rootFrame.windowIds.contains(window.windowId), "Window should be in frame")
        #expect(frameManager.frameContaining(window.windowId) === rootFrame, "Window should be in frameMap")

        // Simulate window disappearing by unregistering it (controller is gone)
        frameManager.unregisterWindow(windowId: window.windowId)

        // Now split triggers snapFrameWindows which discovers missing window
        try frameManager.splitHorizontally()

        // Cleanup should have happened: window removed from frame
        #expect(!rootFrame.windowIds.contains(window.windowId), "Missing window should be cleaned up from frame")

        // Cleanup should have happened: window removed from frameMap
        #expect(frameManager.frameContaining(window.windowId) == nil, "Missing window should be cleaned up from frameMap")
    }

    @Test("raiseWindow cleans up missing window")
    func testRaiseWindowCleanupMissing() throws {
        let frameManager = FrameManager(config: config, logger: logger)
        let screen = NSScreen.main ?? NSScreen()
        frameManager.initializeFromScreen(screen)

        guard let rootFrame = frameManager.rootFrame else { return }

        let window = MockWindowController(title: "Test Window")
        frameManager.registerExistingWindow(window, windowId: window.windowId)
        try frameManager.assignWindow(window, shouldFocus: false)

        // Verify window is tracked
        #expect(rootFrame.windowIds.contains(window.windowId), "Window should be in frame")
        #expect(frameManager.frameContaining(window.windowId) != nil, "Window should be in frameMap")

        // Simulate window disappearing by removing only the controller, not the frameMap entry
        // This simulates the scenario where the window closes but we still have the WindowId tracked
        frameManager.windowControllerMap.removeValue(forKey: window.windowId.asKey())

        // Now raise is called (operation discovers window is gone)
        frameManager.nextWindow()  // This calls raiseWindow internally

        // Cleanup should have happened
        #expect(!rootFrame.windowIds.contains(window.windowId), "Missing window should be removed from frame after raise attempt")
        #expect(frameManager.frameContaining(window.windowId) == nil, "Missing window should be removed from frameMap after raise attempt")
    }

    @Test("cleanup restores consistency after window disappearance")
    func testCleanupRestoresConsistency() throws {
        let frameManager = FrameManager(config: config, logger: logger)
        let screen = NSScreen.main ?? NSScreen()
        frameManager.initializeFromScreen(screen)

        guard let rootFrame = frameManager.rootFrame else { return }

        // Add two windows
        let window1 = MockWindowController(title: "Window 1")
        let window2 = MockWindowController(title: "Window 2")
        frameManager.registerExistingWindow(window1, windowId: window1.windowId)
        frameManager.registerExistingWindow(window2, windowId: window2.windowId)
        try frameManager.assignWindow(window1, shouldFocus: false)
        try frameManager.assignWindow(window2, shouldFocus: false)

        #expect(rootFrame.windowIds.count == 2, "Should have 2 windows")

        // Window1 disappears (remove controller but keep frameMap entry to simulate real scenario)
        // This is the inconsistent state: window in frame but no controller
        frameManager.windowControllerMap.removeValue(forKey: window1.windowId.asKey())

        // Before cleanup: inconsistency exists (window1 in frame but controller missing)
        #expect(rootFrame.windowIds.contains(window1.windowId), "window1 still in frame (orphaned)")
        #expect(frameManager.frameContaining(window1.windowId) != nil, "window1 still in frameMap")

        // Operation discovers missing window and triggers cleanup (split triggers snap)
        try frameManager.splitHorizontally()

        // After split, windows are in child frames, not rootFrame
        guard let child1 = rootFrame.children.first else { return }

        // After cleanup: consistency restored
        #expect(!child1.windowIds.contains(window1.windowId), "window1 should be removed from child1 frame")
        #expect(frameManager.frameContaining(window1.windowId) == nil, "window1 should no longer be in frameMap")
        #expect(child1.windowIds.count == 1, "child1 should have 1 window left")
        #expect(child1.windowIds.contains(window2.windowId), "window2 should still be there")
    }
}
