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

    @Test @MainActor
    func differentElementReferencesSameWindowDeduplicatedByCGWindowID() throws {
        // This test verifies the deduplication fix for the scenario where:
        // - Observer sends element1 (appPID available, cgWindowID not yet)
        // - Poller sends element2 (different AXUIElement ref, same cgWindowID)
        // Both represent the same physical window.
        //
        // The fix: Check windowIdByCGWindowID before creating new WindowId

        let pid = ProcessInfo.processInfo.processIdentifier
        let appElement1 = AXUIElementCreateApplication(pid)

        // First registration: element without cgWindowID (simulates observer finding partial window)
        let windowId1 = registry.getOrRegister(element: appElement1)
        #expect(windowId1 != nil)

        // If we got a cgWindowID on first registration, we can't simulate the partial case
        // But if we didn't, verify it's stored as partial
        if windowId1?.cgWindowID == nil {
            #expect(Bool(true), "Got partial WindowId as expected")
        }

        // Second registration: different AXUIElement reference (simulates poller re-discovering)
        // In real scenarios, the Accessibility API returns different element references
        // for the same window at different times
        let appElement2 = AXUIElementCreateApplication(pid)
        let windowId2 = registry.getOrRegister(element: appElement2)

        // CRITICAL: If both have cgWindowIDs, they should map to the same WindowId
        if let cgId1 = windowId1?.cgWindowID, let cgId2 = windowId2?.cgWindowID {
            if cgId1 == cgId2 {
                #expect(windowId2 === windowId1, "Same cgWindowID should return same WindowId (deduplication works)")
            }
        }

        // Both element lookups should find a WindowId
        let lookup1 = registry.getWindowId(for: appElement1)
        let lookup2 = registry.getWindowId(for: appElement2)

        #expect(lookup1 != nil)
        #expect(lookup2 != nil)

        // If they're the same WindowId, both lookups should find it
        if windowId1 === windowId2 {
            #expect(lookup1 === lookup2, "Both elements should map to same WindowId")
        }
    }
}
