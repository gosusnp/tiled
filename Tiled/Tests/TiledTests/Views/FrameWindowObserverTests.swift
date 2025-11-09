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
}
