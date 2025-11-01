// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Jimmy Ma

import Cocoa
import ApplicationServices

@MainActor
class FrameWindow {
    private var window: NSWindow
    private var titleBarView: FrameTitleBarView? {
        window.contentView as? FrameTitleBarView
    }

    init() {
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary]

        // Panel won't activate when shown
        panel.becomesKeyOnlyIfNeeded = false
        panel.hidesOnDeactivate = false

        panel.contentView = FrameTitleBarView(frame: .zero)
        panel.orderFront(nil)

        self.window = panel
    }

    func updateOverlay(rect: CGRect, tabs: [WindowTab]) {
        self.window.setFrame(rect, display: true)
        self.titleBarView?.setupTabs(tabs: tabs)
    }

    func clear() {
        self.window.setIsVisible(false)
        self.titleBarView?.setupTabs(tabs: [])
    }
}
