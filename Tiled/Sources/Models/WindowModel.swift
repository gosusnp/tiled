// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Jimmy Ma

import Cocoa
import ApplicationServices

class WindowModel {
    let element: AXUIElement
    let title: String
    let appName: String

    init(element: AXUIElement, title: String, appName: String) {
        self.element = element
        self.title = title
        self.appName = appName
    }
}
