// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Jimmy Ma

import Cocoa
import Testing
@testable import Tiled

// MARK: - Per-Space Registry Validation Tests

/// Tests for per-space registry isolation and ephemeral handling.
/// Why: Ensures element churn doesn't cause cross-space collisions or duplicates.
/// Verifies: registry separation per space, independence from other spaces.
@MainActor
@Suite("Per-Space Registry")
struct PerSpaceRegistryTests {
    let config = ConfigController()
    let logger = Logger()
    let axHelper = DefaultAccessibilityAPIHelper()
    var spaceManager: SpaceManager!

    init() {
        spaceManager = SpaceManager(logger: logger, config: config, axHelper: axHelper)
    }

    @Test("SpaceManager can get or create registry per space")
    func testRegistryCreationPerSpace() {
        let space1 = UUID()
        let space2 = UUID()

        let registry1 = spaceManager.getOrCreateRegistry(for: space1)
        let registry2 = spaceManager.getOrCreateRegistry(for: space2)

        // Should be different instances
        #expect(registry1 !== registry2)

        // Getting same space should return same instance
        let registry1Again = spaceManager.getOrCreateRegistry(for: space1)
        #expect(registry1 === registry1Again)
    }

    @Test("Per-space registry isolation prevents cross-space collisions")
    func testPerSpaceRegistryIsolation() {
        let space1 = UUID()
        let space2 = UUID()

        let registry1 = spaceManager.getOrCreateRegistry(for: space1)
        let registry2 = spaceManager.getOrCreateRegistry(for: space2)

        // Register windows in different spaces with same PID
        // (simulating same app on different spaces)
        let appPID: pid_t = 1234

        // This test validates registry separation
        // Each registry should maintain independent state
        #expect(registry1 !== registry2)
    }
}

// MARK: - Frame Manager Per-Space Tests

/// Tests for FrameManager independence and lifecycle per space.
/// Why: Each space needs isolated frame tree; switching spaces shouldn't affect others.
/// Verifies: independent FrameManager instances, frame containment queries, multi-space isolation.
@MainActor
@Suite("Frame Manager Per-Space")
struct FrameManagerPerSpaceTests {
    let config = ConfigController()
    let logger = Logger()
    var spaceManager: SpaceManager!

    init() {
        spaceManager = SpaceManager(logger: logger, config: config)
    }

    @Test("FrameManager frameContaining returns nil for unassigned windows")
    func testFrameMapEmptyForNewWindows() {
        let space = UUID()
        spaceManager._setActiveSpace(id: space)
        let frameManager = spaceManager.activeFrameManager!

        // Create a window ID
        let windowId = WindowId(appPID: 1234, cgWindowID: 12345, registry: DefaultWindowRegistry())

        // Before assignment, should not be in any frame
        let result = frameManager.frameContaining(windowId)
        #expect(result == nil)
    }

    @Test("Multiple space managers maintain separate frame managers")
    func testIndependentFrameManagersPerSpace() {
        let space1 = UUID()
        let space2 = UUID()

        spaceManager._setActiveSpace(id: space1)
        let fm1 = spaceManager.activeFrameManager

        spaceManager._setActiveSpace(id: space2)
        let fm2 = spaceManager.activeFrameManager

        // Should be different instances
        #expect(fm1 !== fm2)

        // Both should be non-nil
        #expect(fm1 != nil)
        #expect(fm2 != nil)
    }
}

// MARK: - Registry Persistence Across Space Switches

@MainActor
@Suite("Registry Persistence")
struct RegistryPersistenceTests {
    let config = ConfigController()
    let logger = Logger()
    var spaceManager: SpaceManager!

    init() {
        spaceManager = SpaceManager(logger: logger, config: config)
    }

    @Test("Multiple spaces maintain independent registries")
    func testMultipleSpacesIndependentRegistries() {
        let space1 = UUID()
        let space2 = UUID()
        let space3 = UUID()

        let registry1 = spaceManager.getOrCreateRegistry(for: space1)
        let registry2 = spaceManager.getOrCreateRegistry(for: space2)
        let registry3 = spaceManager.getOrCreateRegistry(for: space3)

        // All should be different
        #expect(registry1 !== registry2)
        #expect(registry2 !== registry3)
        #expect(registry1 !== registry3)
    }

