// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Jimmy Ma

import Cocoa
@testable import Tiled

/// Mock WindowController for testing that doesn't actually move/resize real windows
class MockWindowController: WindowControllerProtocol {
    let windowId: WindowId

    private(set) var raiseCallCount = 0
    private(set) var repositionCallCount = 0

    nonisolated(unsafe) private static var elementCounter: Int = 1

    nonisolated init(title: String) {
        // Create a unique WindowModel for testing
        let pid = pid_t(Self.elementCounter)
        Self.elementCounter += 1

        // For tests, we need a WindowId but WindowId's registry parameter is @MainActor isolated.
        // Since we're in a test and don't actually use the registry, we can create a minimal
        // WindowId that will be valid for our testing purposes
        // We'll defer this to when it's actually needed
        self.windowId = WindowId(appPID: pid, registry: EmptyWindowRegistry())
    }

    nonisolated init(windowId: WindowId) {
        Self.elementCounter += 1

        // For tests, we need a WindowId but WindowId's registry parameter is @MainActor isolated.
        // Since we're in a test and don't actually use the registry, we can create a minimal
        // WindowId that will be valid for our testing purposes
        // We'll defer this to when it's actually needed
        self.windowId = windowId
    }

    func raise() {
        raiseCallCount += 1
        // No-op: don't actually raise windows in tests
    }

    func reposition(to rect: CGRect) throws {
        repositionCallCount += 1
        // No-op: don't actually reposition windows in tests
    }

    var raiseWasCalled: Bool {
        raiseCallCount > 0
    }

    func resetMockState() {
        raiseCallCount = 0
        repositionCallCount = 0
    }
}
