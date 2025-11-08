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

    func move(_ element: AXUIElement, to: CGPoint) throws {
    }

    func raise(_ element: AXUIElement) {
    }

    func resize(_ element: AXUIElement, size: CGSize) throws {
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

    @Test func windowIdIsHashable() {
        let windowId = WindowId(appPID: 1234, registry: registry)

        // Should be able to use as dictionary key
        var dict: [WindowId: String] = [:]
        dict[windowId] = "test"

        #expect(dict[windowId] == "test")
    }

    @Test func identicalWindowIdsHaveSameHash() {
        let windowId1 = WindowId(appPID: 1234, registry: registry)
        let windowId2 = WindowId(appPID: 5678, registry: registry)

        // Different instances should have different IDs
        #expect(windowId1.id != windowId2.id)

        // Different instances should have different hashes
        var hasher1 = Hasher()
        windowId1.hash(into: &hasher1)
        let hash1 = hasher1.finalize()

        var hasher2 = Hasher()
        windowId2.hash(into: &hasher2)
        let hash2 = hasher2.finalize()

        #expect(hash1 != hash2)
    }

    @Test func windowIdEqualityBasedOnId() {
        let windowId1 = WindowId(appPID: 1234, registry: registry)
        let id1 = windowId1.id

        // Create another reference to test equality by identity
        let windowId2 = windowId1
        #expect(windowId1 == windowId2)
        #expect(windowId1.id == windowId2.id)

        // Different WindowIds should not be equal
        let windowId3 = WindowId(appPID: 1234, registry: registry)
        #expect(windowId1 != windowId3)
    }

    @Test func windowIdCanBeUsedInSet() {
        let windowId1 = WindowId(appPID: 1234, registry: registry)
        let windowId2 = WindowId(appPID: 5678, registry: registry)
        let windowId3 = windowId1  // Same instance

        var set: Set<WindowId> = [windowId1, windowId2]
        #expect(set.count == 2)

        // Adding the same instance should not increase count
        set.insert(windowId3)
        #expect(set.count == 2)

        // New instance should increase count
        let windowId4 = WindowId(appPID: 9999, registry: registry)
        set.insert(windowId4)
        #expect(set.count == 3)
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
