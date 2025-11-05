// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Jimmy Ma

import Cocoa
@testable import Tiled

/// Mock WindowController for testing that doesn't actually move/resize real windows
class MockWindowController: WindowControllerProtocol {
    let window: WindowModel
    weak var frame: FrameController?

    private(set) var raiseCallCount = 0
    private(set) var moveCallCount = 0
    private(set) var resizeCallCount = 0

    var appName: String { window.appName }
    var title: String { window.title }

    var isFocused: Bool { false }
    var isMain: Bool { false }
    var size: CGSize { CGSize(width: 800, height: 600) }

    nonisolated(unsafe) private static var elementCounter: Int = 1

    init(title: String) {
        // Create a unique WindowModel for testing
        let pid = pid_t(Self.elementCounter)
        Self.elementCounter += 1

        let element = AXUIElementCreateApplication(pid)
        self.window = WindowModel(element: element, title: title, appName: "MockApp")
    }

    func raise() {
        raiseCallCount += 1
        // No-op: don't actually raise windows in tests
    }

    func move(to: CGPoint) throws {
        moveCallCount += 1
        // No-op: don't actually move windows in tests
    }

    func resize(size: CGSize) throws {
        resizeCallCount += 1
        // No-op: don't actually resize windows in tests
    }
}
