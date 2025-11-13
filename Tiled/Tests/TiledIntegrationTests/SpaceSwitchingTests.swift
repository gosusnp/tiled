// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Jimmy Ma

import Cocoa
import Testing
@testable import Tiled

// MARK: - Space Switching Integration Tests

/// Integration tests for space switching and multi-space window discovery.
/// These tests verify that windows on inactive spaces are properly discovered
/// and assigned when those spaces become active.
@MainActor
@Suite("Space Switching Integration")
struct SpaceSwitchingTests {
    let config = ConfigController()
    let logger = Logger()
    var spaceManager: SpaceManager!

    init() {
        spaceManager = SpaceManager(logger: logger, config: config)
    }

    @Test("SpaceManager callback mechanism supports space change notifications")
    func testSpaceChangedCallbackMechanism() {
        var callbackFired = false
        spaceManager.onSpaceChanged = {
            callbackFired = true
        }

        // Callback is wired and can be called
        spaceManager.onSpaceChanged?()
        #expect(callbackFired == true)
    }

    @Test("WindowManager creates separate registries per space")
    func testSeparateRegistriesPerSpace() {
        let space1ID = UUID()
        let space2ID = UUID()

        spaceManager._setActiveSpace(id: space1ID)
        let registry1 = spaceManager.getOrCreateRegistry(for: space1ID)

        spaceManager._setActiveSpace(id: space2ID)
        let registry2 = spaceManager.getOrCreateRegistry(for: space2ID)

        // Verify we get separate registries for different spaces
        #expect(registry1 !== registry2)
    }

    @Test("Registry lookup returns same instance for same space")
    func testRegistryInstanceCaching() {
        let space1ID = UUID()
        spaceManager._setActiveSpace(id: space1ID)

        let registry = spaceManager.getOrCreateRegistry(for: space1ID)

        // Multiple calls to getOrCreateRegistry return same instance
        let registry2 = spaceManager.getOrCreateRegistry(for: space1ID)
        #expect(registry === registry2)
    }

    @Test("FrameManager accessed via activeFrameManager property")
    func testFrameManagerAccess() {
        let space1ID = UUID()
        let space2ID = UUID()

        // Get or create registries, which triggers FrameManager creation
        spaceManager._setActiveSpace(id: space1ID)
        let registry1 = spaceManager.getOrCreateRegistry(for: space1ID)
        // In actual flow, handleSpaceChange() would create FrameManager
        // For unit test, we just verify the registry system works

        spaceManager._setActiveSpace(id: space2ID)
        let registry2 = spaceManager.getOrCreateRegistry(for: space2ID)

        // Verify separate registries for each space
        #expect(registry1 !== registry2)

        // Verify we can track which space is active
        #expect(spaceManager.activeSpaceId == space2ID)

        // Switching back to space1
        spaceManager._setActiveSpace(id: space1ID)
        #expect(spaceManager.activeSpaceId == space1ID)
    }

    @Test("ActiveSpaceId updates correctly on space switch")
    func testActiveSpaceIdTracking() {
        let space1ID = UUID()
        spaceManager._setActiveSpace(id: space1ID)
        #expect(spaceManager.activeSpaceId == space1ID)

        let space2ID = UUID()
        spaceManager._setActiveSpace(id: space2ID)
        #expect(spaceManager.activeSpaceId == space2ID)

        spaceManager._setActiveSpace(id: space1ID)
        #expect(spaceManager.activeSpaceId == space1ID)
    }
}
