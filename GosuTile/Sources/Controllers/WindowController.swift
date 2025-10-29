// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Jimmy Ma

import Cocoa
import ApplicationServices

enum WindowError: Error {
    case resizeFailed(AXError)
    case moveFailed(AXError)
    case invalidWindow
}

class WindowController {
    let window: WindowModel

    var isFocused: Bool {
        var value: AnyObject?
        let result =
            AXUIElementCopyAttributeValue(self.window.element, kAXFocusedAttribute as CFString, &value)

        guard result == .success, let isFocused = value as? Bool else {
            return false
        }
        return isFocused
    }

    var isMain: Bool {
        var value: AnyObject?
        let result =
            AXUIElementCopyAttributeValue(self.window.element, kAXMainAttribute as CFString, &value)

        guard result == .success, let isMain = value as? Bool else {
            return false
        }
        return isMain
    }

    var size: CGSize {
        var sizeValue: CFTypeRef?
        AXUIElementCopyAttributeValue(self.window.element, kAXSizeAttribute as CFString, &sizeValue)

        let sizeValueRef = sizeValue
        var size = CGSize.zero

        AXValueGetValue(sizeValueRef as! AXValue, .cgSize, &size)

        return size
    }

    var appName: String { window.appName }
    var title: String { window.title }

    init(window: WindowModel) {
        self.window = window
    }

    func raise() {
        raiseWindow(self.window.element)
    }

    func move(to: CGPoint) throws {
        var position = to
        guard let axPosition = AXValueCreate(.cgPoint, &position) else {
            throw WindowError.invalidWindow
        }

        let result = AXUIElementSetAttributeValue(self.window.element, kAXPositionAttribute as CFString, axPosition)

        guard result == .success else {
            throw WindowError.moveFailed(result)
        }
    }

    func resize(size: CGSize) throws {
        var targetSize = size
        guard let axSize = AXValueCreate(.cgSize, &targetSize) else {
            throw WindowError.invalidWindow
        }

        let result = AXUIElementSetAttributeValue(self.window.element, kAXSizeAttribute as CFString, axSize)

        guard result == .success else {
            throw WindowError.resizeFailed(result)
        }
    }

    private func raiseWindow(_ window: AXUIElement) {
        var pid: pid_t = 0
        AXUIElementGetPid(window, &pid)

        // Try raise action
        AXUIElementPerformAction(window, kAXRaiseAction as CFString)

        // Try activating app
        if let app = NSRunningApplication(processIdentifier: pid) {
            app.activate()
        }

        // // Try setting as main window
        let appElement = AXUIElementCreateApplication(pid)
        AXUIElementSetAttributeValue(
            appElement,
            kAXMainWindowAttribute as CFString,
            window as CFTypeRef
        )
    }

    static func fromElement(_ element: AXUIElement) -> WindowController {
        var titleRef: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleRef)
        let title = titleRef as? String ?? "Untitled"

        var pid: pid_t = 0
        AXUIElementGetPid(element, &pid)
        let app = NSRunningApplication(processIdentifier: pid)
        let appName = app?.localizedName ?? "Unknown"

        return WindowController(
            window: WindowModel(
                element: element,
                title: title,
                appName: appName,
            )
        )
    }
}
