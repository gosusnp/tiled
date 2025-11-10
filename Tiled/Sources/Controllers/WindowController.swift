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

    func reposition(to rect: CGRect) throws {
        guard let element = windowId.getCurrentElement() else { throw WindowError.invalidWindow }
        // Move first, then resize. This prevents the app from auto-correcting the size
        // if the large window at the original position doesn't fit on screen.
        // By moving to the target position first, we give the app the correct context
        // for what size constraints apply at the destination location.
        try axHelper.move(element, to: rect.origin)
        try axHelper.resize(element, size: rect.size)
    }
}
