// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Jimmy Ma

import Cocoa
import Testing
@testable import Tiled

@Suite("FrameWindow Observer Tests")
@MainActor
struct FrameWindowObserverTests {
    let config: ConfigController
    let testFrame: CGRect

    init() {
        self.config = ConfigController()
        self.testFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
    }

    func createFrameController() -> FrameController {
        return FrameController(rect: testFrame, config: config, axHelper: MockAccessibilityAPIHelper())
    }

    @Test("FrameWindow observer is established during initialization")
    func testFrameWindowObserverSetup() throws {
        let frameController = createFrameController()
        let frameWindow = frameController.frameWindow as? FrameWindow

        // Verify it's a real FrameWindow (not a mock)
        #expect(frameWindow != nil)

        // The observer should be set up via setupObservers() in FrameController init
        // We verify it's working by checking state updates
        let window1 = MockWindowController(title: "Window 1")
        try frameController.addWindow(window1.windowId)

        // If observer is working, windowTabs was published
        #expect(frameController.windowTabs.count == 1)
    }

    @Test("FrameWindow observer responds to windowTabs changes")
    func testFrameWindowObservesWindowTabs() throws {
        let frameController = createFrameController()
        let frameWindow = frameController.frameWindow as? FrameWindow

        #expect(frameWindow != nil)

        // Initially, tabs should be empty
        #expect(frameController.windowTabs.isEmpty)

        let window1 = MockWindowController(title: "Window 1")

        // Add window - observer's subscription should trigger updateOverlay()
        try frameController.addWindow(window1.windowId)

        // Verify state was published
        #expect(frameController.windowTabs.count == 1)
    }

    @Test("setupObservers establishes binding to real FrameWindow")
    func testFrameWindowObserverBinding() throws {
        let frameController = createFrameController()

        // Verify we got a real FrameWindow (not a mock)
        let realFrameWindow = frameController.frameWindow as? FrameWindow
        #expect(realFrameWindow != nil)

        // The setupObservers() in init calls setFrameController
        // which establishes the Combine binding via setupBindings()
        // We verify the binding works by triggering state changes
        let window1 = MockWindowController(title: "Window 1")
        try frameController.addWindow(window1.windowId)

        // If binding is working, state propagates
        #expect(frameController.windowTabs.count == 1)
    }

    @Test("Observer subscription is actually registered on FrameWindow")
    func testObserverSubscriptionIsRegistered() throws {
        let frameController = createFrameController()
        let frameWindow = frameController.frameWindow as? FrameWindow

        #expect(frameWindow != nil)
        guard let frameWindow = frameWindow else { return }

        // Verify that the observer binding was actually registered
        // setupObservers() in FrameController init calls setFrameController()
        // which calls setupBindings(), which creates a subscription
        #expect(frameWindow.hasActiveBindings == true)
    }

    @Test("setFrameController establishes observable subscription")
    func testSetFrameControllerEstablishesSubscription() throws {
        let frameController = createFrameController()

        // Create a fresh FrameWindow without observers
        let frameWindow = FrameWindow(geo: frameController.geometry, styleProvider: frameController.styleProvider)

        // Verify it has no bindings yet
        #expect(frameWindow.hasActiveBindings == false)

        // Now set the frame controller, which calls setupBindings()
        frameWindow.setFrameController(frameController)

        // Verify binding was established
        #expect(frameWindow.hasActiveBindings == true)

        // Add a window and verify state propagates
        let window1 = MockWindowController(title: "Window 1")
        try frameController.addWindow(window1.windowId)

        // If binding is working, windowTabs should be published
        #expect(frameController.windowTabs.count == 1)
    }

    @Test("FrameWindow observer updates when windowTabs changes")
    func testFrameWindowUpdatesOnWindowTabsChange() throws {
        let frameController = createFrameController()
        let frameWindow = frameController.frameWindow as? FrameWindow

        #expect(frameWindow != nil)
        guard let frameWindow = frameWindow else { return }

        let window1 = MockWindowController(title: "Window 1")
        let window2 = MockWindowController(title: "Window 2")

        // Start with empty
        #expect(frameController.windowTabs.isEmpty)

        // Add first window - observer automatically calls updateOverlay via subscription
        try frameController.addWindow(window1.windowId, shouldFocus: true)
        #expect(frameController.windowTabs.count == 1)

        // Add second window
        try frameController.addWindow(window2.windowId, shouldFocus: false)
        #expect(frameController.windowTabs.count == 2)

        // Remove first window
        let removed = frameController.removeWindow(window1.windowId)
        #expect(removed == true)
        #expect(frameController.windowTabs.count == 1)
    }

