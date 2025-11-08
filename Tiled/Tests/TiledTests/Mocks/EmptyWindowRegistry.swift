// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Jimmy Ma

import Cocoa
@testable import Tiled

/// A minimal WindowRegistry implementation for tests that doesn't require @MainActor
class EmptyWindowRegistry: WindowRegistry {

    init() {}

    func getOrRegister(element: AXUIElement) -> WindowId? {
        // For tests, just create a minimal WindowId without upgrading
        nil
    }

    func getWindowId(for element: AXUIElement) -> WindowId? {
        nil
    }

    func getElement(for windowId: WindowId) -> AXUIElement? {
        nil
    }

    func updateElement(_ element: AXUIElement, for windowId: WindowId) {
        // No-op for tests
    }

    func unregister(_ windowId: WindowId) {
        // No-op for tests
    }

    func getAllWindowIds() -> [WindowId] {
        []
    }

    func registerObserver(_ observer: WindowIdObserver, for windowId: WindowId) {
        // No-op for tests
    }

    func unregisterObserver(_ observer: WindowIdObserver, for windowId: WindowId) {
        // No-op for tests
    }

    func _notifyWindowIdDestroyed(_ windowId: WindowId) {
        // No-op for tests
    }
}
