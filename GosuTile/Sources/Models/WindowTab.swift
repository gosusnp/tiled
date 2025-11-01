// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Jimmy Ma

import Cocoa

class WindowTab {
    let title: String
    let isActive: Bool
    let style: Style

    init(title: String, isActive: Bool, style: Style) {
        self.title = title
        self.isActive = isActive
        self.style = style
    }
}