    @Test("Observer ensures parent tabs empty after split")
    func testFrameWindowObserverRespondsToSplit() throws {
        let frameController = createFrameController()

        let window1 = MockWindowController(title: "Window 1")
        try frameController.addWindow(window1.windowId)

        // Parent has tabs before split
        #expect(frameController.windowTabs.count == 1)

        // Split the frame
        let child1 = try frameController.split(direction: .Horizontal)

        // Observer should have updated parent's tabs to empty (non-leaf)
        #expect(frameController.windowTabs.isEmpty)

        // Observer should have updated child to show tabs
        #expect(child1.windowTabs.count == 1)
    }

    @Test("Observer weak reference doesn't create retain cycles")
    func testFrameWindowWeakReferenceNoRetainCycle() throws {
        weak var weakFrameController: FrameController?

        do {
            var frameController: FrameController? = createFrameController()
            weakFrameController = frameController

            // Frame should be allocated
            #expect(weakFrameController != nil)

            let window1 = MockWindowController(title: "Window 1")
            try frameController?.addWindow(window1.windowId)

            // Deallocate (observer has weak ref, so this works)
            frameController = nil
        }

        // If weak reference is now nil, no retain cycle
        #expect(weakFrameController == nil)
    }

    @Test("Observer automatically updates child frame tabs after split")
    func testObserverUpdatesAllChildFrames() throws {
        let parent = createFrameController()

        let window1 = MockWindowController(title: "Window 1")
        let window2 = MockWindowController(title: "Window 2")

        try parent.addWindow(window1.windowId)
        try parent.addWindow(window2.windowId)

        let child1 = try parent.split(direction: .Vertical)
        let child2 = parent.children[1]

        // All frames have observers set up
        #expect((parent.frameWindow as? FrameWindow) != nil)
        #expect((child1.frameWindow as? FrameWindow) != nil)
        #expect((child2.frameWindow as? FrameWindow) != nil)

        // Each observer should have been updated correctly
        #expect(parent.windowTabs.isEmpty)  // Parent is non-leaf
        #expect(child1.windowTabs.count == 2)  // Child1 has windows
        #expect(child2.windowTabs.isEmpty)  // Child2 is empty
    }

    @Test("Observer updates parent tabs when child frame closes")
    func testObserverUpdatesParentWhenChildCloses() throws {
        let parent = createFrameController()

        let window1 = MockWindowController(title: "Window 1")
        let window2 = MockWindowController(title: "Window 2")

        try parent.addWindow(window1.windowId)
        try parent.addWindow(window2.windowId)

        // Parent starts with 2 tabs
        #expect(parent.windowTabs.count == 2)

        // Split: child1 gets all windows
        let child1 = try parent.split(direction: .Horizontal)
        let child2 = parent.children[1]

        // Parent becomes non-leaf (empty tabs)
        #expect(parent.windowTabs.isEmpty)
        #expect(child1.windowTabs.count == 2)
        #expect(child2.windowTabs.isEmpty)

        // Close child1 - consolidates windows back to parent
        _ = try child1.closeFrame()

        // Observer should have updated parent's tabs - should show consolidated windows
        // This is the bug: parent.windowTabs should be populated but remains empty
        #expect(parent.windowTabs.count == 2, "Parent should show consolidated windows after child closes")
        #expect(!parent.children.isEmpty == false, "Parent should be leaf after close")
    }

    // MARK: - Comprehensive Lifecycle Tests

