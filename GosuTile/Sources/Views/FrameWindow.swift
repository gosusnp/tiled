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

    init(geo: FrameGeometry, styleProvider: StyleProvider) {
        let frame = FrameWindow.invertY(rect: geo.frameRect)
        let panel = NSPanel(
            contentRect: frame,
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

        panel.contentView = FrameTitleBarView(geometry: geo, styleProvider: styleProvider)
        panel.orderFront(nil)

        self.window = panel
    }

    func updateOverlay(tabs: [WindowTab]) {
        self.titleBarView?.setupTabs(tabs: tabs)
    }

    func clear() {
        self.titleBarView?.setupTabs(tabs: [])
        self.titleBarView?.setActive(false)  // Show dimmed border for parent
    }

    func setActive(_ isActive: Bool) {
        self.titleBarView?.setActive(isActive)
    }

    private static func invertY(rect: CGRect) -> NSRect {
        let screenHeight = NSScreen.main?.frame.height ?? 0
        let convertedY = screenHeight - rect.origin.y - rect.size.height
        return NSRect(x: rect.origin.x, y: convertedY, width: rect.size.width, height: rect.size.height)
    }
}
