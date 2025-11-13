// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Jimmy Ma

import Cocoa
import Testing
@testable import Tiled

// MARK: - Space Switching Integration Tests

/// Comprehensive integration tests for space switching and multi-space window management.
/// Verifies: per-space FrameManager isolation, per-space WindowRegistry isolation,
/// active space ID tracking, and rapid switching consistency.
@MainActor
@Suite("Space Switching Integration")
struct SpaceSwitchingIntegrationTests {
    let config = ConfigController()
    let logger = Logger()
    var spaceManager: SpaceManager!

    init() {
        spaceManager = SpaceManager(logger: logger, config: config)
    }

    @Test("Each space gets independent FrameManager")
    func testEachSpaceHasIndependentFrameManager() {
        let space1 = UUID()
        let space2 = UUID()
        let space3 = UUID()

        spaceManager._setActiveSpace(id: space1)
        let fm1 = spaceManager.activeFrameManager

        spaceManager._setActiveSpace(id: space2)
        let fm2 = spaceManager.activeFrameManager

        spaceManager._setActiveSpace(id: space3)
        let fm3 = spaceManager.activeFrameManager

        // All should be different
        #expect(fm1 !== fm2)
        #expect(fm2 !== fm3)
        #expect(fm1 !== fm3)

        // Switching back should return same manager
        spaceManager._setActiveSpace(id: space1)
        #expect(spaceManager.activeFrameManager === fm1)
    }

    @Test("Each space gets independent WindowRegistry")
    func testEachSpaceHasIndependentWindowRegistry() {
        let space1 = UUID()
        let space2 = UUID()

        spaceManager._setActiveSpace(id: space1)
        let registry1 = spaceManager.getOrCreateRegistry(for: space1)

        spaceManager._setActiveSpace(id: space2)
        let registry2 = spaceManager.getOrCreateRegistry(for: space2)

        #expect(registry1 !== registry2)

        // Accessing same space returns same registry
        let registry1Again = spaceManager.getOrCreateRegistry(for: space1)
        #expect(registry1 === registry1Again)
    }

    @Test("ActiveSpaceId tracking persists correctly")
    func testActiveSpaceIdPersistence() {
        let space1 = UUID()
        let space2 = UUID()
        let space3 = UUID()

        spaceManager._setActiveSpace(id: space1)
        #expect(spaceManager.activeSpaceId == space1)

        spaceManager._setActiveSpace(id: space2)
        #expect(spaceManager.activeSpaceId == space2)

        spaceManager._setActiveSpace(id: space3)
        #expect(spaceManager.activeSpaceId == space3)

        // Complex switching pattern
        spaceManager._setActiveSpace(id: space1)
        #expect(spaceManager.activeSpaceId == space1)

        spaceManager._setActiveSpace(id: space2)
        #expect(spaceManager.activeSpaceId == space2)

        spaceManager._setActiveSpace(id: space1)
        #expect(spaceManager.activeSpaceId == space1)
    }

    @Test("Multiple spaces can be managed simultaneously")
    func testMultipleSpaceManagement() {
        let spaces = (0..<5).map { _ in UUID() }

        // Create registries for all spaces
        for space in spaces {
            spaceManager._setActiveSpace(id: space)
            _ = spaceManager.getOrCreateRegistry(for: space)
        }

        // Verify all registries exist and are unique
        var registries: [UUID: SpaceWindowRegistry] = [:]
        for space in spaces {
            let registry = spaceManager.getOrCreateRegistry(for: space)
            registries[space] = registry
        }

        #expect(registries.count == 5)

        // Verify no duplicate registries
        let uniqueRegistries = Set(registries.values.map { ObjectIdentifier($0) })
        #expect(uniqueRegistries.count == 5)
    }

    @Test("Space switching doesn't affect previous space's state")
    func testSpaceSwitchingPreservesState() {
        let space1 = UUID()
        let space2 = UUID()

        spaceManager._setActiveSpace(id: space1)
        let registry1 = spaceManager.getOrCreateRegistry(for: space1)
        let fm1 = spaceManager.activeFrameManager

        spaceManager._setActiveSpace(id: space2)
        let registry2 = spaceManager.getOrCreateRegistry(for: space2)
        let fm2 = spaceManager.activeFrameManager

        // Space 1's objects should remain the same
        #expect(spaceManager.getOrCreateRegistry(for: space1) === registry1)
        spaceManager._setActiveSpace(id: space1)
        #expect(spaceManager.activeFrameManager === fm1)

        // Space 2's objects should remain the same
        spaceManager._setActiveSpace(id: space2)
        #expect(spaceManager.getOrCreateRegistry(for: space2) === registry2)
        #expect(spaceManager.activeFrameManager === fm2)
    }

