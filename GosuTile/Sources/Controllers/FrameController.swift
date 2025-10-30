// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Jimmy Ma

import Cocoa
import ApplicationServices

@MainActor
class FrameController {
    let config: ConfigController
    private let geometry: FrameGeometry
    let frameWindow: FrameWindow

    var children: [FrameController] = []
    var windows: [WindowController] = []
    var activeIndex = 0;

    var activeWindow: WindowController? {
        guard !windows.isEmpty && activeIndex < windows.count else { return nil }
        return self.windows[activeIndex]
    }

    init(rect: CGRect, config: ConfigController) {
        self.config = config
        self.geometry = FrameGeometry(rect: rect, titleBarHeight: config.titleBarHeight)
        self.frameWindow = FrameWindow()
    }

    private init(geometry: FrameGeometry, config: ConfigController) {
        self.config = config
        self.geometry = geometry
        self.frameWindow = FrameWindow()
    }

    func refreshOverlay() {
        let tabs = self.windows.enumerated().map { (index, w) in
            TabInfo(title: w.title, isActive: index == self.activeIndex)
        }
        self.frameWindow.updateOverlay(
            rect: self.geometry.titleBarRect,
            tabs: tabs,
        )
    }

    func addWindow(_ window: WindowController) throws {
        // TODO check for duplicate before inserting
        self.windows.append(window)

        // resize window to frame size
        let targetRect = self.geometry.contentRect
        try window.resize(size: targetRect.size)
        try window.move(to: targetRect.origin)
    }

    func nextWindow() {
        self.activeIndex = self.activeIndex + 1 >= self.windows.count ? 0 : self.activeIndex + 1
        self.activeWindow?.raise()
        self.refreshOverlay()
    }

    func previousWindow() {
        self.activeIndex = self.activeIndex <= 0 ? self.windows.count - 1 : self.activeIndex - 1
        self.activeWindow?.raise()
        self.refreshOverlay()
    }

    func split(direction: Direction) throws {
        precondition(self.children.isEmpty)

        let (geo1, geo2) = direction == .Horizontal
            ? self.geometry.splitHorizontally()
            : self.geometry.splitVertically()

        let child1 = FrameController(geometry: geo1, config: self.config)
        let child2 = FrameController(geometry: geo2, config: self.config)
        self.children = [child1, child2]

        let windowsToMove = self.windows
        self.windows = []
        let targetFrame = self.children[0]
        for w in windowsToMove {
            try targetFrame.addWindow(w)
        }
    }

    func toString() -> String {
        return "Frame(rect=\(self.geometry.rect))"
    }

    static func fromScreen(_ screen: NSScreen, config: ConfigController) -> FrameController {
        let geometry = FrameGeometry.fromScreen(screen, titleBarHeight: config.titleBarHeight)
        return FrameController(rect: geometry.rect, config: config)
    }
}
