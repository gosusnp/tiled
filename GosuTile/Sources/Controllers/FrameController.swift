// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Jimmy Ma

import Cocoa
import ApplicationServices

class FrameController {
    let frame: FrameModel

    var children: [FrameController] = []
    var windows: [WindowController] = []

    init(frame: FrameModel) {
        self.frame = frame
    }

    static func fromRect(_ rect: CGRect) -> FrameController {
        return FrameController(
            frame: FrameModel(rect: rect)
        )
    }

    static func fromScreen(_ screen: NSScreen) -> FrameController {
        let bounds = screen.visibleFrame
        return FrameController.fromRect(
            CGRect(
                x: bounds.minX,
                y: bounds.minY,
                width: bounds.width,
                height: bounds.height,
            )
        )
    }

    func addWindow(_ window: WindowController) throws {
        // TODO check for duplicate before inserting
        self.windows.append(window)

        // resize window to frame size
        try window.resize(size: self.frame.rect.size)
        try window.move(to: self.frame.rect.origin)
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
        let f1 = FrameController.fromRect(CGRect(
            x: self.frame.rect.origin.x,
            y: self.frame.rect.origin.y,
            width: self.frame.rect.size.width,
            height: yshift,
        ))
        let f2 = FrameController.fromRect(CGRect(
            x: self.frame.rect.origin.x,
            y: self.frame.rect.origin.y + yshift,
            width: self.frame.rect.size.width,
            height: yshift,
        ))
        self.children.append(f1)
        self.children.append(f2)
    }

    private func splitVertically() {
        let xshift = self.frame.rect.size.width / 2
        let f1 = FrameController.fromRect(CGRect(
            x: self.frame.rect.origin.x,
            y: self.frame.rect.origin.y,
            width: xshift,
            height: self.frame.rect.size.height,
        ))
        let f2 = FrameController.fromRect(CGRect(
            x: self.frame.rect.origin.x + xshift,
            y: self.frame.rect.origin.y,
            width: xshift,
            height: self.frame.rect.size.height,
        ))
        self.children.append(f1)
        self.children.append(f2)
    }
}
