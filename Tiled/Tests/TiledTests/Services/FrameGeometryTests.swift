// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Jimmy Ma

import Cocoa
import Testing
@testable import Tiled

@Suite("FrameGeometry Tests")
struct FrameGeometryTests {
    let titleBarHeight: CGFloat = 28
    let testRect: CGRect

    init() {
        self.testRect = CGRect(x: 0, y: 0, width: 1920, height: 1080)
    }

    @Test("Initializes with rect and titleBarHeight")
    func testInitialization() {
        let geometry = FrameGeometry(rect: testRect, titleBarHeight: titleBarHeight)

        #expect(geometry.frameRect == testRect)
        #expect(geometry.titleBarHeight == titleBarHeight)
    }

    @Test("Calculates contentRect correctly")
    func testContentRect() {
        let geometry = FrameGeometry(rect: testRect, titleBarHeight: titleBarHeight)
        let contentRect = geometry.contentRect

        // Content should start after titleBar and have reduced height
        #expect(contentRect.origin.x == testRect.origin.x)
        #expect(contentRect.origin.y == testRect.origin.y + titleBarHeight)
        #expect(contentRect.size.width == testRect.size.width)
        #expect(contentRect.size.height == testRect.size.height - titleBarHeight)
    }

    @Test("Calculates titleBarRect correctly")
    func testTitleBarRect() {
        let geometry = FrameGeometry(rect: testRect, titleBarHeight: titleBarHeight)
        let titleBarRect = geometry.titleBarRect

        // Title bar should be at the bottom of the frame
        #expect(titleBarRect.origin.x == testRect.origin.x)
        #expect(titleBarRect.origin.y == testRect.origin.y)
        #expect(titleBarRect.size.width == testRect.size.width)
        #expect(titleBarRect.size.height == titleBarHeight)
    }

    @Test("Splits horizontally into two equal geometries")
    func testSplitHorizontally() {
        let geometry = FrameGeometry(rect: testRect, titleBarHeight: titleBarHeight)
        let (top, bottom) = geometry.splitHorizontally()

        let expectedHeight = testRect.size.height / 2

        // Check top geometry
        #expect(top.frameRect.origin.x == testRect.origin.x)
        #expect(top.frameRect.origin.y == testRect.origin.y)
        #expect(top.frameRect.size.width == testRect.size.width)
        #expect(top.frameRect.size.height == expectedHeight)
        #expect(top.titleBarHeight == titleBarHeight)

        // Check bottom geometry
        #expect(bottom.frameRect.origin.x == testRect.origin.x)
        #expect(bottom.frameRect.origin.y == testRect.origin.y + expectedHeight)
        #expect(bottom.frameRect.size.width == testRect.size.width)
        #expect(bottom.frameRect.size.height == expectedHeight)
        #expect(bottom.titleBarHeight == titleBarHeight)
    }

    @Test("Splits vertically into two equal geometries")
    func testSplitVertically() {
        let geometry = FrameGeometry(rect: testRect, titleBarHeight: titleBarHeight)
        let (left, right) = geometry.splitVertically()

        let expectedWidth = testRect.size.width / 2

        // Check left geometry
        #expect(left.frameRect.origin.x == testRect.origin.x)
        #expect(left.frameRect.origin.y == testRect.origin.y)
        #expect(left.frameRect.size.width == expectedWidth)
        #expect(left.frameRect.size.height == testRect.size.height)
        #expect(left.titleBarHeight == titleBarHeight)

        // Check right geometry
        #expect(right.frameRect.origin.x == testRect.origin.x + expectedWidth)
        #expect(right.frameRect.origin.y == testRect.origin.y)
        #expect(right.frameRect.size.width == expectedWidth)
        #expect(right.frameRect.size.height == testRect.size.height)
        #expect(right.titleBarHeight == titleBarHeight)
    }

    @Test("Creates geometry from rect factory method")
    func testFromRectFactory() {
        let geometry = FrameGeometry.fromRect(testRect, titleBarHeight: titleBarHeight)

        #expect(geometry.frameRect == testRect)
        #expect(geometry.titleBarHeight == titleBarHeight)
    }
}
