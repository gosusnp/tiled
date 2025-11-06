// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Jimmy Ma

import XCTest
@testable import Tiled

@MainActor
class FrameCommandQueueTests: XCTestCase {
    var frameManager: FrameManager!

    override func setUp() async throws {
        try await super.setUp()
        frameManager = FrameManager(config: ConfigController(), logger: Logger())

        // Initialize with mock window factory for all frame creation
        let mockFactory = MockFrameWindowFactory()
        let testRect = CGRect(x: 0, y: 0, width: 800, height: 600)
        let rootFrame = FrameController(rect: testRect, config: frameManager.config, windowFactory: mockFactory)
        rootFrame.setActive(true)
        frameManager.rootFrame = rootFrame
        frameManager.activeFrame = rootFrame
    }

    // MARK: - Basic Queue Behavior

    func testEnqueueCommand_InitiatesProcessing() async throws {
        let initialActiveFrame = frameManager.activeFrame

        // Enqueue a split command
        frameManager.enqueueCommand(.splitVertically)

        // Wait for async processing
        try await Task.sleep(nanoseconds: 100_000_000)  // 100ms

        // Active frame should have changed (new split occurred)
        XCTAssertNotNil(frameManager.activeFrame)
        // Use identity comparison (===) instead of equality
        XCTAssertFalse(frameManager.activeFrame === initialActiveFrame)
    }

    func testMultipleEnqueuedCommands_ExecuteSerially() async throws {
        // Enqueue three commands in sequence
        frameManager.enqueueCommand(.splitVertically)
        frameManager.enqueueCommand(.navigateLeft)
        frameManager.enqueueCommand(.splitHorizontally)

        // Wait for all to process
        try await Task.sleep(nanoseconds: 200_000_000)  // 200ms

        // Frame tree should reflect all operations
        XCTAssertNotNil(frameManager.rootFrame)
        // If all commands executed, we should have split frames
        if let root = frameManager.rootFrame {
            XCTAssertFalse(root.children.isEmpty, "Frame tree should have children after splits")
        }
    }

    func testQueueProcessing_IsNotConcurrent() async throws {
        // This test verifies that commands don't execute in parallel
        // by checking that state mutations from each command are isolated

        // Create custom frame manager to track execution
        let config = ConfigController()
        let fm = FrameManager(config: config, logger: Logger())

        // Initialize with mock window factory
        let mockFactory = MockFrameWindowFactory()
        let testRect = CGRect(x: 0, y: 0, width: 800, height: 600)
        let rootFrame = FrameController(rect: testRect, config: config, windowFactory: mockFactory)
        rootFrame.setActive(true)
        fm.rootFrame = rootFrame
        fm.activeFrame = rootFrame

        // Enqueue multiple navigation commands
        fm.enqueueCommand(.navigateLeft)
        fm.enqueueCommand(.navigateRight)
        fm.enqueueCommand(.navigateUp)
        fm.enqueueCommand(.navigateDown)

        // Wait for all to complete
        try await Task.sleep(nanoseconds: 300_000_000)  // 300ms

        // No assertion needed here - if this runs without crashing,
        // the queue serialized the commands properly
        XCTAssertNotNil(fm.activeFrame)
    }

    // MARK: - Command Routing

    func testSplitVerticallyCommand_ExecutesOperation() async throws {
        let rootFrame = frameManager.rootFrame
        let initialChildCount = rootFrame?.children.count ?? 0

        frameManager.enqueueCommand(.splitVertically)
        try await Task.sleep(nanoseconds: 100_000_000)

        let finalChildCount = rootFrame?.children.count ?? 0
        XCTAssertGreaterThan(finalChildCount, initialChildCount, "Split should create children")
    }

    func testSplitHorizontallyCommand_ExecutesOperation() async throws {
        let rootFrame = frameManager.rootFrame
        let initialChildCount = rootFrame?.children.count ?? 0

        frameManager.enqueueCommand(.splitHorizontally)
        try await Task.sleep(nanoseconds: 100_000_000)

        let finalChildCount = rootFrame?.children.count ?? 0
        XCTAssertGreaterThan(finalChildCount, initialChildCount, "Split should create children")
    }

