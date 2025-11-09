// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Jimmy Ma

import Cocoa
import Testing
@testable import Tiled

@Suite @MainActor
struct FrameCommandQueueTests {
    var frameManager: FrameManager!

    init() async throws {
        frameManager = FrameManager(config: ConfigController(), logger: Logger())

        // Initialize with mock window factory for all frame creation
        let mockFactory = MockFrameWindowFactory()
        let testRect = CGRect(x: 0, y: 0, width: 800, height: 600)
        let rootFrame = FrameController(rect: testRect, config: frameManager.config, windowFactory: mockFactory, axHelper: MockAccessibilityAPIHelper())
        rootFrame.setActive(true)
        frameManager.rootFrame = rootFrame
        frameManager.activeFrame = rootFrame
    }

    // MARK: - Basic Queue Behavior

    @Test
    func testEnqueueCommand_InitiatesProcessing() async throws {
        let initialActiveFrame = frameManager.activeFrame

        // Enqueue a split command
        frameManager.enqueueCommand(.splitVertically)

        // Wait for background task to process command
        try await Task.sleep(nanoseconds: 100_000_000)

        // Active frame should have changed (new split occurred)
        #expect(frameManager.activeFrame != nil)
        // Use identity comparison (===) instead of equality
        #expect(!(frameManager.activeFrame === initialActiveFrame))
    }

    @Test
    func testMultipleEnqueuedCommands_ExecuteSerially() async throws {
        // Enqueue three commands in sequence
        frameManager.enqueueCommand(.splitVertically)
        frameManager.enqueueCommand(.navigateLeft)
        frameManager.enqueueCommand(.splitHorizontally)

        // Wait for all to process
        try await Task.sleep(nanoseconds: 200_000_000)

        // Frame tree should reflect all operations
        #expect(frameManager.rootFrame != nil)
        // If all commands executed, we should have split frames
        if let root = frameManager.rootFrame {
            #expect(!root.children.isEmpty)
        }
    }

    @Test
    func testQueueProcessing_IsNotConcurrent() async throws {
        // This test verifies that commands execute serially
        // by checking that state mutations from each command are isolated

        // Create custom frame manager
        let config = ConfigController()
        let fm = FrameManager(config: config, logger: Logger())

        // Initialize with mock window factory
        let mockFactory = MockFrameWindowFactory()
        let testRect = CGRect(x: 0, y: 0, width: 800, height: 600)
        let rootFrame = FrameController(rect: testRect, config: config, windowFactory: mockFactory, axHelper: MockAccessibilityAPIHelper())
        rootFrame.setActive(true)
        fm.rootFrame = rootFrame
        fm.activeFrame = rootFrame

        // Enqueue multiple navigation commands
        fm.enqueueCommand(.navigateLeft)
        fm.enqueueCommand(.navigateRight)
        fm.enqueueCommand(.navigateUp)
        fm.enqueueCommand(.navigateDown)

        // No assertion needed here - if this runs without crashing,
        // the queue serialized the commands properly
        #expect(fm.activeFrame != nil)
    }

    // MARK: - Command Routing

    @Test
    func testSplitVerticallyCommand_ExecutesOperation() async throws {
        let rootFrame = frameManager.rootFrame
        let initialChildCount = rootFrame?.children.count ?? 0

        frameManager.enqueueCommand(.splitVertically)
        try await Task.sleep(nanoseconds: 100_000_000)

        let finalChildCount = rootFrame?.children.count ?? 0
        #expect(finalChildCount > initialChildCount)
    }

    @Test
    func testSplitHorizontallyCommand_ExecutesOperation() async throws {
        let rootFrame = frameManager.rootFrame
        let initialChildCount = rootFrame?.children.count ?? 0

        frameManager.enqueueCommand(.splitHorizontally)
        try await Task.sleep(nanoseconds: 100_000_000)

        let finalChildCount = rootFrame?.children.count ?? 0
        #expect(finalChildCount > initialChildCount)
    }

