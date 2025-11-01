// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Jimmy Ma

import Cocoa

class Style {
    let backgroundColor: NSColor
    let foregroundColor: NSColor

    let borderColor: NSColor
    let borderWidth: CGFloat

    let cornerRadius: CGFloat
    let cornerMask: CACornerMask

    let font: NSFont

    init(
        backgroundColor: NSColor,
        foregroundColor: NSColor,
    ) {
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor

        self.borderColor = NSColor.separatorColor
        self.borderWidth = 1

        self.cornerRadius = 2
        self.cornerMask = [.layerMinXMinYCorner, .layerMaxXMinYCorner]

        self.font = NSFont.systemFont(ofSize: 13)
    }
}
