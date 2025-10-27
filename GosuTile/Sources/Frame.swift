// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Jimmy Ma

import Cocoa

enum Direction {
    case Horizontal
    case Vertical
}

// MARK: - Frame
class Frame {
    let id = UUID()
    var rect: CGRect
    var children: [Frame] = []
    var direction: Direction? = nil
    var windows: [AppWindow] = []

    init(rect: CGRect) {
        self.rect = rect
    }

    func addWindow(_ window: AppWindow) throws {
        // TODO check for duplicate before inserting
        windows.append(window)

        // resize window to frame size
        try window.resize(size: self.rect.size)
        try window.move(to: self.rect.origin)
    }

    func split(direction: Direction) throws {
        precondition(self.direction == nil)
        self.direction = direction

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
        return "Frame(rect=\(self.rect))"
    }

    private func splitHorizontally() {
        let yshift = self.rect.size.height / 2
        let f1 = Frame(rect: CGRect(
            x: self.rect.origin.x,
            y: self.rect.origin.y,
            width: self.rect.size.width,
            height: yshift,
        ))
        let f2 = Frame(rect: CGRect(
            x: self.rect.origin.x,
            y: self.rect.origin.y + yshift,
            width: self.rect.size.width,
            height: yshift,
        ))
        self.children.append(f1)
        self.children.append(f2)
    }

    private func splitVertically() {
        let xshift = self.rect.size.width / 2
        let f1 = Frame(rect: CGRect(
            x: self.rect.origin.x,
            y: self.rect.origin.y,
            width: xshift,
            height: self.rect.size.height,
        ))
        let f2 = Frame(rect: CGRect(
            x: self.rect.origin.x + xshift,
            y: self.rect.origin.y,
            width: xshift,
            height: self.rect.size.height,
        ))
        self.children.append(f1)
        self.children.append(f2)
    }
}
