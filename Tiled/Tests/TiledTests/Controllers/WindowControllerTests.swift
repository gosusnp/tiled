// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Jimmy Ma

import Cocoa
import Testing
@testable import Tiled

@Suite("WindowController Tests")
@MainActor
struct WindowControllerTests {
    let mockRegistry: MockWindowRegistry
    let mockHelper: MockAccessibilityAPIHelper
    let mockElement: AXUIElement

    init() {
        self.mockRegistry = MockWindowRegistry()
        self.mockHelper = MockAccessibilityAPIHelper()
        self.mockHelper.getAppPIDResult = 123
        self.mockElement = AXUIElementCreateApplication(123)
    }

    // MARK: - Initialization Tests

    @Test("Creates WindowController with WindowId")
    func testInitialization() {
        let windowId = WindowId(appPID: 123, registry: mockRegistry)
        let controller = WindowController(windowId: windowId, axHelper: mockHelper)

        #expect(controller.windowId.appPID == 123)
    }

    // MARK: - Raise Tests

    @Test("raise() calls axHelper when window valid")
    func testRaiseValidWindow() throws {
        let windowId = WindowId(appPID: 123, registry: mockRegistry)
        mockRegistry.registerElement(mockElement, for: windowId.id)
        let controller = WindowController(windowId: windowId, axHelper: mockHelper)

        controller.raise()

        #expect(mockHelper.raiseCallCount == 1)
    }

    @Test("raise() handles invalid window gracefully")
    func testRaiseInvalidWindow() {
        // Create WindowId with no registered element
        let windowId = WindowId(appPID: 123, registry: mockRegistry)
        let controller = WindowController(windowId: windowId, axHelper: mockHelper)

        // Should not crash
        controller.raise()

        // axHelper.raise should not be called
        #expect(mockHelper.raiseCallCount == 0)
    }

    // MARK: - Reposition Tests

    @Test("reposition() delegates to axHelper with correct rect")
    func testRepositionWindow() throws {
        let windowId = WindowId(appPID: 123, registry: mockRegistry)
        mockRegistry.registerElement(mockElement, for: windowId.id)
        let controller = WindowController(windowId: windowId, axHelper: mockHelper)

        let rect = CGRect(x: 100, y: 200, width: 800, height: 600)
        try controller.reposition(to: rect)

        #expect(mockHelper.resizeCallCount == 1)
        #expect(mockHelper.lastResizeSize == rect.size)
        #expect(mockHelper.moveCallCount == 1)
        #expect(mockHelper.lastMovePosition == rect.origin)
    }

    @Test("reposition() throws when window invalid")
    func testRepositionInvalidWindow() throws {
        let windowId = WindowId(appPID: 123, registry: mockRegistry)
        let controller = WindowController(windowId: windowId, axHelper: mockHelper)

        var threwError = false
        do {
            let rect = CGRect(x: 100, y: 200, width: 800, height: 600)
            try controller.reposition(to: rect)
        } catch WindowError.invalidWindow {
            threwError = true
        }

        #expect(threwError)
    }

    @Test("reposition() propagates axHelper resize errors")
    func testRepositionPropagatesResizeError() throws {
        let windowId = WindowId(appPID: 123, registry: mockRegistry)
        mockRegistry.registerElement(mockElement, for: windowId.id)
        mockHelper.resizeError = WindowError.resizeFailed(.cannotComplete)
        let controller = WindowController(windowId: windowId, axHelper: mockHelper)

        var caughtError = false
        do {
            let rect = CGRect(x: 100, y: 200, width: 800, height: 600)
            try controller.reposition(to: rect)
        } catch WindowError.resizeFailed {
            caughtError = true
        }

        #expect(caughtError)
    }