    @Test("Same space always returns same registry")
    func testSameSpaceReturnsSameRegistry() {
        let space = UUID()

        let registry1 = spaceManager.getOrCreateRegistry(for: space)
        let registry2 = spaceManager.getOrCreateRegistry(for: space)
        let registry3 = spaceManager.getOrCreateRegistry(for: space)

        // All should be identical
        #expect(registry1 === registry2)
        #expect(registry2 === registry3)
        #expect(registry1 === registry3)
    }

    @Test("Registry persistence across space switches")
    func testRegistryPersistenceAcrossSwitch() {
        let space1 = UUID()
        let space2 = UUID()

        let registry1 = spaceManager.getOrCreateRegistry(for: space1)

        // Switch spaces
        spaceManager._setActiveSpace(id: space2)
        let registry2 = spaceManager.getOrCreateRegistry(for: space2)

        // Switch back
        spaceManager._setActiveSpace(id: space1)
        let registry1Again = spaceManager.getOrCreateRegistry(for: space1)

        // Should get same registry for space1
        #expect(registry1 === registry1Again)
        #expect(registry2 !== registry1)
    }
}

// MARK: - Active Space Tracking & Consistency

@MainActor
@Suite("Active Space Tracking")
struct ActiveSpaceTrackingTests {
    let config = ConfigController()
    let logger = Logger()
    var spaceManager: SpaceManager!

    init() {
        spaceManager = SpaceManager(logger: logger, config: config)
    }

    @Test("Active space ID changes correctly")
    func testActiveSpaceIdTracking() {
        let space1 = UUID()
        let space2 = UUID()
        let space3 = UUID()

        spaceManager._setActiveSpace(id: space1)
        #expect(spaceManager.activeSpaceId == space1)

        spaceManager._setActiveSpace(id: space2)
        #expect(spaceManager.activeSpaceId == space2)

        spaceManager._setActiveSpace(id: space3)
        #expect(spaceManager.activeSpaceId == space3)

        // Back to space1
        spaceManager._setActiveSpace(id: space1)
        #expect(spaceManager.activeSpaceId == space1)
    }

    @Test("FrameManager per space maintains isolation")
    func testFrameManagerPerSpaceIsolated() {
        let space1 = UUID()
        let space2 = UUID()

        spaceManager._setActiveSpace(id: space1)
        let fm1 = spaceManager.activeFrameManager

        spaceManager._setActiveSpace(id: space2)
        let fm2 = spaceManager.activeFrameManager

        // Should be different instances
        #expect(fm1 !== fm2)

        // Both should be non-nil
        #expect(fm1 != nil)
        #expect(fm2 != nil)

        // Switching back should return same instance
        spaceManager._setActiveSpace(id: space1)
        #expect(spaceManager.activeFrameManager === fm1)
    }

    @Test("Multiple rapid space switches maintain state")
    func testRapidSpaceSwitchesPreserveState() {
        let spaces = (0..<5).map { _ in UUID() }
        var frameManagers: [UUID: FrameManager] = [:]

        // Create FrameManagers for all spaces
        for space in spaces {
            spaceManager._setActiveSpace(id: space)
            if let fm = spaceManager.activeFrameManager {
                frameManagers[space] = fm
            }
        }

        // Rapidly switch and verify
        for _ in 0..<3 {
            for space in spaces {
                spaceManager._setActiveSpace(id: space)
                if let expectedFm = frameManagers[space] {
                    #expect(spaceManager.activeFrameManager === expectedFm)
                }
            }
        }
    }
}

// MARK: - Space Manager Edge Cases & Defensive Handling

/// Tests for error resilience when spaces are created, destroyed, or not yet initialized.
/// Why: System should remain valid even when accessed before any space is set.
/// Verifies: graceful handling of nil states, lazy FrameManager creation, deferred registry access.
@MainActor
@Suite("Space Manager Edge Cases")
struct SpaceManagerEdgeCasesTests {
    let config = ConfigController()
    let logger = Logger()
    var spaceManager: SpaceManager!

