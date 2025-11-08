// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Jimmy Ma

import Cocoa
import Testing
import ApplicationServices
@testable import Tiled

// MARK: - WindowController Tests

@Suite("WindowController")
@MainActor
struct WindowControllerTests {
    var registry: MockWindowRegistry!

    init() {
        registry = MockWindowRegistry()
    }

    @Test("stores and retains windowId reference")
    func storesWindowId() {
        let windowId = WindowId(appPID: 1234, registry: registry)
        let controller = WindowController(windowId: windowId, title: "Test", appName: "TestApp")

        #expect(controller.windowId === windowId)
    }

    @Test("appName property returns Unknown when window is nil")
    func appNameProperty() {
        let windowId = WindowId(appPID: 1234, registry: registry)

        let controller = WindowController(windowId: windowId, title: "Test", appName: "Unused")

        // WindowId-based init has window = nil, so appName falls back to "Unknown"
        #expect(controller.appName == "Unknown")
    }
}
