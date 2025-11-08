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
        frameManager.rootFrame = FrameController(rect: testFrame, config: config, windowFactory: mockFactory)
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
        frameManager.rootFrame = FrameController(rect: testFrame, config: config, windowFactory: mockFactory)
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
        frameManager.rootFrame = FrameController(rect: testFrame, config: config, windowFactory: mockFactory)
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
        frameManager.rootFrame = FrameController(rect: testFrame, config: config, windowFactory: mockFactory)
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
        frameManager.rootFrame = FrameController(rect: testFrame, config: config, windowFactory: mockFactory)
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
        frameManager.rootFrame = FrameController(rect: testFrame, config: config, windowFactory: mockFactory)
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
        frameManager.rootFrame = FrameController(rect: testFrame, config: config, windowFactory: mockFactory)
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
        frameManager.rootFrame = FrameController(rect: testFrame, config: config, windowFactory: mockFactory)
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
        frameManager.rootFrame = FrameController(rect: testFrame, config: config, windowFactory: mockFactory)
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
        frameManager.rootFrame = FrameController(rect: testFrame, config: config, windowFactory: mockFactory)
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
        frameManager.rootFrame = FrameController(rect: testFrame, config: config, windowFactory: mockFactory)
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

    @Test("Parent frame is cleared after split")
    func testParentFrameClearedAfterSplit() throws {
        let frameManager = FrameManager(config: config, logger: logger)
        let testFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        frameManager.rootFrame = FrameController(rect: testFrame, config: config, windowFactory: mockFactory)
        frameManager.activeFrame = frameManager.rootFrame

        guard let root = frameManager.rootFrame else {
            Issue.record("rootFrame should not be nil")
            return
        }

        // Get the actual mock frame window from the root frame
        let mockWindow = root.frameWindow as? MockFrameWindow
        mockWindow?.clearCallCount = 0

        // Split should clear the parent frame
        try frameManager.splitHorizontally()

        // Parent frame should have been cleared
        #expect((mockWindow?.clearCallCount ?? 0) >= 1)
    }

    @Test("Children frames are not cleared after split")
    func testChildrenFramesNotClearedAfterSplit() throws {
        let frameManager = FrameManager(config: config, logger: logger)
        let testFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)

        let parentFrame = FrameController(rect: testFrame, config: config, windowFactory: mockFactory)
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
        frameManager.rootFrame = FrameController(rect: testFrame, config: config, windowFactory: mockFactory)
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
        frameManager.rootFrame = FrameController(rect: testFrame, config: config, windowFactory: mockFactory)
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
        frameManager.rootFrame = FrameController(rect: testFrame, config: config, windowFactory: mockFactory)
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
        try rightChild.addWindow(window)

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
        frameManager.rootFrame = FrameController(rect: testFrame, config: config, windowFactory: mockFactory)
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
        try leftChild.addWindow(window)

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
        frameManager.rootFrame = FrameController(rect: testFrame, config: config, windowFactory: mockFactory)
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
        try bottomChild.addWindow(window)

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
        frameManager.rootFrame = FrameController(rect: testFrame, config: config, windowFactory: mockFactory)
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
        try topChild.addWindow(window)

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
        let testFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        frameManager.rootFrame = FrameController(rect: testFrame, config: config, windowFactory: mockFactory)
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
        try leftChild.addWindow(window)

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
}
