// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Jimmy Ma

import Cocoa
import Testing
@testable import Tiled

// MARK: - Window Deduplication Tests

/// Integration tests for window deduplication.
///
/// Verifies the registry correctly identifies when the same window is reported through
/// different AXUIElement references and maintains a single WindowId.
///
/// Requires real AXUIElement instances from the macOS Accessibility API.
@Suite("Window Deduplication")
struct WindowIdDeduplicationTests {
    var registry: DefaultWindowRegistry!
    var axHelper: DefaultAccessibilityAPIHelper!

    init() {
        axHelper = DefaultAccessibilityAPIHelper()
        registry = DefaultWindowRegistry(axHelper: axHelper)
    }

    @Test @MainActor
    func sameElementReturnsIdenticalWindowId() throws {
        // Get a real application element
        let pid = ProcessInfo.processInfo.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)

        // Register the same element twice
        let windowId1 = registry.getOrRegister(element: appElement)
        let windowId2 = registry.getOrRegister(element: appElement)

        // Should get the same WindowId object (identity, not just equality)
        #expect(windowId1 === windowId2)
    }

    @Test @MainActor
    func multipleSameElementRegistrationsCreateNoduplicates() throws {
        let pid = ProcessInfo.processInfo.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)

        // Register multiple times
        let windowId1 = registry.getOrRegister(element: appElement)
        let windowId2 = registry.getOrRegister(element: appElement)
        let windowId3 = registry.getOrRegister(element: appElement)

        // All should be identical
        #expect(windowId1 === windowId2)
        #expect(windowId2 === windowId3)

        // Registry should only track one WindowId
        let allWindowIds = registry.getAllWindowIds()
        let matchingIds = allWindowIds.filter { $0.appPID == pid }
        #expect(matchingIds.count == 1)
    }

    @Test @MainActor
    func elementLookupReturnsRegisteredWindowId() throws {
        let pid = ProcessInfo.processInfo.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)

        // Register the element
        let registered = registry.getOrRegister(element: appElement)

        // Look it up by element
        let found = registry.getWindowId(for: appElement)

        // Should get the same WindowId
        #expect(found === registered)
    }

    @Test @MainActor
    func windowIdLookupReturnsCurrentElement() throws {
        let pid = ProcessInfo.processInfo.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)

        // Register the element
        guard let windowId = registry.getOrRegister(element: appElement) else {
            Issue.record("Failed to register element")
            return
        }

        // Get the element back by WindowId
        let retrieved = registry.getElement(for: windowId)

        // Should get back an element (may not be identical due to Accessibility API creating new refs)
        #expect(retrieved != nil)
    }

    @Test @MainActor
    func basicRegistration() throws {
        // Get a real application to test with
        let pid = ProcessInfo.processInfo.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)

        let windowId = registry.getOrRegister(element: appElement)
        #expect(windowId != nil)
        #expect(windowId?.appPID == pid)
    }

    @Test @MainActor
    func registrationWithCGWindowID() throws {
        let pid = ProcessInfo.processInfo.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)

        let windowId = registry.getOrRegister(element: appElement)
        #expect(windowId != nil)

        // If we got a cgWindowID, verify it's set
        if let cgWindowID = windowId?.cgWindowID {
            #expect(cgWindowID != 0)
        }
    }

    @Test @MainActor
    func registrationCreatesStableReference() throws {
        let pid = ProcessInfo.processInfo.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)

        let windowId1 = registry.getOrRegister(element: appElement)
        let windowId2 = registry.getOrRegister(element: appElement)

        // Both should be the same stable reference
        #expect(windowId1?.id == windowId2?.id)
    }
}
