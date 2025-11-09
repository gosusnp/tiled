// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Jimmy Ma

import Cocoa
import Testing
@testable import Tiled

@Suite("WindowPollingService Tests")
struct WindowPollingServiceTests {
    let logger: Logger

    init() {
        self.logger = Logger()
    }

    @Test("Poller only emits closure event once, not on subsequent polls")
    func testClosureEmittedOnceOnly() throws {
        let mockAxHelper = TestAccessibilityAPIHelper()
        let mockWorkspaceProvider = TestWorkspaceProvider()

        let service = WindowPollingService(
            logger: logger,
            workspaceProvider: mockWorkspaceProvider,
            axHelper: mockAxHelper
        )

        var closureEventCount = 0
        service.onWindowClosed = { _ in
            closureEventCount += 1
        }

        let testElement = AXUIElementCreateApplication(getpid())
        mockAxHelper.returnWindows = [testElement]
        mockAxHelper.windowIDMap[ObjectIdentifier(testElement)] = CGWindowID(888)

        service.startPolling()
        Thread.sleep(forTimeInterval: 0.1)

        // Close window
        mockAxHelper.returnWindows = []
        Thread.sleep(forTimeInterval: 0.2)

        let eventCountAfterClose = closureEventCount

        // Next poll should not emit another closure event
        Thread.sleep(forTimeInterval: 0.1)

        #expect(closureEventCount == eventCountAfterClose, "Closure should only be emitted once, not duplicated on subsequent polls")

        service.stopPolling()
    }

    @Test("Polling service can be started and stopped")
    func testStartStopPolling() throws {
        let mockAxHelper = TestAccessibilityAPIHelper()
        let mockWorkspaceProvider = TestWorkspaceProvider()

        let service = WindowPollingService(
            logger: logger,
            workspaceProvider: mockWorkspaceProvider,
            axHelper: mockAxHelper
        )

        #expect(!service.isPolling)

        service.startPolling()
        Thread.sleep(forTimeInterval: 0.05)
        #expect(service.isPolling)

        service.stopPolling()
        Thread.sleep(forTimeInterval: 0.05)
        #expect(!service.isPolling)
    }

    @Test("Poller handles window provider returning no windows")
    func testHandlesEmptyWindowList() throws {
        let mockAxHelper = TestAccessibilityAPIHelper()
        let mockWorkspaceProvider = TestWorkspaceProvider()

        let service = WindowPollingService(
            logger: logger,
            workspaceProvider: mockWorkspaceProvider,
            axHelper: mockAxHelper
        )

        var callCount = 0
        service.onWindowOpened = { _ in
            callCount += 1
        }
        service.onWindowClosed = { _ in
            callCount += 1
        }

        mockAxHelper.returnWindows = []

        service.startPolling()
        Thread.sleep(forTimeInterval: 0.2)

        // Should handle empty list gracefully without calling callbacks
        #expect(callCount == 0, "No callbacks should fire for empty window list")

        service.stopPolling()
    }

    @Test("Window closure callbacks are optional")
    func testOptionalCallbacks() throws {
        let mockAxHelper = TestAccessibilityAPIHelper()
        let mockWorkspaceProvider = TestWorkspaceProvider()

        let service = WindowPollingService(
            logger: logger,
            workspaceProvider: mockWorkspaceProvider,
            axHelper: mockAxHelper
        )

        // Don't set callbacks - should not crash
        mockAxHelper.returnWindows = []

        service.startPolling()
        Thread.sleep(forTimeInterval: 0.1)
        service.stopPolling()

        // If we reach here without crashing, test passes
        #expect(true)
    }
}