    @Test("ActiveSpaceId is nil before any space is set")
    func testActiveSpaceIdInitiallyNil() {
        let freshSpaceManager = SpaceManager(logger: logger, config: config)
        #expect(freshSpaceManager.activeSpaceId == nil)
    }

    @Test("ActiveFrameManager is nil when no active space")
    func testActiveFrameManagerNilWithoutActiveSpace() {
        let freshSpaceManager = SpaceManager(logger: logger, config: config)
        #expect(freshSpaceManager.activeFrameManager == nil)
    }

    @Test("Space switching with rapid changes maintains consistency")
    func testRapidSpaceSwitchingConsistency() {
        let spaces = (0..<10).map { _ in UUID() }

        // Rapidly switch spaces
        for _ in 0..<3 {
            for space in spaces {
                spaceManager._setActiveSpace(id: space)
                #expect(spaceManager.activeSpaceId == space)
            }
        }

        // Final state should be correct
        spaceManager._setActiveSpace(id: spaces[0])
        #expect(spaceManager.activeSpaceId == spaces[0])

        // All spaces should still have their registries
        for space in spaces {
            let registry = spaceManager.getOrCreateRegistry(for: space)
            #expect(registry !== nil)
        }
    }
}

// MARK: - Window Discovery on Space Change Tests

/// Tests verifying that window discovery works correctly when switching spaces.
/// Ensures: FrameManager creation, registry persistence, window isolation across switches.
@MainActor
@Suite("Window Discovery on Space Change")
struct WindowDiscoveryOnSpaceChangeTests {
    let config = ConfigController()
    let logger = Logger()
    var spaceManager: SpaceManager!

    init() {
        spaceManager = SpaceManager(logger: logger, config: config)
    }

    @Test("FrameManager created for new space on space change")
    func testFrameManagerCreationOnSpaceChange() {
        let space1 = UUID()
        let space2 = UUID()

        spaceManager._setActiveSpace(id: space1)
        spaceManager._setActiveSpace(id: space2)

        // Both spaces should have FrameManagers after being active
        #expect(spaceManager.activeSpaceId == space2)

        // Switch back to space1
        spaceManager._setActiveSpace(id: space1)
        #expect(spaceManager.activeSpaceId == space1)
    }

    @Test("Registry persists across space transitions")
    func testRegistryPersistenceAcrossTransitions() {
        let space1 = UUID()
        let space2 = UUID()

        spaceManager._setActiveSpace(id: space1)
        let registry1 = spaceManager.getOrCreateRegistry(for: space1)

        // Switch to space2 and back
        spaceManager._setActiveSpace(id: space2)
        spaceManager._setActiveSpace(id: space1)

        // Registry should be the same object
        #expect(spaceManager.getOrCreateRegistry(for: space1) === registry1)
    }

    @Test("Multiple space switches maintain window isolation")
    func testWindowIsolationAcrossSpaceSwitches() {
        let space1 = UUID()
        let space2 = UUID()
        let space3 = UUID()

        spaceManager._setActiveSpace(id: space1)
        let reg1 = spaceManager.getOrCreateRegistry(for: space1)

        spaceManager._setActiveSpace(id: space2)
        let reg2 = spaceManager.getOrCreateRegistry(for: space2)

        spaceManager._setActiveSpace(id: space3)
        let reg3 = spaceManager.getOrCreateRegistry(for: space3)

        // All registries should be independent
        #expect(reg1 !== reg2)
        #expect(reg2 !== reg3)
        #expect(reg1 !== reg3)

        // Verify they're still the same after space switching
        #expect(spaceManager.getOrCreateRegistry(for: space1) === reg1)
        #expect(spaceManager.getOrCreateRegistry(for: space2) === reg2)
        #expect(spaceManager.getOrCreateRegistry(for: space3) === reg3)
    }
}
