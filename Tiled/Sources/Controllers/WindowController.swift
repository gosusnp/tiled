// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Jimmy Ma

import Cocoa
import ApplicationServices

enum WindowError: Error {
    case resizeFailed(AXError)
    case moveFailed(AXError)
    case invalidWindow
}

class WindowController: WindowControllerProtocol {
    let windowId: WindowId
    private let axHelper: AccessibilityAPIHelper

    init(windowId: WindowId, axHelper: AccessibilityAPIHelper) {
        // New init for WindowId-based API
        // window is nil - all element access goes through windowId via registry
        self.windowId = windowId
        self.axHelper = axHelper
    }

    func raise() {
        // TODO we should probably throw here for consistency
        //guard let element = windowId?.getCurrentElement() else { throw WindowError.invalidWindow }
        guard let element = windowId.getCurrentElement() else { return }
        axHelper.raise(element)
    }

    func move(to: CGPoint) throws {
        guard let element = windowId.getCurrentElement() else { throw WindowError.invalidWindow }
        try axHelper.move(element, to: to)
    }

    func resize(size: CGSize) throws {
        guard let element = windowId.getCurrentElement() else { throw WindowError.invalidWindow }
        try axHelper.resize(element, size: size)
    }
}
