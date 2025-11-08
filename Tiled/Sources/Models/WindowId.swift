// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Jimmy Ma

import Cocoa

/// Stable proxy to a window.
/// UUID remains constant throughout window lifetime.
/// Subscribes to registry for state updates (push model).
///
/// Invariant: At least one of cgWindowID or element reference must be present.
/// If both are lost, the window is invalid.
class WindowId: WindowIdObserver, Hashable {
    /// Immutable, unique identity (never changes)
    let id: UUID

    /// Application PID
    let appPID: pid_t

    /// CGWindowID (enriched when available, may be nil initially)
    private(set) var cgWindowID: CGWindowID?

    /// Cached element reference (weak, may become stale)
    private weak var cachedElement: AXUIElement?

    /// Window is still valid (false if both cgWindowID and element are lost)
    private(set) var isValid: Bool = true

    /// Weak reference to registry for state queries
    private weak var registry: WindowRegistry?

    init(appPID: pid_t, cgWindowID: CGWindowID? = nil, registry: WindowRegistry) {
        self.id = UUID()
        self.appPID = appPID
        self.cgWindowID = cgWindowID
        self.registry = registry

        // Subscribe to own updates from registry
        registry.registerObserver(self, for: self)
    }

    /// Get current AXUIElement reference, validating and refreshing as needed.
    /// Checks cached reference first, falls back to registry lookup.
    /// Returns nil if window is invalid.
    func getCurrentElement() -> AXUIElement? {
        guard isValid else { return nil }

        // Fetch current from registry (which maintains the freshest reference)
        guard let element = registry?.getElement(for: self) else {
            return nil
        }

        self.cachedElement = element
        return element
    }

    /// Stable key for dictionary storage (UUID-based, never invalidated)
    func asKey() -> UUID {
        return id
    }

    // MARK: - WindowIdObserver (receives updates from registry)

    func windowIdUpgraded(_ windowId: WindowId, cgWindowID: CGWindowID) {
        guard windowId === self else { return }
        self.cgWindowID = cgWindowID
    }

    func windowIdElementRefreshed(_ windowId: WindowId, newElement: AXUIElement) {
        guard windowId === self else { return }
        self.cachedElement = newElement
    }

    func windowIdInvalidated(_ windowId: WindowId) {
        guard windowId === self else { return }
        self.isValid = false
        self.cachedElement = nil
    }

    // MARK: - Internal (Registry use only)

    func _upgrade(cgWindowID: CGWindowID) {
        self.cgWindowID = cgWindowID
    }

    deinit {
        registry?._notifyWindowIdDestroyed(self)
    }

    // MARK: - Hashable conformance

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: WindowId, rhs: WindowId) -> Bool {
        lhs.id == rhs.id
    }
}
