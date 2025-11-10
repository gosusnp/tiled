// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Jimmy Ma

import Cocoa

// MARK: - WindowRegistry Protocol

protocol WindowRegistry: AnyObject {

    /// Register or retrieve WindowId for element.
    /// If element matches existing partial WindowId (same appPID), upgrades in-place.
    /// Creates new WindowId with available identifying information.
    func getOrRegister(element: AXUIElement) -> WindowId?

    /// Look up WindowId by element
    func getWindowId(for element: AXUIElement) -> WindowId?

    /// Look up current element by WindowId
    func getElement(for windowId: WindowId) -> AXUIElement?

    /// Update element reference for WindowId (handles stale reference recovery)
    func updateElement(_ element: AXUIElement, for windowId: WindowId)

    /// Unregister and invalidate a window
    func unregister(_ windowId: WindowId)

    /// Get all currently tracked WindowIds
    func getAllWindowIds() -> [WindowId]

    /// Register observer for WindowId state changes
    func registerObserver(_ observer: WindowIdObserver, for windowId: WindowId)

    /// Unregister observer
    func unregisterObserver(_ observer: WindowIdObserver, for windowId: WindowId)

    // MARK: - Internal (WindowId use only)

    /// Called by WindowId.deinit to notify registry of destruction
    func _notifyWindowIdDestroyed(_ windowId: WindowId)
}

// MARK: - WindowIdObserver Protocol

/// Observer for WindowId state changes.
/// WindowId itself implements this to receive updates from registry.
/// When WindowId is deallocated, it's automatically removed from observer list.
protocol WindowIdObserver: AnyObject {

    /// WindowId was upgraded from partial (appPID only) to complete (cgWindowID present)
    func windowIdUpgraded(_ windowId: WindowId, cgWindowID: CGWindowID)

    /// Element reference was refreshed (stale detection + recovery)
    func windowIdElementRefreshed(_ windowId: WindowId, newElement: AXUIElement)

    /// WindowId was invalidated (lost both cgWindowID and element reference)
    func windowIdInvalidated(_ windowId: WindowId)
}

// MARK: - WeakObserver Wrapper

/// Wrapper for weak references to WindowIdObserver objects.
/// Used instead of NSHashTable to avoid Objective-C runtime issues.
private class WeakObserver {
    private weak var observer: WindowIdObserver?

    init(_ observer: WindowIdObserver) {
        self.observer = observer
    }

    func call<T>(block: (WindowIdObserver) -> T?) -> T? {
        guard let observer = observer else { return nil }
        return block(observer)
    }

    var isAlive: Bool {
        return observer != nil
    }
}

// MARK: - Default WindowRegistry Implementation

/// Thread-safe registry for window identification.
///
/// Key design principle: Do not break references held by consumers.
/// - Never remove WindowId references, only add/upgrade
/// - Element mappings are additive; old stale mappings may remain as harmless orphans
/// - Consumers' WindowId keys remain valid throughout the window's lifetime
class DefaultWindowRegistry: WindowRegistry {

    // MARK: - Storage

    /// WindowId -> element reference mapping (current element for the window)
    private var elementByWindowId: [UUID: AXUIElement] = [:]

    /// Element -> WindowId mapping (using object reference identity as key)
    /// Note: May contain orphaned stale elements pointing to the same WindowId
    /// Uses a Dictionary with the element's raw pointer as key for stable identity
    private var windowIdByElement: [ObjectIdentifier: WindowId] = [:]

    /// CGWindowID -> WindowId mapping (complete windows)
    private var windowIdByCGWindowID: [CGWindowID: WindowId] = [:]

    /// AppPID -> partial WindowIds (those without cgWindowID)
    /// Only one partial per appPID; upgraded in-place when cgWindowID discovered
    private var partialWindowIds: [pid_t: WindowId] = [:]