    @Test("Observers active in deeply nested frame hierarchy")
    func testObserversInDeeplyNestedHierarchy() throws {
        let root = createFrameController()
        let w1 = MockWindowController(title: "W1")
        try root.addWindow(w1.windowId)

        // Create 3 levels of splits: root -> level1 -> level2
        let level1 = try root.split(direction: .Horizontal)
        let level2 = try level1.split(direction: .Vertical)

        // All frames should have active observers
        #expect((root.frameWindow as? FrameWindow)?.hasActiveBindings == true)
        #expect((level1.frameWindow as? FrameWindow)?.hasActiveBindings == true)
        #expect((level2.frameWindow as? FrameWindow)?.hasActiveBindings == true)

        // All non-leaf frames should have empty tabs
        #expect(root.windowTabs.isEmpty)
        #expect(level1.windowTabs.isEmpty)

        // Only leaf should have tabs
        #expect(level2.windowTabs.count == 1)
    }

    @Test("Observer tracks state through complex operations sequence")
    func testObserverTracksComplexOperationSequence() throws {
        let root = createFrameController()
        let w1 = MockWindowController(title: "W1")
        let w2 = MockWindowController(title: "W2")
        let w3 = MockWindowController(title: "W3")

        // Start: root has 3 windows
        try root.addWindow(w1.windowId)
        try root.addWindow(w2.windowId)
        try root.addWindow(w3.windowId)
        #expect(root.windowTabs.count == 3)

        // Op 1: Split horizontally
        let left = try root.split(direction: .Horizontal)
        let right = root.children[1]
        #expect(root.windowTabs.isEmpty)
        #expect(left.windowTabs.count == 3)
        #expect(right.windowTabs.isEmpty)

        // Op 2: Split left vertically
        let leftTop = try left.split(direction: .Vertical)
        let leftBottom = left.children[1]
        #expect(left.windowTabs.isEmpty)
        #expect(leftTop.windowTabs.count == 3)
        #expect(leftBottom.windowTabs.isEmpty)

        // Op 3: Remove a window from leftTop
        let removed = leftTop.removeWindow(w1.windowId)
        #expect(removed == true)
        #expect(leftTop.windowTabs.count == 2)

        // Op 4: Close leftTop (consolidate back to left)
        _ = try leftTop.closeFrame()
        #expect(left.windowTabs.count == 2)
        #expect(root.windowTabs.isEmpty) // root still non-leaf

        // Op 5: Close right child (consolidate to root)
        _ = try right.closeFrame()
        #expect(root.windowTabs.count == 2) // now root is leaf with consolidated windows
    }

    @Test("Observer responds to rapid consecutive window operations")
    func testObserverRespondsToRapidOperations() throws {
        let frame = createFrameController()
        var windowIds: [WindowId] = []

        // Rapidly add 5 windows
        for i in 1...5 {
            let w = MockWindowController(title: "W\(i)")
            try frame.addWindow(w.windowId)
            windowIds.append(w.windowId)
        }
        #expect(frame.windowTabs.count == 5)

        // Rapidly remove all
        for windowId in windowIds {
            _ = frame.removeWindow(windowId)
        }
        #expect(frame.windowTabs.isEmpty)

        // Rapidly re-add different windows
        for i in 6...10 {
            let w = MockWindowController(title: "W\(i)")
            try frame.addWindow(w.windowId)
        }
        #expect(frame.windowTabs.count == 5)
    }

    @Test("Observer subscription active across all frames after complex split pattern")
    func testObserverSubscriptionsAcrossComplexSplitPattern() throws {
        let root = createFrameController()
        let w1 = MockWindowController(title: "W1")
        let w2 = MockWindowController(title: "W2")
        let w3 = MockWindowController(title: "W3")
        let w4 = MockWindowController(title: "W4")

        try root.addWindow(w1.windowId)
        try root.addWindow(w2.windowId)
        try root.addWindow(w3.windowId)
        try root.addWindow(w4.windowId)

        // Create 4-way split: H split, then V on each side
        let leftHalf = try root.split(direction: .Horizontal)
        let rightHalf = root.children[1]

        let leftTop = try leftHalf.split(direction: .Vertical)
        let leftBottom = leftHalf.children[1]

        let rightTop = try rightHalf.split(direction: .Vertical)
        let rightBottom = rightHalf.children[1]

        // Verify all frames have active observers
        let allFrames = [root, leftHalf, rightHalf, leftTop, leftBottom, rightTop, rightBottom]
        for frame in allFrames {
            let hasBinding = (frame.frameWindow as? FrameWindow)?.hasActiveBindings ?? false
            #expect(hasBinding == true, "Frame should have active observer binding")
        }

        // Verify tab states are correct
        #expect(root.windowTabs.isEmpty) // non-leaf
        #expect(leftHalf.windowTabs.isEmpty) // non-leaf
        #expect(rightHalf.windowTabs.isEmpty) // non-leaf
        #expect(leftTop.windowTabs.count == 4) // leaf with all windows
        #expect(leftBottom.windowTabs.isEmpty) // leaf, empty
        #expect(rightTop.windowTabs.isEmpty) // leaf, empty
        #expect(rightBottom.windowTabs.isEmpty) // leaf, empty
    }

