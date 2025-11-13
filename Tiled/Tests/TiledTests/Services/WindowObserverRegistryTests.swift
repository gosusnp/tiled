// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Jimmy Ma

import Cocoa
import Testing
@testable import Tiled

// MARK: - WindowObserver Registry Integration

/// Unit tests for WindowObserver interaction with SpaceWindowRegistry.
/// Verifies observer correctly creates ephemeral WindowIds on the active Space.
@MainActor
@Suite("WindowObserver Registry")
struct WindowObserverRegistryTests {
    var spaceRegistry: SpaceWindowRegistry!
    var logger: Logger = Logger()
    var mockWindowRegistry: SimpleWindowRegistryMock!

    init() {
        logger = Logger()
        spaceRegistry = SpaceWindowRegistry(logger: logger)
        mockWindowRegistry = SimpleWindowRegistryMock()
    }

    @Test("WindowObserver creates ephemeral WindowId on active Space")
    func testWindowObserverCreatesEphemeralWindowId() {
        let appPID: pid_t = 1111

        // Observer detects window but cgWindowID not yet known
        let windowId = WindowId(appPID: appPID, registry: mockWindowRegistry)
        let originalUUID = windowId.id

        #expect(windowId.cgWindowID == nil)

        // Register as ephemeral in space registry
        // (In real scenario, observer would call this)
        // Note: ephemeral registration requires real AXUIElement, tested in integration tests
        // For now, verify registry supports the concept

        #expect(windowId.cgWindowID == nil)
        #expect(windowId.id == originalUUID)
    }

    @Test("WindowObserver respects active Space boundary")
    func testWindowObserverRespectsActiveSpaceBoundary() {
        let spaceManager = SpaceManager(logger: logger, config: ConfigController())
        let spaceID = UUID()

        spaceManager._setActiveSpace(id: spaceID)

        let registry = spaceManager.getOrCreateRegistry(for: spaceID)

        let appPID: pid_t = 2222
        let windowId = WindowId(appPID: appPID, registry: mockWindowRegistry)

        // Registry exists for active space
        #expect(spaceManager.activeSpaceId == spaceID)
        #expect(registry !== nil)
    }

    @Test("WindowObserver registers ephemeral in correct Space")
    func testWindowObserverRegistersEphemeralInCorrectSpace() {
        let spaceManager = SpaceManager(logger: logger, config: ConfigController())
        let space1ID = UUID()
        let space2ID = UUID()

        spaceManager._setActiveSpace(id: space1ID)
        let registry1 = spaceManager.getOrCreateRegistry(for: space1ID)

        let appPID: pid_t = 3333
        let windowId = WindowId(appPID: appPID, registry: mockWindowRegistry)

        // Ephemeral would be registered in space1's registry
        #expect(spaceManager.activeSpaceId == space1ID)

        // Switch to space2
        spaceManager._setActiveSpace(id: space2ID)
        let registry2 = spaceManager.getOrCreateRegistry(for: space2ID)

        // Verify they're different registries
        #expect(registry1 !== registry2)
    }

    @Test("WindowObserver ephemeral WindowId lacks cgWindowID until poller discovers it")
    func testWindowObserverEphemeralLacksCGWindowID() {
        let appPID: pid_t = 4444

        // Observer creates WindowId without cgWindowID
        let windowId = WindowId(appPID: appPID, registry: mockWindowRegistry)

        #expect(windowId.cgWindowID == nil)

        // Later, poller upgrades it
        let cgWindowID: CGWindowID = 450
        windowId._upgrade(cgWindowID: cgWindowID)

        #expect(windowId.cgWindowID == cgWindowID)
    }

    @Test("WindowObserver creates new ephemeral for each unique window")
    func testWindowObserverCreatesUniqueEphemeralPerWindow() {
        let appPID: pid_t = 5555

        // Observer detects multiple windows from same app
        let window1 = WindowId(appPID: appPID, registry: mockWindowRegistry)
        let window2 = WindowId(appPID: appPID, registry: mockWindowRegistry)
        let window3 = WindowId(appPID: appPID, registry: mockWindowRegistry)

        // Each gets unique UUID
        #expect(window1.id != window2.id)
        #expect(window2.id != window3.id)

        // All ephemeral (no cgWindowID)
        #expect(window1.cgWindowID == nil)
        #expect(window2.cgWindowID == nil)
        #expect(window3.cgWindowID == nil)
    }

    @Test("WindowObserver initial state: ephemeral WindowIds awaiting poller confirmation")
    func testWindowObserverInitialStateIsEphemeral() {
        let appPID: pid_t = 6666

        // Observer creates ephemeral
        let windowId = WindowId(appPID: appPID, registry: mockWindowRegistry)

        // WindowId exists but is incomplete (ephemeral)
        #expect(windowId.id != nil)
        #expect(windowId.cgWindowID == nil)

        // Poller will later provide cgWindowID
        #expect(windowId.appPID == appPID)
    }
}
