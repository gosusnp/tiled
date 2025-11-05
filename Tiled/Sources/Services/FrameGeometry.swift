// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Jimmy Ma

import Cocoa

class FrameGeometry {
    let frameRect: CGRect
    let titleBarHeight: CGFloat

    init(rect: CGRect, titleBarHeight: CGFloat) {
        self.frameRect = rect
        self.titleBarHeight = titleBarHeight
    }

    // Derived rects
    var contentRect: CGRect {
        CGRect(
            x: frameRect.origin.x,
            y: frameRect.origin.y + titleBarHeight,
            width: frameRect.size.width,
            height: frameRect.size.height - titleBarHeight,
        )
    }

    var titleBarRect: CGRect {
        CGRect(
            x: frameRect.origin.x,
            y: frameRect.origin.y,
            width: frameRect.size.width,
            height: titleBarHeight,
        )
    }

    // Splitting returns two new geometries
    func splitHorizontally() -> (FrameGeometry, FrameGeometry) {
        let yshift = frameRect.size.height / 2
        let bottom = FrameGeometry(
            rect: CGRect(x: frameRect.origin.x, y: frameRect.origin.y + yshift, width: frameRect.width, height: yshift),
            titleBarHeight: titleBarHeight
        )
        let top = FrameGeometry(
            rect: CGRect(x: frameRect.origin.x, y: frameRect.origin.y, width: frameRect.width, height: yshift),
            titleBarHeight: titleBarHeight
        )
        return (top, bottom)
    }

    func splitVertically() -> (FrameGeometry, FrameGeometry) {
        let xshift = frameRect.size.width / 2
        let left = FrameGeometry(
            rect: CGRect(x: frameRect.origin.x, y: frameRect.origin.y, width: xshift, height: frameRect.height),
            titleBarHeight: titleBarHeight
        )
        let right = FrameGeometry(
            rect: CGRect(x: frameRect.origin.x + xshift, y: frameRect.origin.y, width: xshift, height: frameRect.height),
            titleBarHeight: titleBarHeight
        )
        return (left, right)
    }

    // Factory methods
    static func fromRect(_ rect: CGRect, titleBarHeight: CGFloat) -> FrameGeometry {
        FrameGeometry(rect: rect, titleBarHeight: titleBarHeight)
    }

    static func fromScreen(_ screen: NSScreen, titleBarHeight: CGFloat) -> FrameGeometry {
        let menubarHeight = screen.frame.height - screen.visibleFrame.height - (screen.visibleFrame.minY - screen.frame.minY)
        let frame = screen.visibleFrame
        return FrameGeometry(
            rect: CGRect(
                x: frame.minX,
                y: frame.minY + menubarHeight,
                width: frame.width,
                height: frame.height
            ),
            titleBarHeight: titleBarHeight
        )
    }

    // TODO: Extract menubar height calculation into testable helper function
    // This will allow proper unit testing of the calculation logic without
    // depending on NSScreen, which is difficult to mock.
    // See: Tests/GosuTileTests/Services/FrameGeometryTests.swift
}
