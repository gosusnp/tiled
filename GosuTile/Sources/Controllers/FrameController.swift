// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Jimmy Ma

import Cocoa
import ApplicationServices

@MainActor
class FrameController {
    let config: ConfigController
    let styleProvider: StyleProvider
    private let geometry: FrameGeometry
    let frameWindow: FrameWindow
    let windowStack: WindowStackController

    var children: [FrameController] = []
    weak var parent: FrameController? = nil

    var activeWindow: WindowController? {
        self.windowStack.activeWindow
    }

    init(rect: CGRect, config: ConfigController) {
        self.config = config
        self.styleProvider = StyleProvider()
        self.geometry = FrameGeometry(rect: rect, titleBarHeight: config.titleBarHeight)
        self.frameWindow = FrameWindow(geo: self.geometry, styleProvider: self.styleProvider)
        self.windowStack = WindowStackController(styleProvider: self.styleProvider)
    }

    private init(geometry: FrameGeometry, config: ConfigController) {
        self.config = config
        self.styleProvider = StyleProvider()
        self.geometry = geometry
        self.frameWindow = FrameWindow(geo: self.geometry, styleProvider: self.styleProvider)
        self.windowStack = WindowStackController(styleProvider: self.styleProvider)
    }

    func refreshOverlay() {
        if (self.children.isEmpty) {
            self.frameWindow.updateOverlay(tabs: self.windowStack.tabs)
        } else {
            self.frameWindow.clear()
            for child in self.children {
                child.refreshOverlay()
            }
        }
    }

    func addWindow(_ window: WindowController, shouldFocus: Bool = false) throws {
        window.frame = self  // Set the frame reference
        try self.windowStack.add(window, shouldFocus: shouldFocus)

        // resize window to frame size
        let targetRect = self.geometry.contentRect
        try window.resize(size: targetRect.size)
        try window.move(to: targetRect.origin)
    }

    func removeWindow(_ window: WindowController) -> Bool {
        let removed = self.windowStack.remove(window)
        if removed {
            window.frame = nil  // Clear the frame reference
        }
        return removed
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

    func takeWindowsFrom(_ other: FrameController) throws {
        // Transfer windows to this frame's stack
        try self.windowStack.takeAll(from: other.windowStack)

        // Update frame references for transferred windows
        for w in self.windowStack.all {
            w.frame = self
        }

        // Reposition all windows to fit this frame
        let targetRect = self.geometry.contentRect
        for w in self.windowStack.all {
            try w.resize(size: targetRect.size)
            try w.move(to: targetRect.origin)
        }
    }

    func split(direction: Direction) throws -> FrameController {
        precondition(self.children.isEmpty)

        let (geo1, geo2) = direction == .Horizontal
            ? self.geometry.splitHorizontally()
            : self.geometry.splitVertically()

        let child1 = FrameController(geometry: geo1, config: self.config)
        child1.parent = self
        let child2 = FrameController(geometry: geo2, config: self.config)
        child2.parent = self
        self.children = [child1, child2]

        try child1.takeWindowsFrom(self)
        self.refreshOverlay()
        return child1
    }

    func toString() -> String {
        return "Frame(rect=\(self.geometry.frameRect))"
    }

    static func fromScreen(_ screen: NSScreen, config: ConfigController) -> FrameController {
        let geometry = FrameGeometry.fromScreen(screen, titleBarHeight: config.titleBarHeight)
        return FrameController(rect: geometry.frameRect, config: config)
    }
}
