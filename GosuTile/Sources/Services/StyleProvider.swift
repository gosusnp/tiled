// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Jimmy Ma

import Cocoa

class StyleProvider {
    private let activeStyle: Style
    private let defaultStyle: Style

    init() {
        activeStyle = Style(
            backgroundColor: NSColor.lightGray,
            foregroundColor: NSColor.labelColor,
            frameBorderColor: NSColor.systemBlue,
        )
        defaultStyle = Style(
            backgroundColor: NSColor.darkGray,
            foregroundColor: NSColor.secondaryLabelColor,
            frameBorderColor: NSColor.gray.withAlphaComponent(0.4),
        )
    }
    func getStyle(isActive: Bool) -> Style { isActive ? self.activeStyle : self.defaultStyle }
}
