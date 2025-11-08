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
    let window: WindowModel?
    let windowId: WindowId?
    weak var frame: FrameController?

    var isFocused: Bool {
        guard let window = window else { return false }
        var value: AnyObject?
        let result =
            AXUIElementCopyAttributeValue(window.element, kAXFocusedAttribute as CFString, &value)

        guard result == .success, let isFocused = value as? Bool else {
            return false
        }
        return isFocused
    }

    var isMain: Bool {
        guard let window = window else { return false }
        var value: AnyObject?
        let result =
            AXUIElementCopyAttributeValue(window.element, kAXMainAttribute as CFString, &value)

        guard result == .success, let isMain = value as? Bool else {
            return false
        }
        return isMain
    }

    var size: CGSize {
        guard let window = window else { return .zero }
        var sizeValue: CFTypeRef?
        AXUIElementCopyAttributeValue(window.element, kAXSizeAttribute as CFString, &sizeValue)

        let sizeValueRef = sizeValue
        var size = CGSize.zero

        AXValueGetValue(sizeValueRef as! AXValue, .cgSize, &size)

        return size
    }

    var appName: String { window?.appName ?? "Unknown" }
    var title: String { window?.title ?? "Untitled" }

    init(window: WindowModel) {
        self.window = window
        self.windowId = nil
    }

    init(windowId: WindowId, title: String, appName: String) {
        // New init for WindowId-based API
        // window is nil - all element access goes through windowId via registry
        self.windowId = windowId
        self.window = nil
    }

    func raise() {
        guard let window = window else { return }
        raiseWindow(window.element)
    }

    func move(to: CGPoint) throws {
        guard let window = window else { throw WindowError.invalidWindow }
        var position = to
        guard let axPosition = AXValueCreate(.cgPoint, &position) else {
            throw WindowError.invalidWindow
        }

        let result = AXUIElementSetAttributeValue(window.element, kAXPositionAttribute as CFString, axPosition)

        guard result == .success else {
            throw WindowError.moveFailed(result)
        }
    }

    func resize(size: CGSize) throws {
        guard let window = window else { throw WindowError.invalidWindow }
        var targetSize = size
        guard let axSize = AXValueCreate(.cgSize, &targetSize) else {
            throw WindowError.invalidWindow
        }

        let result = AXUIElementSetAttributeValue(window.element, kAXSizeAttribute as CFString, axSize)

        guard result == .success else {
            throw WindowError.resizeFailed(result)
        }
    }

    private func raiseWindow(_ window: AXUIElement) {
        var pid: pid_t = 0
        AXUIElementGetPid(window, &pid)

        // 1. First, activate the application
        if let app = NSRunningApplication(processIdentifier: pid) {
            if #available(macOS 14.0, *) {
                app.activate(options: .activateAllWindows)
            } else {
                app.activate(options: [.activateIgnoringOtherApps])
            }
        }

        // 2. Longer delay after app switcher usage
        usleep(100_000) // 100ms - increased delay

        // 3. Set as main window BEFORE raise action
        let appElement = AXUIElementCreateApplication(pid)
        AXUIElementSetAttributeValue(appElement, kAXMainWindowAttribute as CFString, window as CFTypeRef)

        // 4. Another small delay
        usleep(50_000) // 50ms

        // 5. Try the raise action
        AXUIElementPerformAction(window, kAXRaiseAction as CFString)

        // 6. Set focused attribute
        AXUIElementSetAttributeValue(window, kAXFocusedAttribute as CFString, kCFBooleanTrue)

        // 7. Force frontmost (this helps after app switcher)
        AXUIElementSetAttributeValue(appElement, kAXFrontmostAttribute as CFString, kCFBooleanTrue)

        // 8. Set main window again (helps with stubborn windows)
        AXUIElementSetAttributeValue(appElement, kAXMainWindowAttribute as CFString, window as CFTypeRef)
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