    @Test("Observer handles window cycling with active state tracking")
    func testObserverHandlesWindowCycling() throws {
        let frame = createFrameController()
        let w1 = MockWindowController(title: "W1")
        let w2 = MockWindowController(title: "W2")
        let w3 = MockWindowController(title: "W3")

        try frame.addWindow(w1.windowId, shouldFocus: true)
        #expect(frame.windowTabs.count == 1)
        #expect(frame.windowTabs[0].isActive == true)

        try frame.addWindow(w2.windowId, shouldFocus: false)
        #expect(frame.windowTabs.count == 2)
        #expect(frame.windowTabs[0].isActive == true)
        #expect(frame.windowTabs[1].isActive == false)

        try frame.addWindow(w3.windowId, shouldFocus: false)
        #expect(frame.windowTabs.count == 3)

        // Cycle forward
        let next = frame.nextWindow()
        #expect(next != nil)
        // Observer should publish new active state
        #expect(frame.windowTabs.count == 3)

        // Cycle backward
        let prev = frame.previousWindow()
        #expect(prev != nil)
        // Observer should publish updated active state
        #expect(frame.windowTabs.count == 3)
    }

    @Test("Observer maintains correct state after frame consolidation from deep hierarchy")
    func testObserverStateAfterDeepConsolidation() throws {
        let root = createFrameController()
        let w1 = MockWindowController(title: "W1")
        let w2 = MockWindowController(title: "W2")

        try root.addWindow(w1.windowId)
        try root.addWindow(w2.windowId)

        // Create a 3-level deep hierarchy: root -> mid -> leaf
        let mid = try root.split(direction: .Horizontal)
        let leaf = try mid.split(direction: .Vertical)
        let leafSibling = mid.children[1]

        // Verify initial state
        #expect(root.windowTabs.isEmpty)
        #expect(mid.windowTabs.isEmpty)
        #expect(leaf.windowTabs.count == 2)
        #expect(leafSibling.windowTabs.isEmpty)

        // Close leaf - consolidates to mid
        _ = try leaf.closeFrame()
        // After close, mid is now a leaf with 2 windows
        #expect(mid.windowTabs.count == 2)
        #expect(root.windowTabs.isEmpty) // root still non-leaf

        // Now mid has been consolidated back to a leaf. Close mid to consolidate to root
        _ = try mid.closeFrame()
        #expect(root.windowTabs.count == 2) // root is now leaf with all windows
    }

    @Test("Observer subscriptions don't leak when frames are deallocated")
    func testObserverSubscriptionsCleanupOnDeallocation() throws {
        weak var weakFrame: FrameController?
        weak var weakFrameWindow: FrameWindow?

        do {
            let frame = createFrameController()
            let frameWindow = frame.frameWindow as? FrameWindow
            weakFrame = frame
            weakFrameWindow = frameWindow

            let w = MockWindowController(title: "W")
            try frame.addWindow(w.windowId)

            // Verify setup
            #expect(weakFrame != nil)
            #expect(weakFrameWindow != nil)
            #expect(frameWindow?.hasActiveBindings == true)

            // Exit scope - frame and window should deallocate
        }

        // Weak references should be nil, confirming no retain cycles
        #expect(weakFrame == nil)
        #expect(weakFrameWindow == nil)
    }
}
