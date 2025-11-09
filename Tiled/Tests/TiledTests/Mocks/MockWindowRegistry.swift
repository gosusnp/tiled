// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Jimmy Ma

import Cocoa
import ApplicationServices
@testable import Tiled

// MARK: - Mock AXUIElement for tests

@MainActor
class MockAXElement {
    let id: UUID = UUID()
    private static var _ptrCounter: UInt = 0x2000
    private let _ptrValue: UInt

    var title: String = "Test Window"
    var appPID: pid_t = 1234
    var isFocused: Bool = false
    var isMain: Bool = false
    var size: CGSize = CGSize(width: 800, height: 600)

    init() {
        _ptrValue = Self._ptrCounter
        Self._ptrCounter += 1
    }

    func asAXElement() -> AXUIElement {
        return UnsafeMutableRawPointer(bitPattern: _ptrValue)! as! AXUIElement
    }
}

// MARK: - Mock WindowRegistry

@MainActor
class MockWindowRegistry: @preconcurrency WindowRegistry {
    var elements: [UUID: AXUIElement] = [:]
    var mockElement: MockAXElement?
    private var elementByWindowId: [UUID: AXUIElement] = [:]
    private var validWindowIds: Set<UUID> = []

    func getOrRegister(element: AXUIElement) -> WindowId? {
        return WindowId(appPID: 1234, registry: self)
    }

    func getWindowId(for element: AXUIElement) -> WindowId? {
        return nil
    }

    func getElement(for windowId: WindowId) -> AXUIElement? {
        guard validWindowIds.contains(windowId.id) else { return nil }
        return elementByWindowId[windowId.id]
    }

    func updateElement(_ element: AXUIElement, for windowId: WindowId) {}

    func unregister(_ windowId: WindowId) {
        elementByWindowId.removeValue(forKey: windowId.id)
        validWindowIds.remove(windowId.id)
    }

    func getAllWindowIds() -> [WindowId] {
        return []
    }

    func registerObserver(_ observer: WindowIdObserver, for windowId: WindowId) {}

    func unregisterObserver(_ observer: WindowIdObserver, for windowId: WindowId) {}

    func _notifyWindowIdDestroyed(_ windowId: WindowId) {}

    // Test helper methods
    func registerElement(_ element: AXUIElement, for windowIdUUID: UUID) {
        elementByWindowId[windowIdUUID] = element
        validWindowIds.insert(windowIdUUID)
    }

    func invalidateWindow(for windowIdUUID: UUID) {
        elementByWindowId.removeValue(forKey: windowIdUUID)
        validWindowIds.remove(windowIdUUID)
    }
}

// MARK: - Mock Accessibility Helper

@MainActor
class MockAccessibilityHelper {
    var mockTitle: String = "Test Window"
    var mockAppPID: pid_t = 1234
    var mockAppName: String = "TestApp"
    var mockIsFocused: Bool = false
    var mockIsMain: Bool = false
    var mockSize: CGSize = CGSize(width: 800, height: 600)

    func getTitle(_ element: AXUIElement) -> String {
        return mockTitle
    }

    func getAppPID(_ element: AXUIElement) -> pid_t {
        return mockAppPID
    }

    func getAppName(pid: pid_t) -> String {
        return mockAppName
    }

    func getIsFocused(_ element: AXUIElement) -> Bool {
        return mockIsFocused
    }

    func getIsMain(_ element: AXUIElement) -> Bool {
        return mockIsMain
    }

    func getSize(_ element: AXUIElement) -> CGSize {
        return mockSize
    }
}
