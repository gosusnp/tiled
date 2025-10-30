// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Jimmy Ma

import Cocoa
import ApplicationServices

@MainActor
class FrameController {
    let config: ConfigController
    private let geometry: FrameGeometry
    let frameWindow: FrameWindow
    let windowStack: WindowStackController

    var children: [FrameController] = []

    var activeWindow: WindowController? {
        self.windowStack.activeWindow
    }

    init(rect: CGRect, config: ConfigController) {
        self.config = config
        self.geometry = FrameGeometry(rect: rect, titleBarHeight: config.titleBarHeight)
        self.frameWindow = FrameWindow()
        self.windowStack = WindowStackController()
    }

    private init(geometry: FrameGeometry, config: ConfigController) {
        self.config = config
        self.geometry = geometry
        self.frameWindow = FrameWindow()
        self.windowStack = WindowStackController()
    }

    func refreshOverlay() {
        self.frameWindow.updateOverlay(
            rect: self.geometry.titleBarRect,
            tabs: self.windowStack.tabs,
        )
    }

    func addWindow(_ window: WindowController) throws {
        try self.windowStack.add(window)

        // resize window to frame size
        let targetRect = self.geometry.contentRect
        try window.resize(size: targetRect.size)
        try window.move(to: targetRect.origin)
    }

    func nextWindow() {
        self.windowStack.nextWindow()
        self.activeWindow?.raise()
        self.refreshOverlay()
    }

    func previousWindow() {
        self.windowStack.previousWindow()
        self.activeWindow?.raise()
        self.refreshOverlay()
    }

    private func takeWindowsFrom(_ other: FrameController) throws {
        // Transfer windows to this frame's stack
        try self.windowStack.takeAll(from: other.windowStack)

        // Reposition all windows to fit this frame
        let targetRect = self.geometry.contentRect
        for w in self.windowStack.all {
            try w.resize(size: targetRect.size)
            try w.move(to: targetRect.origin)
        }
    }

    func split(direction: Direction) throws {
        precondition(self.children.isEmpty)

        let (geo1, geo2) = direction == .Horizontal
            ? self.geometry.splitHorizontally()
            : self.geometry.splitVertically()

        let child1 = FrameController(geometry: geo1, config: self.config)
        let child2 = FrameController(geometry: geo2, config: self.config)
        self.children = [child1, child2]

        try child1.takeWindowsFrom(self)
    }

    func toString() -> String {
        return "Frame(rect=\(self.geometry.rect))"
    }

    static func fromScreen(_ screen: NSScreen, config: ConfigController) -> FrameController {
        let geometry = FrameGeometry.fromScreen(screen, titleBarHeight: config.titleBarHeight)
        return FrameController(rect: geometry.rect, config: config)
    }
}