    /// WindowId -> observers mapping (weak references)
    /// Note: Using Array with weak references instead of NSHashTable to avoid
    /// Objective-C runtime issues on ARM64e (pointer authentication)
    private var observers: [UUID: [WeakObserver]] = [:]

    private let lock = NSRecursiveLock()

    /// Helper for Accessibility API interactions (injected for testability)
    private let axHelper: AccessibilityAPIHelper

    init(axHelper: AccessibilityAPIHelper = DefaultAccessibilityAPIHelper()) {
        self.axHelper = axHelper
    }

    // MARK: - Public API

    func getOrRegister(element: AXUIElement) -> WindowId? {
        lock.lock()
        defer { lock.unlock() }

        // Check if we already know about this element
        if let existing = windowIdByElement[ObjectIdentifier(element)] {
            return existing
        }

        // New element. Extract info.
        guard let appPID = axHelper.getAppPID(element) else { return nil }
        let cgWindowID = axHelper.getWindowID(element)

        // DEDUPLICATION FIX: Check if we already have a complete WindowId for this cgWindowID
        // This handles the case where observer sends element1 (no cgWindowID), then poller sends
        // element2 (different AXUIElement ref, but same cgWindowID). Both represent the same window.
        if let cgWindowID,
           let existing = windowIdByCGWindowID[cgWindowID] {
            // Update element mapping for existing WindowId (additive)
            windowIdByElement[ObjectIdentifier(element)] = existing
            elementByWindowId[existing.id] = element
            return existing
        }

        // Check if this matches an existing partial WindowId (same appPID, no cgWindowID yet)
        if let partial = partialWindowIds[appPID],
           partial.cgWindowID == nil,
           let cgWindowID = cgWindowID {
            // Validate the partial's cached element isn't stale before upgrading
            if !isStale(partial) {
                // This is the same window! Upgrade it.
                upgrade(partial, with: cgWindowID, element: element)
                return partial
            }
            // If partial's element is stale, treat as new window (don't upgrade)
            // This avoids creating duplicates from invalid references
        }

        // New window entirely
        let windowId = WindowId(appPID: appPID, cgWindowID: cgWindowID, registry: self)
        storeWindowId(windowId, for: element)

        return windowId
    }

    func getWindowId(for element: AXUIElement) -> WindowId? {
        lock.lock()
        defer { lock.unlock() }
        return windowIdByElement[ObjectIdentifier(element)]
    }

    func getElement(for windowId: WindowId) -> AXUIElement? {
        lock.lock()
        defer { lock.unlock() }
        return elementByWindowId[windowId.id]
    }

    func updateElement(_ element: AXUIElement, for windowId: WindowId) {
        lock.lock()
        defer { lock.unlock() }

        // Add new mapping (additive, don't remove old one)
        // Old stale element may remain in the map as a harmless orphan,
        // still pointing to the same WindowId. This maintains reference stability.
        elementByWindowId[windowId.id] = element
        windowIdByElement[ObjectIdentifier(element)] = windowId

        // Notify observers of refresh
        notifyObservers(windowId: windowId, event: .elementRefreshed(element: element))
    }

    func unregister(_ windowId: WindowId) {
        lock.lock()
        defer { lock.unlock() }

        // Remove element mapping
        if let element = elementByWindowId.removeValue(forKey: windowId.id) {
            windowIdByElement.removeValue(forKey: ObjectIdentifier(element))
        }

        // Remove from tracking based on completion state
        if let cgWindowID = windowId.cgWindowID {
            // Complete WindowId: remove from cgWindowID mapping
            windowIdByCGWindowID.removeValue(forKey: cgWindowID)
        } else {
            // Partial WindowId: remove from partial tracking
            partialWindowIds.removeValue(forKey: windowId.appPID)
        }

        // Notify observers of invalidation
        notifyObservers(windowId: windowId, event: .invalidated)

        // Clear observer list
        observers.removeValue(forKey: windowId.id)
    }

