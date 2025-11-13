// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Jimmy Ma

import Cocoa

/// Per-space window registry.
/// Maintains separate tracking for each macOS Space/Desktop.
/// This is a service object that manages window identity and deduplication for a specific space.
/// NOT marked @MainActor - can be created/accessed from any context.
///
/// Storage model:
/// - Permanent windows: keyed by cgWindowID (system authority)
/// - Ephemeral windows: keyed by element ObjectIdentifier (observer hints)
/// - All windows: tracked in allWindowIds for lifecycle management
///
/// Invariants:
/// - One WindowId per cgWindowID (no duplicates in permanent storage)
/// - One WindowId per unique element (deduplication by element reference)
/// - cgWindowID=nil means ephemeral (not yet confirmed by poller)
/// - cgWindowID set means permanent (confirmed from CGWindowList)
@MainActor
class SpaceWindowRegistry {
    // MARK: - Storage

    /// Permanent windows: keyed by system identifier
    /// These are windows confirmed to exist in CGWindowList
    private var windowIdByCGWindowID: [CGWindowID: WindowId] = [:]

    /// Lookup by element: both ephemeral + permanent
    /// Maps element ObjectIdentifier to WindowId
    /// Used to find existing WindowId when element is observed
    private var windowIdByElement: [ObjectIdentifier: WindowId] = [:]

    /// All WindowIds in this space (for lifecycle tracking)
    /// Kept for cleanup operations
    private var allWindowIds: Set<WindowId> = []

    /// Lock for thread-safe access
    private let lock = NSRecursiveLock()

    /// Logger
    let logger: Logger

    // MARK: - Initialization

    init(logger: Logger) {
        self.logger = logger
    }

    // MARK: - Permanent Window Registration

    /// Register a permanent window (cgWindowID known)
    func register(_ windowId: WindowId, withCGWindowID cgWindowID: CGWindowID) {
        lock.lock()
        defer { lock.unlock() }

        windowIdByCGWindowID[cgWindowID] = windowId
        allWindowIds.insert(windowId)

        logger.debug("Registered permanent window: cgWindowID=\(cgWindowID), uuid=\(windowId.id)")
    }

    /// Look up permanent window by cgWindowID
    func lookupPermanent(by cgWindowID: CGWindowID) -> WindowId? {
        lock.lock()
        defer { lock.unlock() }

        return windowIdByCGWindowID[cgWindowID]
    }

    // MARK: - Ephemeral Window Registration

    /// Register an ephemeral window (cgWindowID=nil)
    func registerEphemeral(_ windowId: WindowId, forElement element: AXUIElement) {
        lock.lock()
        defer { lock.unlock() }

        let elementId = ObjectIdentifier(element)
        windowIdByElement[elementId] = windowId
        allWindowIds.insert(windowId)

        logger.debug("Registered ephemeral window: element=\(elementId), uuid=\(windowId.id)")
    }

    /// Look up ephemeral window by element
    func lookupEphemeral(by element: AXUIElement) -> WindowId? {
        lock.lock()
        defer { lock.unlock() }

        let elementId = ObjectIdentifier(element)
        return windowIdByElement[elementId]
    }

    // MARK: - Upgrade Ephemeral to Permanent

    /// Upgrade ephemeral window to permanent
    /// Moves from ephemeral tracking to permanent, removes old element mappings
    func upgradeToPermanent(_ windowId: WindowId, withCGWindowID cgWindowID: CGWindowID) {
        lock.lock()
        defer { lock.unlock() }

        // Store in permanent tracking
        windowIdByCGWindowID[cgWindowID] = windowId

        // Remove ephemeral element mappings for this window
        // (there may be multiple if element churned)
        let elementsToRemove = windowIdByElement
            .filter { $0.value.id == windowId.id }
            .map { $0.key }

        for elementId in elementsToRemove {
            windowIdByElement.removeValue(forKey: elementId)
        }

        logger.debug("Upgraded window to permanent: cgWindowID=\(cgWindowID), uuid=\(windowId.id)")
    }

    // MARK: - Cleanup

    /// Remove orphaned ephemeral window (element stale, not in CGWindowList)
    func removeOrphanedEphemeral(by element: AXUIElement) {
        lock.lock()
        defer { lock.unlock() }

        let elementId = ObjectIdentifier(element)

        if let windowId = windowIdByElement.removeValue(forKey: elementId) {
            // Check if this window has other element references
            let hasOtherReferences = windowIdByElement.values.contains { $0.id == windowId.id }

            // If no other references and not in permanent storage, remove from tracking
            if !hasOtherReferences && windowIdByCGWindowID.values.contains(where: { $0.id == windowId.id }) == false {
                allWindowIds.remove(windowId)
                logger.debug("Removed orphaned ephemeral: element=\(elementId), uuid=\(windowId.id)")
            }
        }
    }

    /// Unregister closed window (cgWindowID no longer in CGWindowList)
    func unregister(by cgWindowID: CGWindowID) {
        lock.lock()
        defer { lock.unlock() }

        if let windowId = windowIdByCGWindowID.removeValue(forKey: cgWindowID) {
            // Remove ephemeral element references
            let elementsToRemove = windowIdByElement
                .filter { $0.value.id == windowId.id }
                .map { $0.key }

            for elementId in elementsToRemove {
                windowIdByElement.removeValue(forKey: elementId)
            }

            // Remove from all tracking
            allWindowIds.remove(windowId)

            logger.debug("Unregistered closed window: cgWindowID=\(cgWindowID), uuid=\(windowId.id)")
        }
    }

    // MARK: - Queries

    /// Get all WindowIds in this space
    func getAllWindowIds() -> [WindowId] {
        lock.lock()
        defer { lock.unlock() }

        return Array(allWindowIds)
    }

    /// Get all permanent WindowIds
    func getAllPermanentWindowIds() -> [WindowId] {
        lock.lock()
        defer { lock.unlock() }

        return Array(windowIdByCGWindowID.values)
    }

    /// Get all ephemeral WindowIds
    func getAllEphemeralWindowIds() -> [WindowId] {
        lock.lock()
        defer { lock.unlock() }

        let ephemeralSet = Set(windowIdByElement.values)
        let permanentSet = Set(windowIdByCGWindowID.values)

        return Array(ephemeralSet.subtracting(permanentSet))
    }

    /// Check if window is permanent
    func isPermanent(_ windowId: WindowId) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        return windowId.cgWindowID != nil && windowIdByCGWindowID[windowId.cgWindowID!] != nil
    }
}
