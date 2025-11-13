// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Jimmy Ma

import Cocoa
import Testing
@testable import Tiled

// MARK: - Mock AXUIElement

/// Safe mock AXUIElement that can be used with ObjectIdentifier.
/// Real AXUIElement is an Objective-C opaque type. We create stable
/// pointer values that won't cause memory corruption.
@MainActor
class MockAXUIElementForRegistry {
    let id: UUID = UUID()

    // Static counter for unique pointer values
    private static var _ptrCounter: UInt = 0x2000
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
func mockElementRefForRegistry(_ mock: MockAXUIElementForRegistry) -> AXUIElement {
    return mock.asAXElement()
}

// MARK: - Mock Registry for WindowId

/// Simple mock registry for WindowId initialization in tests
/// (Different from the full WindowRegistry protocol mock in Mocks/)
class SimpleWindowRegistryMock: WindowRegistry {
    func getOrRegister(element: AXUIElement) -> WindowId? {
        return nil
    }

    func getWindowId(for element: AXUIElement) -> WindowId? {
        return nil
    }

    func getElement(for windowId: WindowId) -> AXUIElement? {
        return nil
    }

    func updateElement(_ element: AXUIElement, for windowId: WindowId) {
    }

    func unregister(_ windowId: WindowId) {
    }

    func getAllWindowIds() -> [WindowId] {
        return []
    }

    func registerObserver(_ observer: WindowIdObserver, for windowId: WindowId) {
    }

    func unregisterObserver(_ observer: WindowIdObserver, for windowId: WindowId) {
    }

    func _notifyWindowIdDestroyed(_ windowId: WindowId) {
    }
}

// MARK: - SpaceWindowRegistry Tests

@MainActor
@Suite("SpaceWindowRegistry")
struct SpaceWindowRegistryTests {
    var registry: SpaceWindowRegistry!
    var logger: Logger = Logger()
    var mockWindowRegistry: SimpleWindowRegistryMock!

    init() {
        logger = Logger()
        registry = SpaceWindowRegistry(logger: logger)
        mockWindowRegistry = SimpleWindowRegistryMock()
    }

    // MARK: - Test 1: Store Permanent Window by cgWindowID

    @Test("Store and retrieve permanent window by cgWindowID")
    func testStoresWindowById() {
        let cgWindowID: CGWindowID = 42
        let appPID: pid_t = 1234

        // Create permanent WindowId
        let windowId = WindowId(appPID: appPID, registry: mockWindowRegistry)
        windowId._upgrade(cgWindowID: cgWindowID)

        // Store in registry
        registry.register(windowId, withCGWindowID: cgWindowID)

        // Lookup by cgWindowID
        let retrieved = registry.lookupPermanent(by: cgWindowID)
        #expect(retrieved?.id == windowId.id)
        #expect(retrieved?.cgWindowID == cgWindowID)
    }

    // MARK: - Test 2: Multiple Permanent Windows Same PID

    @Test("Support multiple permanent windows with same PID")
    func testMultiplePermanentWindowsSamePID() {
        let appPID: pid_t = 1234
        let cgID1: CGWindowID = 101
        let cgID2: CGWindowID = 102
        let cgID3: CGWindowID = 103

        // Create 3 permanent windows for same app
        let w1 = WindowId(appPID: appPID, registry: mockWindowRegistry)
        let w2 = WindowId(appPID: appPID, registry: mockWindowRegistry)
        let w3 = WindowId(appPID: appPID, registry: mockWindowRegistry)

        w1._upgrade(cgWindowID: cgID1)
        w2._upgrade(cgWindowID: cgID2)
        w3._upgrade(cgWindowID: cgID3)

        registry.register(w1, withCGWindowID: cgID1)
        registry.register(w2, withCGWindowID: cgID2)
        registry.register(w3, withCGWindowID: cgID3)

        // Verify all 3 can be looked up independently
        #expect(registry.lookupPermanent(by: cgID1)?.id == w1.id)
        #expect(registry.lookupPermanent(by: cgID2)?.id == w2.id)
        #expect(registry.lookupPermanent(by: cgID3)?.id == w3.id)
        #expect(registry.lookupPermanent(by: cgID1)?.id != w2.id)
    }

    // MARK: - Test 3: Remove Closed Window

    @Test("Remove closed window (cgWindowID no longer in system)")
    func testRemoveClosedWindow() {
        let cgWindowID: CGWindowID = 42
        let appPID: pid_t = 1234

        let windowId = WindowId(appPID: appPID, registry: mockWindowRegistry)
        windowId._upgrade(cgWindowID: cgWindowID)
        registry.register(windowId, withCGWindowID: cgWindowID)

        // Verify it's registered
        #expect(registry.lookupPermanent(by: cgWindowID) != nil)

        // Remove (window closed)
        registry.unregister(by: cgWindowID)

        // Verify removed
        #expect(registry.lookupPermanent(by: cgWindowID) == nil)
    }
}

// MARK: - SpaceManager Per-Space Registry Tests

@MainActor
@Suite("SpaceManager Per-Space Registry")
struct SpaceManagerRegistryTests {
    var spaceManager: SpaceManager!
    var logger: Logger = Logger()
    var mockHelper: MockAccessibilityAPIHelper!

    init() {
        mockHelper = MockAccessibilityAPIHelper()
        spaceManager = SpaceManager(logger: logger, config: ConfigController(), axHelper: mockHelper)
    }

    // MARK: - Test 1: Creates Different Registry Per Space

    @Test("Create different registry instances for different spaces")
    func testCreatesPerSpaceRegistry() {
        let spaceID1 = UUID()
        let spaceID2 = UUID()

        // Get registries for different spaces
        let registry1 = spaceManager.getOrCreateRegistry(for: spaceID1)
        let registry2 = spaceManager.getOrCreateRegistry(for: spaceID2)

        // Verify they're different instances
        #expect(registry1 !== registry2)
    }

    // MARK: - Test 2: Reuses Registry for Same Space

    @Test("Reuse registry instance for same space")
    func testReusesRegistryForSameSpace() {
        let spaceID = UUID()

        let registry1 = spaceManager.getOrCreateRegistry(for: spaceID)
        let registry2 = spaceManager.getOrCreateRegistry(for: spaceID)

        // Verify same instance returned
        #expect(registry1 === registry2)
    }

    // MARK: - Test 3: Active Registry Returns Correct Space

    @Test("Active registry returns correct space's registry")
    func testActiveRegistryReturnsCorrectSpace() {
        let spaceID = UUID()
        spaceManager._setActiveSpace(id: spaceID)  // Simulate space change

        let registry = spaceManager.getOrCreateRegistry(for: spaceID)
        let activeRegistry = spaceManager.activeWindowRegistry

        // Verify active registry is the correct one
        #expect(activeRegistry === registry)
    }
}