    @Test("reposition() propagates axHelper move errors")
    func testRepositionPropagatesMoveError() throws {
        let windowId = WindowId(appPID: 123, registry: mockRegistry)
        mockRegistry.registerElement(mockElement, for: windowId.id)
        mockHelper.moveError = WindowError.moveFailed(.cannotComplete)
        let controller = WindowController(windowId: windowId, axHelper: mockHelper)

        var caughtError = false
        do {
            let rect = CGRect(x: 100, y: 200, width: 800, height: 600)
            try controller.reposition(to: rect)
        } catch WindowError.moveFailed {
            caughtError = true
        }

        #expect(caughtError)
    }

    // MARK: - WindowId Integration Tests

    @Test("Multiple operations with same WindowId share registry")
    func testWindowIdIntegration() throws {
        let windowId = WindowId(appPID: 123, registry: mockRegistry)
        let controller1 = WindowController(windowId: windowId, axHelper: mockHelper)
        let controller2 = WindowController(windowId: windowId, axHelper: mockHelper)

        // Register element after controller creation
        mockRegistry.registerElement(mockElement, for: windowId.id)

        // Both controllers should access same element
        try controller1.reposition(to: CGRect(x: 100, y: 200, width: 500, height: 400))
        try controller2.reposition(to: CGRect(x: 0, y: 0, width: 800, height: 600))

        #expect(mockHelper.moveCallCount == 2)
        #expect(mockHelper.resizeCallCount == 2)
    }

    @Test("Operations fail gracefully when WindowId becomes invalid")
    func testWindowIdInvalidation() throws {
        let windowId = WindowId(appPID: 123, registry: mockRegistry)
        mockRegistry.registerElement(mockElement, for: windowId.id)
        let controller = WindowController(windowId: windowId, axHelper: mockHelper)

        // First operation succeeds
        try controller.reposition(to: CGRect(x: 100, y: 200, width: 500, height: 400))
        #expect(mockHelper.moveCallCount == 1)
        #expect(mockHelper.resizeCallCount == 1)

        // Invalidate the window (simulate close)
        mockRegistry.invalidateWindow(for: windowId.id)

        // Second operation fails gracefully
        var threwError = false
        do {
            try controller.reposition(to: CGRect(x: 200, y: 300, width: 600, height: 500))
        } catch WindowError.invalidWindow {
            threwError = true
        }

        #expect(threwError)
    }

    // MARK: - Protocol Conformance Tests

    @Test("Implements WindowControllerProtocol")
    func testProtocolConformance() {
        let windowId = WindowId(appPID: 123, registry: mockRegistry)
        let controller = WindowController(windowId: windowId, axHelper: mockHelper)

        // Should be assignable to protocol type
        let _: WindowControllerProtocol = controller
    }

    // MARK: - Sequence Tests

    @Test("Sequences multiple operations correctly")
    func testSequenceOperations() throws {
        let windowId = WindowId(appPID: 123, registry: mockRegistry)
        mockRegistry.registerElement(mockElement, for: windowId.id)
        let controller = WindowController(windowId: windowId, axHelper: mockHelper)

        try controller.reposition(to: CGRect(x: 0, y: 0, width: 1920, height: 1080))
        controller.raise()

        #expect(mockHelper.moveCallCount == 1)
        #expect(mockHelper.resizeCallCount == 1)
        #expect(mockHelper.raiseCallCount == 1)
    }

    @Test("Can perform same operation multiple times")
    func testRepeatedOperations() throws {
        let windowId = WindowId(appPID: 123, registry: mockRegistry)
        mockRegistry.registerElement(mockElement, for: windowId.id)
        let controller = WindowController(windowId: windowId, axHelper: mockHelper)

        try controller.reposition(to: CGRect(x: 100, y: 100, width: 400, height: 300))
        try controller.reposition(to: CGRect(x: 200, y: 200, width: 500, height: 400))
        try controller.reposition(to: CGRect(x: 300, y: 300, width: 600, height: 500))

        #expect(mockHelper.moveCallCount == 3)
        #expect(mockHelper.resizeCallCount == 3)
        #expect(mockHelper.lastMovePosition == CGPoint(x: 300, y: 300))
    }
}
