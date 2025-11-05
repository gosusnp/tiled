// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Jimmy Ma

import Cocoa
import Testing
@testable import GosuTile

@Suite("WindowPollingService Tests")
struct WindowPollingServiceTests {
    let logger: Logger

    init() {
        self.logger = Logger()
    }

    @Test("Poller only emits closure event once, not on subsequent polls")
    func testClosureEmittedOnceOnly() throws {
        let mockWindowProvider = TestWindowProvider()
        let mockWorkspaceProvider = TestWorkspaceProvider()

        let service = WindowPollingService(
            logger: logger,
            workspaceProvider: mockWorkspaceProvider,
            windowProvider: mockWindowProvider
        )

        var closureEventCount = 0
        service.onWindowClosed = { _ in
            closureEventCount += 1
        }

        let testElement = AXUIElementCreateApplication(getpid())
        mockWindowProvider.returnWindows = [testElement]
        mockWindowProvider.windowIDMap[ObjectIdentifier(testElement)] = CGWindowID(888)

        service.startPolling()
        Thread.sleep(forTimeInterval: 0.1)

        // Close window
        mockWindowProvider.returnWindows = []
        Thread.sleep(forTimeInterval: 0.2)

        let eventCountAfterClose = closureEventCount

        // Next poll should not emit another closure event
        Thread.sleep(forTimeInterval: 0.1)

        #expect(closureEventCount == eventCountAfterClose, "Closure should only be emitted once, not duplicated on subsequent polls")

        service.stopPolling()
    }

    @Test("Polling service can be started and stopped")
    func testStartStopPolling() throws {
        let mockWindowProvider = TestWindowProvider()
        let mockWorkspaceProvider = TestWorkspaceProvider()

        let service = WindowPollingService(
            logger: logger,
            workspaceProvider: mockWorkspaceProvider,
            windowProvider: mockWindowProvider
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
        let mockWindowProvider = TestWindowProvider()
        let mockWorkspaceProvider = TestWorkspaceProvider()

        let service = WindowPollingService(
            logger: logger,
            workspaceProvider: mockWorkspaceProvider,
            windowProvider: mockWindowProvider
        )

        var callCount = 0
        service.onWindowOpened = { _ in
            callCount += 1
        }
        service.onWindowClosed = { _ in
            callCount += 1
        }

        mockWindowProvider.returnWindows = []

        service.startPolling()
        Thread.sleep(forTimeInterval: 0.2)

        // Should handle empty list gracefully without calling callbacks
        #expect(callCount == 0, "No callbacks should fire for empty window list")

        service.stopPolling()
    }

    @Test("Window closure callbacks are optional")
    func testOptionalCallbacks() throws {
        let mockWindowProvider = TestWindowProvider()
        let mockWorkspaceProvider = TestWorkspaceProvider()

        let service = WindowPollingService(
            logger: logger,
            workspaceProvider: mockWorkspaceProvider,
            windowProvider: mockWindowProvider
        )

        // Don't set callbacks - should not crash
        mockWindowProvider.returnWindows = []

        service.startPolling()
        Thread.sleep(forTimeInterval: 0.1)
        service.stopPolling()

        // If we reach here without crashing, test passes
        #expect(true)
    }
}

