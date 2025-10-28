// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Jimmy Ma

import Cocoa
import ApplicationServices

@MainActor
class FrameWindow {
    private var window: NSWindow

    init() {
        let window = NSWindow(
            contentRect: .zero,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.level = .floating
        // TODO fix the color
        window.backgroundColor = NSColor.blue
        window.isOpaque = false
        window.hasShadow = false

        window.orderFront(nil)

        self.window = window
    }

    func updateOverlay(rect: CGRect) {
        self.window.setFrame(rect, display: true)
    }
}
