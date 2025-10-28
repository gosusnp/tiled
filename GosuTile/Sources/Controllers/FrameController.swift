// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Jimmy Ma

import Cocoa
import ApplicationServices

@MainActor
class FrameController {
    let config: ConfigController
    let frame: FrameModel
    let window: FrameWindow

    var children: [FrameController] = []
    var windows: [WindowController] = []

    init(frame: FrameModel, config: ConfigController) {
        self.config = config
        self.frame = frame
        self.window = FrameWindow()
    }

    func refreshOverlay() {
        let tabs = self.windows.map { TabInfo(title: $0.title, isActive: $0.isActive) }
        self.window.updateOverlay(
            rect: self.getTitleBarRect(),
            tabs: tabs,
        )
    }

    func addWindow(_ window: WindowController) throws {
        // TODO check for duplicate before inserting
        self.windows.append(window)

        // resize window to frame size
        let targetRect = self.getContentRect()
        try window.resize(size: targetRect.size)
        try window.move(to: targetRect.origin)
    }

    func split(direction: Direction) throws {
        precondition(self.frame.direction == nil)
        self.frame.direction = direction

        switch direction {
            case Direction.Horizontal: self.splitHorizontally()
            case Direction.Vertical: self.splitVertically()
        }

        let windowsToMove = self.windows
        self.windows = []
        let targetFrame = self.children[0]
        for w in windowsToMove {
            try targetFrame.addWindow(w)
        }
    }

    func toString() -> String {
        return "Frame(rect=\(self.frame.rect))"
    }

    private func splitHorizontally() {
        let yshift = self.frame.rect.size.height / 2
        let f1 = FrameController.fromRect(
            CGRect(
                x: self.frame.rect.origin.x,
                y: self.frame.rect.origin.y,
                width: self.frame.rect.size.width,
                height: yshift,
            ),
            config: self.config,
        )
        let f2 = FrameController.fromRect(
            CGRect(
                x: self.frame.rect.origin.x,
                y: self.frame.rect.origin.y + yshift,
                width: self.frame.rect.size.width,
                height: yshift,
            ),
            config: self.config,
        )
        self.children.append(f1)
        self.children.append(f2)
    }

    private func splitVertically() {
        let xshift = self.frame.rect.size.width / 2
        let f1 = FrameController.fromRect(
            CGRect(
                x: self.frame.rect.origin.x,
                y: self.frame.rect.origin.y,
                width: xshift,
                height: self.frame.rect.size.height,
            ),
            config: self.config,
        )
        let f2 = FrameController.fromRect(
            CGRect(
                x: self.frame.rect.origin.x + xshift,
                y: self.frame.rect.origin.y,
                width: xshift,
                height: self.frame.rect.size.height,
            ),
            config: self.config,
        )
        self.children.append(f1)
        self.children.append(f2)
    }

    private func getTitleBarRect() -> CGRect {
        return CGRect(
            x: self.frame.rect.origin.x,
            y: self.frame.rect.origin.y + self.frame.rect.size.height - self.config.titleBarHeight,
            width: self.frame.rect.size.width,
            height: self.config.titleBarHeight,
        )
    }

    private func getContentRect() -> CGRect {
        return CGRect(
            x: self.frame.rect.origin.x,
            y: self.frame.rect.origin.y + self.config.titleBarHeight,
            width: self.frame.rect.size.width,
            height: self.frame.rect.size.height - self.config.titleBarHeight,
        )
    }

    static func fromRect(_ rect: CGRect, config: ConfigController) -> FrameController {
        return FrameController(
            frame: FrameModel(rect: rect),
            config: config,
        )
    }

    static func fromScreen(_ screen: NSScreen, config: ConfigController) -> FrameController {
        let menubarHeight = screen.frame.height - screen.visibleFrame.height - (screen.visibleFrame.minY - screen.frame.minY)

        let bounds = screen.visibleFrame
        return FrameController.fromRect(
            CGRect(
                x: bounds.minX,
                y: bounds.minY + menubarHeight,
                width: bounds.width,
                height: bounds.height,
            ),
            config: config,
        )
    }
}