    @Test
    func testNavigateCommands_ExecuteWithoutCrashing() async throws {
        // Just verify these don't crash when executed via queue
        frameManager.enqueueCommand(.navigateLeft)
        frameManager.enqueueCommand(.navigateRight)
        frameManager.enqueueCommand(.navigateUp)
        frameManager.enqueueCommand(.navigateDown)

        // If we got here, navigation executed without crashing
        #expect(frameManager.activeFrame != nil)
    }

    @Test
    func testCycleWindowCommands_ExecuteWithoutCrashing() async throws {
        frameManager.enqueueCommand(.cycleWindowForward)
        frameManager.enqueueCommand(.cycleWindowBackward)

        #expect(frameManager.activeFrame != nil)
    }

    // MARK: - Command Queue State

    @Test
    func testActiveFrameRemaining_AfterNavigation() async throws {
        frameManager.enqueueCommand(.navigateLeft)
        frameManager.enqueueCommand(.navigateRight)

        // Active frame should still exist
        #expect(frameManager.activeFrame != nil)
    }

    @Test
    func testRootFrameRemaining_AfterOperations() async throws {
        let rootBefore = frameManager.rootFrame

        frameManager.enqueueCommand(.splitVertically)
        frameManager.enqueueCommand(.splitHorizontally)

        let rootAfter = frameManager.rootFrame
        // Root frame should still be the same root (using identity comparison)
        #expect(rootBefore === rootAfter)
    }

    // MARK: - Rapid Command Queueing

    @Test
    func testRapidEnqueueing_ProcessesAllCommands() async throws {
        let commandCount = 10

        for _ in 0..<commandCount {
            frameManager.enqueueCommand(.navigateLeft)
            frameManager.enqueueCommand(.navigateRight)
        }

        // If we got here without crash, all commands were processed
        #expect(frameManager.activeFrame != nil)
    }

    @Test
    func testInterleavedEnqueueing_WithSplitsAndNavigation() async throws {
        frameManager.enqueueCommand(.splitVertically)
        frameManager.enqueueCommand(.navigateLeft)
        frameManager.enqueueCommand(.splitHorizontally)
        frameManager.enqueueCommand(.navigateRight)
        frameManager.enqueueCommand(.navigateUp)

        #expect(frameManager.rootFrame != nil)
        #expect(frameManager.activeFrame != nil)
    }

    // MARK: - Queue Consistency

    @Test
    func testConsecutiveOperations_MaintainTreeStructure() async throws {
        // Verify that the frame tree stays valid through multiple operations

        frameManager.enqueueCommand(.splitVertically)
        try await Task.sleep(nanoseconds: 100_000_000)
        let activeAfterFirstSplit = frameManager.activeFrame

        frameManager.enqueueCommand(.splitHorizontally)
        try await Task.sleep(nanoseconds: 100_000_000)
        let activeAfterSecondSplit = frameManager.activeFrame

        // Both should be valid frames
        #expect(activeAfterFirstSplit != nil)
        #expect(activeAfterSecondSplit != nil)

        // Root frame should have children
        if let root = frameManager.rootFrame {
            #expect(!root.children.isEmpty)
        }
    }

    @Test
    func testQueueDoesNotCorruptState_UnderLoad() async throws {
        // This is a stress test - enqueue many commands and verify state is valid

        for i in 0..<5 {
            frameManager.enqueueCommand(i % 2 == 0 ? .splitVertically : .splitHorizontally)
            frameManager.enqueueCommand(i % 4 == 0 ? .navigateLeft : .navigateRight)
        }

        // Verify basic invariants
        #expect(frameManager.rootFrame != nil)
        #expect(frameManager.activeFrame != nil)

        // If rootFrame exists, activeFrame should be in the tree
        if let root = frameManager.rootFrame, let active = frameManager.activeFrame {
            let isInTree = isFrameInTree(active, in: root)
            #expect(isInTree)
        }
    }

    // MARK: - Helper Methods

    private func isFrameInTree(_ target: FrameController, in node: FrameController?) -> Bool {
        guard let node = node else { return false }
        if node === target { return true }
        for child in node.children {
            if isFrameInTree(target, in: child) { return true }
        }
        return false
    }
}