    func getAllWindowIds() -> [WindowId] {
        lock.lock()
        defer { lock.unlock() }

        var allIds: [WindowId] = []
        allIds.append(contentsOf: partialWindowIds.values)
        allIds.append(contentsOf: windowIdByCGWindowID.values)
        return allIds
    }

    func registerObserver(_ observer: WindowIdObserver, for windowId: WindowId) {
        lock.lock()
        defer { lock.unlock() }

        if observers[windowId.id] == nil {
            observers[windowId.id] = []
        }
        observers[windowId.id]?.append(WeakObserver(observer))
    }

    func unregisterObserver(_ observer: WindowIdObserver, for windowId: WindowId) {
        lock.lock()
        defer { lock.unlock() }

        // Remove dead observers and the matching observer
        if var observerList = observers[windowId.id] {
            observerList.removeAll { !$0.isAlive }
            observers[windowId.id] = observerList.isEmpty ? nil : observerList
        }
    }

    func _notifyWindowIdDestroyed(_ windowId: WindowId) {
        lock.lock()
        defer { lock.unlock() }

        observers.removeValue(forKey: windowId.id)
    }

    // MARK: - Private Helpers

    private func storeWindowId(_ windowId: WindowId, for element: AXUIElement) {
        elementByWindowId[windowId.id] = element
        windowIdByElement[ObjectIdentifier(element)] = windowId

        if let cgWindowID = windowId.cgWindowID {
            windowIdByCGWindowID[cgWindowID] = windowId
        } else {
            partialWindowIds[windowId.appPID] = windowId
        }
    }

    private func isStale(_ windowId: WindowId) -> Bool {
        // Check if the WindowId's cached element is still valid
        guard let cachedElement = elementByWindowId[windowId.id] else {
            return true  // No element at all = stale
        }

        // Validate the element is still alive using helper
        return !axHelper.isElementValid(cachedElement)
    }

    private func upgrade(_ windowId: WindowId, with cgWindowID: CGWindowID, element: AXUIElement) {
        // Update WindowId's state (use internal method since cgWindowID is private(set))
        windowId._upgrade(cgWindowID: cgWindowID)

        // Move from partial tracking to complete tracking
        partialWindowIds.removeValue(forKey: windowId.appPID)
        windowIdByCGWindowID[cgWindowID] = windowId

        // Update element mapping (additive, don't remove old)
        // The new element is fresher and will be used going forward
        elementByWindowId[windowId.id] = element
        windowIdByElement[ObjectIdentifier(element)] = windowId
        // Old element stays in windowIdByElement if it was there; it's a harmless orphan

        // Notify observers of upgrade
        notifyObservers(windowId: windowId, event: .upgraded(cgWindowID: cgWindowID))
    }

    private func notifyObservers(windowId: WindowId, event: WindowIdEvent) {
        guard var observerList = observers[windowId.id] else { return }

        // Iterate over weak refs and clean up dead ones
        var deadCount = 0
        for weakObserver in observerList {
            let _ = weakObserver.call { (observer: WindowIdObserver) -> Void? in
                switch event {
                case .upgraded(let cgWindowID):
                    observer.windowIdUpgraded(windowId, cgWindowID: cgWindowID)
                case .elementRefreshed(let element):
                    observer.windowIdElementRefreshed(windowId, newElement: element)
                case .invalidated:
                    observer.windowIdInvalidated(windowId)
                }
                return nil
            }
            if !weakObserver.isAlive {
                deadCount += 1
            }
        }

        // Clean up dead observers if any exist
        if deadCount > 0 {
            observerList.removeAll { !$0.isAlive }
            observers[windowId.id] = observerList.isEmpty ? nil : observerList
        }
    }
}

// MARK: - Event Type

private enum WindowIdEvent {
    case upgraded(cgWindowID: CGWindowID)
    case elementRefreshed(element: AXUIElement)
    case invalidated
}