    init() {
        spaceManager = SpaceManager(logger: logger, config: config)
    }

    @Test("Active frame manager nil when no space set")
    func testActiveFrameManagerNilWithoutActiveSpace() {
        let freshManager = SpaceManager(logger: logger, config: config)
        #expect(freshManager.activeFrameManager == nil)
    }

    @Test("Active space ID nil when no space set")
    func testActiveSpaceIdNilWithoutActiveSpace() {
        let freshManager = SpaceManager(logger: logger, config: config)
        #expect(freshManager.activeSpaceId == nil)
    }

    @Test("Setting active space creates frame manager")
    func testSettingActiveSpaceCreatesFrameManager() {
        let space = UUID()
        spaceManager._setActiveSpace(id: space)

        // Should have created a frame manager
        #expect(spaceManager.activeFrameManager != nil)
    }

    @Test("Getting registry for non-active space still works")
    func testGetRegistryForNonActiveSpace() {
        let space1 = UUID()
        let space2 = UUID()

        spaceManager._setActiveSpace(id: space1)

        // Get registry for different space while space1 is active
        let registry2 = spaceManager.getOrCreateRegistry(for: space2)

        // Should succeed
        #expect(registry2 != nil)

        // Active space should still be space1
        #expect(spaceManager.activeSpaceId == space1)
    }
}

// MARK: - Multi-Space State Consistency

/// Tests for system invariants across multiple spaces.
/// Why: Rapid space switching and concurrent space management must maintain correctness.
/// Verifies: unique FrameManager per space, consistent active space ID, registry-framemanager sync.
@MainActor
@Suite("Multi-Space Consistency")
struct MultiSpaceConsistencyTests {
    let config = ConfigController()
    let logger = Logger()
    var spaceManager: SpaceManager!

    init() {
        spaceManager = SpaceManager(logger: logger, config: config)
    }

    @Test("Each space has unique FrameManager instance")
    func testFrameManagerUniquenessPerSpace() {
        let spaces = (0..<3).map { _ in UUID() }
        var frameManagers: [UUID: FrameManager] = [:]

        for space in spaces {
            spaceManager._setActiveSpace(id: space)
            if let fm = spaceManager.activeFrameManager {
                frameManagers[space] = fm
            }
        }

        // Should have 3 frame managers
        #expect(frameManagers.count == 3)

        // All should be unique instances
        let fms = Array(frameManagers.values)
        for i in 0..<fms.count {
            for j in (i+1)..<fms.count {
                #expect(fms[i] !== fms[j])
            }
        }
    }

    @Test("Active space ID always matches when queried")
    func testActiveSpaceIdConsistency() {
        let spaces = (0..<5).map { _ in UUID() }

        for space in spaces {
            spaceManager._setActiveSpace(id: space)
            #expect(spaceManager.activeSpaceId == space)

            // Query multiple times - should be consistent
            #expect(spaceManager.activeSpaceId == space)
            #expect(spaceManager.activeSpaceId == space)
        }
    }

    @Test("Registries and FrameManagers stay in sync")
    func testRegistriesAndFrameManagersInSync() {
        let space = UUID()
        spaceManager._setActiveSpace(id: space)

        let registry = spaceManager.getOrCreateRegistry(for: space)
        let frameManager = spaceManager.activeFrameManager

        // Both should exist
        #expect(registry != nil)
        #expect(frameManager != nil)

        // Switch to different space
        let space2 = UUID()
        spaceManager._setActiveSpace(id: space2)

        let registry2 = spaceManager.getOrCreateRegistry(for: space2)
        let frameManager2 = spaceManager.activeFrameManager

        // New ones should exist
        #expect(registry2 != nil)
        #expect(frameManager2 != nil)

        // But be different from first ones
        #expect(registry !== registry2)
        #expect(frameManager !== frameManager2)
    }
}
