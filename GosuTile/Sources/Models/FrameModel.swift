// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Jimmy Ma

import Cocoa

enum Direction {
    case Horizontal
    case Vertical
}

// MARK: - Frame
class FrameModel {
    var rect: CGRect
    var direction: Direction?

    init(rect: CGRect) {
        self.rect = rect
        self.direction = nil
    }
}
