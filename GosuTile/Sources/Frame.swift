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

    func toString() -> String {
        return "Frame(rect=\(self.rect))"
    }

    func split(direction: Direction) {
        precondition(self.direction == nil)
        self.direction = direction
    }
}
