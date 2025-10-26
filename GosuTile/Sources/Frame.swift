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

    init(rect: CGRect) {
        self.rect = rect
    }

    func toString() -> String {
        return "Frame(rect=\(self.rect))"
    }

    func split(direction: Direction) {
        precondition(self.direction == nil)
        self.direction = direction
    }
}
