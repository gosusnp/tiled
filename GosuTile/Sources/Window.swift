// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Jimmy Ma

import Cocoa
import ApplicationServices

// MARK: - Window
struct Window {
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
}

