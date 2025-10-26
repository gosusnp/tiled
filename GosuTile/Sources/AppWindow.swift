// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Jimmy Ma

import Cocoa
import ApplicationServices

enum AppWindowError: Error {
    case resizeFailed(AXError)
    case moveFailed(AXError)
    case invalidWindow
}

// MARK: - AppWindow
struct AppWindow {
    let element: AXUIElement
    let title: String
    let appName: String

    init(_ element: AXUIElement) {
        self.element = element

        var titleRef: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleRef)
        self.title = titleRef as? String ?? "Untitled"

        var pid: pid_t = 0
        AXUIElementGetPid(element, &pid)
        let app = NSRunningApplication(processIdentifier: pid)
        self.appName = app?.localizedName ?? "Unknown"
    }

    func move(to: CGPoint) throws {
        var position = to
        guard let axPosition = AXValueCreate(.cgPoint, &position) else {
            throw AppWindowError.invalidWindow
        }
        
        let result = AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, axPosition)
        
        guard result == .success else {
            throw AppWindowError.moveFailed(result)
        }
    }

    func resize(size: CGSize) throws {
        var targetSize = size
        guard let axSize = AXValueCreate(.cgSize, &targetSize) else {
            throw AppWindowError.invalidWindow
        }
        
        let result = AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, axSize)
        
        guard result == .success else {
            throw AppWindowError.resizeFailed(result)
        }
    }
}