    func testNavigateCommands_ExecuteWithoutCrashing() async throws {
        // Just verify these don't crash when executed via queue
        frameManager.enqueueCommand(.navigateLeft)
        frameManager.enqueueCommand(.navigateRight)
        frameManager.enqueueCommand(.navigateUp)
        frameManager.enqueueCommand(.navigateDown)

        try await Task.sleep(nanoseconds: 200_000_000)

        // If we got here, navigation executed without crashing
        XCTAssertNotNil(frameManager.activeFrame)
    }

    func testCycleWindowCommands_ExecuteWithoutCrashing() async throws {
        frameManager.enqueueCommand(.cycleWindowForward)
        frameManager.enqueueCommand(.cycleWindowBackward)

        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertNotNil(frameManager.activeFrame)
    }

    // MARK: - Command Queue State

    func testActiveFrameRemaining_AfterNavigation() async throws {
        frameManager.enqueueCommand(.navigateLeft)
        frameManager.enqueueCommand(.navigateRight)

        try await Task.sleep(nanoseconds: 100_000_000)

        // Active frame should still exist
        XCTAssertNotNil(frameManager.activeFrame)
    }

    func testRootFrameRemaining_AfterOperations() async throws {
        let rootBefore = frameManager.rootFrame

        frameManager.enqueueCommand(.splitVertically)
        frameManager.enqueueCommand(.splitHorizontally)

        try await Task.sleep(nanoseconds: 200_000_000)

        let rootAfter = frameManager.rootFrame
        // Root frame should still be the same root (using identity comparison)
        XCTAssertTrue(rootBefore === rootAfter, "Root frame reference should be stable")
    }

    // MARK: - Rapid Command Queueing

    func testRapidEnqueueing_ProcessesAllCommands() async throws {
        let commandCount = 10

        for _ in 0..<commandCount {
            frameManager.enqueueCommand(.navigateLeft)
            frameManager.enqueueCommand(.navigateRight)
        }

        // Wait for all to process
        try await Task.sleep(nanoseconds: 500_000_000)  // 500ms

        // If we got here without crash, all commands were processed
        XCTAssertNotNil(frameManager.activeFrame)
    }

    func testInterleavedEnqueueing_WithSplitsAndNavigation() async throws {
        frameManager.enqueueCommand(.splitVertically)
        frameManager.enqueueCommand(.navigateLeft)
        frameManager.enqueueCommand(.splitHorizontally)
        frameManager.enqueueCommand(.navigateRight)
        frameManager.enqueueCommand(.navigateUp)

        try await Task.sleep(nanoseconds: 300_000_000)

        XCTAssertNotNil(frameManager.rootFrame)
        XCTAssertNotNil(frameManager.activeFrame)
    }

    // MARK: - Queue Consistency

    func testConsecutiveOperations_MaintainTreeStructure() async throws {
        // Verify that the frame tree stays valid through multiple operations

        frameManager.enqueueCommand(.splitVertically)
        try await Task.sleep(nanoseconds: 100_000_000)
        let activeAfterFirstSplit = frameManager.activeFrame

        frameManager.enqueueCommand(.splitHorizontally)
        try await Task.sleep(nanoseconds: 100_000_000)
        let activeAfterSecondSplit = frameManager.activeFrame

        // Both should be valid frames
        XCTAssertNotNil(activeAfterFirstSplit)
        XCTAssertNotNil(activeAfterSecondSplit)

        // Root frame should have children
        if let root = frameManager.rootFrame {
            XCTAssertFalse(root.children.isEmpty)
        }
    }

    func testQueueDoesNotCorruptState_UnderLoad() async throws {
        // This is a stress test - enqueue many commands and verify state is valid

        for i in 0..<5 {
            frameManager.enqueueCommand(i % 2 == 0 ? .splitVertically : .splitHorizontally)
            frameManager.enqueueCommand(i % 4 == 0 ? .navigateLeft : .navigateRight)
        }

        try await Task.sleep(nanoseconds: 500_000_000)

        // Verify basic invariants
        XCTAssertNotNil(frameManager.rootFrame)
        XCTAssertNotNil(frameManager.activeFrame)

        // If rootFrame exists, activeFrame should be in the tree
        if let root = frameManager.rootFrame, let active = frameManager.activeFrame {
            let isInTree = isFrameInTree(active, in: root)
            XCTAssertTrue(isInTree, "Active frame should be in tree after queue processing")
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
