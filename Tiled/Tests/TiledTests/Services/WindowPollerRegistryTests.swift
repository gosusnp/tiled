// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Jimmy Ma

import Cocoa
import Testing
@testable import Tiled

// MARK: - WindowPoller Registry Integration

/// Unit tests for WindowPoller interaction with SpaceWindowRegistry.
/// Verifies poller correctly creates, upgrades, and manages WindowIds.
@MainActor
@Suite("WindowPoller Registry")
struct WindowPollerRegistryTests {
    var spaceRegistry: SpaceWindowRegistry!
    var logger: Logger = Logger()
    var mockWindowRegistry: SimpleWindowRegistryMock!

    init() {
        logger = Logger()
        spaceRegistry = SpaceWindowRegistry(logger: logger)
        mockWindowRegistry = SimpleWindowRegistryMock()
    }

    @Test("WindowPoller creates permanent WindowIds with cgWindowID")
    func testWindowPollerCreatesPermanentWindowIds() {
        let appPID: pid_t = 1234
        let cgWindowID1: CGWindowID = 101
        let cgWindowID2: CGWindowID = 102

        let windowId1 = WindowId(appPID: appPID, registry: mockWindowRegistry)
        windowId1._upgrade(cgWindowID: cgWindowID1)

        let windowId2 = WindowId(appPID: appPID, registry: mockWindowRegistry)
        windowId2._upgrade(cgWindowID: cgWindowID2)

        spaceRegistry.register(windowId1, withCGWindowID: cgWindowID1)
        spaceRegistry.register(windowId2, withCGWindowID: cgWindowID2)

        #expect(spaceRegistry.lookupPermanent(by: cgWindowID1)?.cgWindowID == cgWindowID1)
        #expect(spaceRegistry.lookupPermanent(by: cgWindowID2)?.cgWindowID == cgWindowID2)

        let allPermanent = spaceRegistry.getAllPermanentWindowIds()
        #expect(allPermanent.count == 2)
    }

    @Test("WindowPoller upgrades ephemeral WindowId to permanent when cgWindowID discovered")
    func testWindowPollerUpgradesEphemeralToPermanent() {
        let appPID: pid_t = 5678
        let cgWindowID: CGWindowID = 200

        let windowId = WindowId(appPID: appPID, registry: mockWindowRegistry)
        let originalUUID = windowId.id

        #expect(windowId.cgWindowID == nil)

        windowId._upgrade(cgWindowID: cgWindowID)
        spaceRegistry.register(windowId, withCGWindowID: cgWindowID)

        #expect(windowId.cgWindowID == cgWindowID)
        #expect(windowId.id == originalUUID)
        #expect(spaceRegistry.lookupPermanent(by: cgWindowID)?.id == originalUUID)
    }

    @Test("WindowPoller removes orphaned WindowIds not found in CGWindowList")
    func testWindowPollerRemovesOrphanedWindows() {
        let appPID: pid_t = 9999
        let cgWindowID: CGWindowID = 999

        let windowId = WindowId(appPID: appPID, registry: mockWindowRegistry)
        windowId._upgrade(cgWindowID: cgWindowID)
        spaceRegistry.register(windowId, withCGWindowID: cgWindowID)

        #expect(spaceRegistry.getAllWindowIds().count == 1)

        spaceRegistry.unregister(by: cgWindowID)

        #expect(spaceRegistry.getAllWindowIds().count == 0)
    }

    @Test("WindowPoller registers windows in active Space's registry")
    func testWindowPollerUsesActiveSpaceRegistry() {
        let spaceManager = SpaceManager(logger: logger, config: ConfigController())
        let spaceID = UUID()

        spaceManager._setActiveSpace(id: spaceID)

        let registry = spaceManager.getOrCreateRegistry(for: spaceID)

        let appPID: pid_t = 4321
        let cgWindowID: CGWindowID = 500

        let windowId = WindowId(appPID: appPID, registry: mockWindowRegistry)
        windowId._upgrade(cgWindowID: cgWindowID)
        registry.register(windowId, withCGWindowID: cgWindowID)

        #expect(registry.lookupPermanent(by: cgWindowID) != nil)
        #expect(registry.getAllPermanentWindowIds().count == 1)
    }

    @Test("WindowPoller tracks multiple windows from same application independently")
    func testWindowPollerMultipleWindowsSameApp() {
        let appPID: pid_t = 7777
        let cgID1: CGWindowID = 301
        let cgID2: CGWindowID = 302
        let cgID3: CGWindowID = 303

        let w1 = WindowId(appPID: appPID, registry: mockWindowRegistry)
        let w2 = WindowId(appPID: appPID, registry: mockWindowRegistry)
        let w3 = WindowId(appPID: appPID, registry: mockWindowRegistry)

        w1._upgrade(cgWindowID: cgID1)
        w2._upgrade(cgWindowID: cgID2)
        w3._upgrade(cgWindowID: cgID3)

        spaceRegistry.register(w1, withCGWindowID: cgID1)
        spaceRegistry.register(w2, withCGWindowID: cgID2)
        spaceRegistry.register(w3, withCGWindowID: cgID3)

        #expect(spaceRegistry.lookupPermanent(by: cgID1)?.id == w1.id)
        #expect(spaceRegistry.lookupPermanent(by: cgID2)?.id == w2.id)
        #expect(spaceRegistry.lookupPermanent(by: cgID3)?.id == w3.id)

        #expect(w1.id != w2.id)
        #expect(w2.id != w3.id)

        let permanent = spaceRegistry.getAllPermanentWindowIds()
        #expect(permanent.count == 3)
    }

    @Test("WindowPoller detects window closure and removes from registry")
    func testWindowPollerDetectsWindowClosure() {
        let appPID: pid_t = 6666
        let cgWindowID: CGWindowID = 400

        let windowId = WindowId(appPID: appPID, registry: mockWindowRegistry)
        windowId._upgrade(cgWindowID: cgWindowID)
        spaceRegistry.register(windowId, withCGWindowID: cgWindowID)

        #expect(spaceRegistry.lookupPermanent(by: cgWindowID) != nil)

        spaceRegistry.unregister(by: cgWindowID)

        #expect(spaceRegistry.lookupPermanent(by: cgWindowID) == nil)
        #expect(spaceRegistry.getAllPermanentWindowIds().count == 0)
    }
}
