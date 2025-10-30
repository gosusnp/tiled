// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Jimmy Ma

import Cocoa

class FrameGeometry {
    let rect: CGRect
    let titleBarHeight: CGFloat

    init(rect: CGRect, titleBarHeight: CGFloat) {
        self.rect = rect
        self.titleBarHeight = titleBarHeight
    }

    // Derived rects
    var contentRect: CGRect {
        CGRect(
            x: rect.origin.x,
            y: rect.origin.y + titleBarHeight,
            width: rect.size.width,
            height: rect.size.height - titleBarHeight
        )
    }

    var titleBarRect: CGRect {
        CGRect(
            x: rect.origin.x,
            y: rect.origin.y + rect.size.height - titleBarHeight,
            width: rect.size.width,
            height: titleBarHeight
        )
    }

    // Splitting returns two new geometries
    func splitHorizontally() -> (FrameGeometry, FrameGeometry) {
        let yshift = rect.size.height / 2
        let top = FrameGeometry(
            rect: CGRect(x: rect.origin.x, y: rect.origin.y, width: rect.width, height: yshift),
            titleBarHeight: titleBarHeight
        )
        let bottom = FrameGeometry(
            rect: CGRect(x: rect.origin.x, y: rect.origin.y + yshift, width: rect.width, height: yshift),
            titleBarHeight: titleBarHeight
        )
        return (top, bottom)
    }

    func splitVertically() -> (FrameGeometry, FrameGeometry) {
        let xshift = rect.size.width / 2
        let left = FrameGeometry(
            rect: CGRect(x: rect.origin.x, y: rect.origin.y, width: xshift, height: rect.height),
            titleBarHeight: titleBarHeight
        )
        let right = FrameGeometry(
            rect: CGRect(x: rect.origin.x + xshift, y: rect.origin.y, width: xshift, height: rect.height),
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
        let bounds = screen.visibleFrame
        return FrameGeometry(
            rect: CGRect(
                x: bounds.minX,
                y: bounds.minY + menubarHeight,
                width: bounds.width,
                height: bounds.height
            ),
            titleBarHeight: titleBarHeight
        )
    }

    // TODO: Extract menubar height calculation into testable helper function
    // This will allow proper unit testing of the calculation logic without
    // depending on NSScreen, which is difficult to mock.
    // See: Tests/GosuTileTests/Services/FrameGeometryTests.swift
}
