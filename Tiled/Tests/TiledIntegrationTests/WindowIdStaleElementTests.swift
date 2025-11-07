// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Jimmy Ma

import Cocoa
import Testing
@testable import Tiled

// MARK: - Element Validity Tests

/// Integration tests for element validity and observer notifications.
///
/// Requires real AXUIElement instances from the macOS Accessibility API.
@Suite("Element Validity")
struct WindowIdStaleElementTests {
    var registry: DefaultWindowRegistry!

    init() {
        registry = DefaultWindowRegistry(axHelper: DefaultAccessibilityAPIHelper())
    }

    @Test @MainActor
    func elementValidationWorks() throws {
        // Get a real application element
        let pid = ProcessInfo.processInfo.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)

        // Register the element
        guard let windowId = registry.getOrRegister(element: appElement) else {
            Issue.record("Failed to register element")
            return
        }

        // Verify we can retrieve it
        let retrieved = registry.getElement(for: windowId)
        #expect(retrieved != nil)
    }

    @Test @MainActor
    func elementUpdateNotifiesObservers() throws {
        let pid = ProcessInfo.processInfo.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)

        // Register
        guard let windowId = registry.getOrRegister(element: appElement) else {
            Issue.record("Failed to register element")
            return
        }

        // Create observer to track notifications
        let observer = TestWindowIdObserver()
        registry.registerObserver(observer, for: windowId)

        // Update with same element
        registry.updateElement(appElement, for: windowId)

        // Verify observer was notified of refresh
        #expect(observer.elementRefreshCount > 0)
    }

    @Test @MainActor
    func observerReceivesMultipleNotifications() throws {
        let pid = ProcessInfo.processInfo.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)

        guard let windowId = registry.getOrRegister(element: appElement) else {
            Issue.record("Failed to register element")
            return
        }

        // Create observer to track notifications
        let observer = TestWindowIdObserver()
        registry.registerObserver(observer, for: windowId)

        // Update element twice
        registry.updateElement(appElement, for: windowId)
        registry.updateElement(appElement, for: windowId)

        // Count should be 2 since observer received both notifications
        #expect(observer.elementRefreshCount == 2)
    }

    @Test @MainActor
    func retainedByRegistry() throws {
        let pid = ProcessInfo.processInfo.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)

        var windowId: WindowId? = registry.getOrRegister(element: appElement)
        weak var weakWindowId = windowId
        windowId = nil

        // Should still be retained by registry
        #expect(weakWindowId != nil)
    }

    @Test @MainActor
    func partialWindowIdRetainedByRegistry() throws {
        let pid = ProcessInfo.processInfo.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)

        // Create a partial WindowId (may not have cgWindowID)
        var windowId: WindowId? = registry.getOrRegister(element: appElement)
        weak var weakWindowId = windowId
        windowId = nil

        // Should still be retained by registry
        #expect(weakWindowId != nil)
    }

    @Test @MainActor
    func multipleObserversAllNotified() throws {
        let pid = ProcessInfo.processInfo.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)

        guard let windowId = registry.getOrRegister(element: appElement) else {
            Issue.record("Failed to register element")
            return
        }

        let observer1 = TestWindowIdObserver()
        let observer2 = TestWindowIdObserver()
        registry.registerObserver(observer1, for: windowId)
        registry.registerObserver(observer2, for: windowId)

        // Update element - both observers should be notified
        registry.updateElement(appElement, for: windowId)

        #expect(observer1.elementRefreshCount > 0)
        #expect(observer2.elementRefreshCount > 0)
    }

    @Test @MainActor
    func deadObserversNotNotified() throws {
        let pid = ProcessInfo.processInfo.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)

        guard let windowId = registry.getOrRegister(element: appElement) else {
            Issue.record("Failed to register element")
            return
        }

        var observer: TestWindowIdObserver? = TestWindowIdObserver()
        registry.registerObserver(observer!, for: windowId)

        // Destroy observer
        observer = nil

        // Update element - dead observer should not be notified
        registry.updateElement(appElement, for: windowId)

        // No crash and observer is properly cleaned up
    }

    @Test @MainActor
    func observersClearedOnWindowIdDealloc() throws {
        let pid = ProcessInfo.processInfo.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)

        guard let windowId = registry.getOrRegister(element: appElement) else {
            Issue.record("Failed to register element")
            return
        }

        let observer = TestWindowIdObserver()
        registry.registerObserver(observer, for: windowId)

        // Unregister the window
        registry.unregister(windowId)

        // Try to update - observer should not be notified since window was unregistered
        registry.updateElement(appElement, for: windowId)

        // Observer count should remain 0
        #expect(observer.elementRefreshCount == 0)
    }

    @Test @MainActor
    func windowIdAndObserversFreedOnDealloc() throws {
        let pid = ProcessInfo.processInfo.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)

        var windowId: WindowId? = registry.getOrRegister(element: appElement)
        weak var weakWindowId = windowId

        var observer: TestWindowIdObserver? = TestWindowIdObserver()
        if let wid = windowId {
            registry.registerObserver(observer!, for: wid)
        }
        weak var weakObserver = observer

        // Verify both are retained before unregistering
        #expect(weakWindowId != nil)
        #expect(weakObserver != nil)

        // Unregister window and release local references
        if let wid = windowId {
            registry.unregister(wid)
        }
        windowId = nil
        observer = nil

        // Both should be deallocated
        #expect(weakWindowId == nil)
        #expect(weakObserver == nil)
    }
}

// MARK: - Test Observer

/// Observer that tracks notifications for testing
class TestWindowIdObserver: WindowIdObserver {
    private(set) var upgradedCount = 0
    private(set) var elementRefreshCount = 0
    private(set) var invalidatedCount = 0

    func windowIdUpgraded(_ windowId: WindowId, cgWindowID: CGWindowID) {
        upgradedCount += 1
    }

    func windowIdElementRefreshed(_ windowId: WindowId, newElement: AXUIElement) {
        elementRefreshCount += 1
    }

    func windowIdInvalidated(_ windowId: WindowId) {
        invalidatedCount += 1
    }
}
