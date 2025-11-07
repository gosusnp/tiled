// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Jimmy Ma

import Cocoa
import Testing
@testable import Tiled

// MARK: - Mock AccessibilityAPIHelper

class MockAccessibilityAPIHelper: AccessibilityAPIHelper {
    var mockAppPID: pid_t? = 1234
    var mockCGWindowID: CGWindowID? = nil

    func getAppPID(_ element: AXUIElement) -> pid_t? {
        return mockAppPID
    }

    func getWindowID(_ element: AXUIElement) -> CGWindowID? {
        return mockCGWindowID
    }

    func isElementValid(_ element: AXUIElement) -> Bool {
        // For tests, all elements are considered valid by default
        return true
    }
}

// MARK: - Mock AXUIElement

/// Safe mock AXUIElement that can be used with ObjectIdentifier.
/// Real AXUIElement is an Objective-C opaque type. We create stable
/// pointer values that won't cause memory corruption.
@MainActor
class MockAXUIElement {
    let id: UUID = UUID()

    // Static counter for unique pointer values
    private static var _ptrCounter: UInt = 0x1000
    private let _ptrValue: UInt

    init() {
        _ptrValue = Self._ptrCounter
        Self._ptrCounter += 1
    }

    /// Return this mock as a safe-to-use AXUIElement reference
    /// We create a pointer value that's unique but never dereferenced
    func asAXElement() -> AXUIElement {
        // Create a pointer from our counter value
        // This is safe because we never dereference it - it's only used for ObjectIdentifier
        return UnsafeMutableRawPointer(bitPattern: _ptrValue)! as! AXUIElement
    }
}

/// Helper to safely create AXUIElement references from our mock
@MainActor
func mockElementRef(_ mock: MockAXUIElement) -> AXUIElement {
    return mock.asAXElement()
}

// MARK: - WindowId State Tests

@Suite("WindowId State")
struct WindowIdStateTests {
    var registry: DefaultWindowRegistry!
    var mockHelper: MockAccessibilityAPIHelper!

    init() {
        mockHelper = MockAccessibilityAPIHelper()
        registry = DefaultWindowRegistry(axHelper: mockHelper)
    }

    @Test func startsPartial() {
        let windowId = WindowId(appPID: 1234, registry: registry)
        #expect(windowId.cgWindowID == nil)
    }

    @Test func upgradeToComplete() {
        let windowId = WindowId(appPID: 1234, registry: registry)
        let originalId = windowId.id

        windowId._upgrade(cgWindowID: 5678)
        #expect(windowId.cgWindowID == 5678)
        #expect(windowId.id == originalId)
    }

    @Test func asKeyImmutable() {
        let windowId = WindowId(appPID: 1234, registry: registry)
        let key = windowId.asKey()

        windowId._upgrade(cgWindowID: 5678)

        #expect(windowId.asKey() == key)
    }
}

// MARK: - WindowRegistry Registration Tests

/// Tests for registering windows with the registry and retrieving WindowIds.
/// These tests are implemented in the TiledIntegrationTests target because they
/// require real AXUIElement instances (ObjectIdentifier crashes with mock pointers on ARM64e).
///
/// See: Tests/TiledIntegrationTests/WindowIdDeduplicationTests.swift
@Suite("WindowRegistry Registration")
struct WindowRegistryTests {
    var registry: DefaultWindowRegistry!
    var mockHelper: MockAccessibilityAPIHelper!

    init() {
        mockHelper = MockAccessibilityAPIHelper()
        registry = DefaultWindowRegistry(axHelper: mockHelper)
    }

    // Tests moved to integration tests - see WindowIdDeduplicationTests.swift
}

// MARK: - Memory Management Tests

/// Tests for WindowId lifecycle, retention by registry, and cleanup on deallocation.
/// These tests are implemented in the TiledIntegrationTests target because they
/// require real AXUIElement instances (ObjectIdentifier crashes with mock pointers on ARM64e).
///
/// See: Tests/TiledIntegrationTests/WindowIdStaleElementTests.swift
@Suite("Memory Management")
struct MemoryManagementTests {
    var registry: DefaultWindowRegistry!
    var mockHelper: MockAccessibilityAPIHelper!

    init() {
        mockHelper = MockAccessibilityAPIHelper()
        registry = DefaultWindowRegistry(axHelper: mockHelper)
    }

    // Tests moved to integration tests - see WindowIdStaleElementTests.swift
}

// MARK: - Integration Tests

/// Tests requiring real AXUIElement instances from the macOS Accessibility API.
///
/// See: Tests/TiledIntegrationTests/WindowIdDeduplicationTests.swift
/// See: Tests/TiledIntegrationTests/WindowIdStaleElementTests.swift
