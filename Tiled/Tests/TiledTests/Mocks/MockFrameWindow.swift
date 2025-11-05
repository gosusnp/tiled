// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Jimmy Ma

import Cocoa
@testable import Tiled

class MockFrameWindow: FrameWindowProtocol {
    var updateOverlayCallCount = 0
    var clearCallCount = 0
    var setActiveCallCount = 0
    var hideCallCount = 0
    var showCallCount = 0

    var lastUpdateOverlayTabs: [WindowTab]?
    var lastSetActiveValue: Bool?

    func updateOverlay(tabs: [WindowTab]) {
        updateOverlayCallCount += 1
        lastUpdateOverlayTabs = tabs
    }

    func clear() {
        clearCallCount += 1
    }

    func setActive(_ isActive: Bool) {
        setActiveCallCount += 1
        lastSetActiveValue = isActive
    }

    func hide() {
        hideCallCount += 1
    }

    func show() {
        showCallCount += 1
    }

    func close() {
        // No-op for mock
    }
}
