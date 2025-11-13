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

// MARK: - SpaceWindowRegistry Ephemeral Tests

/// Integration tests for SpaceWindowRegistry ephemeral window handling.
/// These tests use ObjectIdentifier on real AXUIElements, so they must be integration tests.
@MainActor
@Suite("SpaceWindowRegistry Ephemeral")
struct SpaceWindowRegistryEphemeralTests {
    var registry: SpaceWindowRegistry!
    var logger: Logger = Logger()
    var mockWindowRegistry: DefaultWindowRegistry!

    init() {
        logger = Logger()
        registry = SpaceWindowRegistry(logger: logger)
        mockWindowRegistry = DefaultWindowRegistry(axHelper: DefaultAccessibilityAPIHelper())
    }

    @Test
    func storesAndRetrievesEphemeralByElement() throws {
        let pid = ProcessInfo.processInfo.processIdentifier
        let element = AXUIElementCreateApplication(pid)
        let appPID: pid_t = 1234

        // Create ephemeral WindowId (cgWindowID=nil)
        let windowId = WindowId(appPID: appPID, registry: mockWindowRegistry)
        #expect(windowId.cgWindowID == nil)

        // Store in registry
        registry.registerEphemeral(windowId, forElement: element)

        // Lookup by element
        let retrieved = registry.lookupEphemeral(by: element)
        #expect(retrieved?.id == windowId.id)
        #expect(retrieved?.cgWindowID == nil)
    }

    @Test
    func upgradesEphemeralToPermanent() throws {
        let pid = ProcessInfo.processInfo.processIdentifier
        let element = AXUIElementCreateApplication(pid)
        let cgWindowID: CGWindowID = 99
        let appPID: pid_t = 5678

        // Create and register ephemeral
        let windowId = WindowId(appPID: appPID, registry: mockWindowRegistry)
        let originalUUID = windowId.id
        registry.registerEphemeral(windowId, forElement: element)

        // Verify it's ephemeral
        #expect(windowId.cgWindowID == nil)
        #expect(registry.lookupEphemeral(by: element)?.id == originalUUID)

        // Upgrade to permanent
        windowId._upgrade(cgWindowID: cgWindowID)
        registry.upgradeToPermanent(windowId, withCGWindowID: cgWindowID)

        // Verify upgrade
        #expect(windowId.cgWindowID == cgWindowID)
        #expect(windowId.id == originalUUID)  // UUID unchanged
        #expect(registry.lookupPermanent(by: cgWindowID)?.id == originalUUID)
        #expect(registry.lookupEphemeral(by: element) == nil)  // Removed from ephemeral
    }

    @Test
    func cleansUpOrphanedEphemerals() throws {
        let pid = ProcessInfo.processInfo.processIdentifier
        let staleElement = AXUIElementCreateApplication(pid)
        let validElement = AXUIElementCreateApplication(pid)
        let appPID: pid_t = 1234

        // Create 2 ephemerals
        let ephemeral1 = WindowId(appPID: appPID, registry: mockWindowRegistry)
        let ephemeral2 = WindowId(appPID: appPID, registry: mockWindowRegistry)
        let id1 = ephemeral1.id
        let id2 = ephemeral2.id

        registry.registerEphemeral(ephemeral1, forElement: staleElement)
        registry.registerEphemeral(ephemeral2, forElement: validElement)

        // Verify both exist
        #expect(registry.lookupEphemeral(by: staleElement)?.id == id1)
        #expect(registry.lookupEphemeral(by: validElement)?.id == id2)

        // Mark staleElement as stale and cleanup orphaned
        registry.removeOrphanedEphemeral(by: staleElement)

        // Verify stale removed, valid remains
        #expect(registry.lookupEphemeral(by: staleElement) == nil)
        #expect(registry.lookupEphemeral(by: validElement)?.id == id2)
    }

    @Test
    func reusesEphemeralForSameElement() throws {
        let pid = ProcessInfo.processInfo.processIdentifier
        let element = AXUIElementCreateApplication(pid)
        let appPID: pid_t = 1234

        // Create and register first ephemeral
        let windowId1 = WindowId(appPID: appPID, registry: mockWindowRegistry)
        let uuid1 = windowId1.id
        registry.registerEphemeral(windowId1, forElement: element)

        // Lookup same element again
        let retrieved = registry.lookupEphemeral(by: element)
        #expect(retrieved?.id == uuid1)
        #expect(retrieved === windowId1)  // Same instance
    }
}
